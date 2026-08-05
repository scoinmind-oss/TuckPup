import AppKit
import SwiftUI

struct MenuBarControlWindowIDs {
    let toggle: CGWindowID
    let hiddenDivider: CGWindowID
    let permanentDivider: CGWindowID

    var all: Set<CGWindowID> {
        [toggle, hiddenDivider, permanentDivider]
    }
}

enum MenuBarItemCategory: String, CaseIterable, Identifiable {
    case visible
    case hidden
    case permanent

    var id: String { rawValue }
}

struct MenuBarLayoutEntry: Identifiable {
    let item: ManagedMenuBarItem
    let image: NSImage?

    init(item: ManagedMenuBarItem, image: NSImage?) {
        self.item = item
        self.image = image
    }

    var id: CGWindowID { item.windowID }
    var name: String {
        if item.sourceBundleIdentifier != "com.apple.controlcenter",
           !item.sourceName.isEmpty {
            return item.sourceName
        }
        return item.displayName
    }

}

/// Complete inventory used by Settings and the permanent-items menu.
/// Classifications are also applied to the native menu bar through the two
/// TuckPup separator items.
@MainActor
final class MenuBarLayoutModel: ObservableObject {
    @Published private(set) var entries: [MenuBarItemCategory: [MenuBarLayoutEntry]] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var isMoving = false
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var hasScreenRecordingPermission = false
    @Published var statusMessage = ""
    @Published private(set) var localizationRevision = 0

    private let controlWindowIDs: () -> MenuBarControlWindowIDs?
    private let moveNativeItem: (
        ManagedMenuBarItem,
        MenuBarItemCategory,
        ManagedMenuBarItem?,
        @escaping (Bool) -> Void
    ) -> Void
    private let reconcileNativeCategories: (
        [MenuBarItemCategory: [ManagedMenuBarItem]],
        @escaping (Bool) -> Void
    ) -> Void
    private var refreshTask: Task<Void, Never>?
    private var workspaceObservers = [NSObjectProtocol]()

    init(
        controlWindowIDs: @escaping () -> MenuBarControlWindowIDs?,
        moveNativeItem: @escaping (
            ManagedMenuBarItem,
            MenuBarItemCategory,
            ManagedMenuBarItem?,
            @escaping (Bool) -> Void
        ) -> Void,
        reconcileNativeCategories: @escaping (
            [MenuBarItemCategory: [ManagedMenuBarItem]],
            @escaping (Bool) -> Void
        ) -> Void
    ) {
        self.controlWindowIDs = controlWindowIDs
        self.moveNativeItem = moveNativeItem
        self.reconcileNativeCategories = reconcileNativeCategories
        MenuBarItemCategory.allCases.forEach { entries[$0] = [] }
        updatePermissions()
        observeRunningApplications()
    }

    func entries(in section: MenuBarItemCategory) -> [MenuBarLayoutEntry] {
        entries[section] ?? []
    }

    func items(in section: MenuBarItemCategory) -> [ManagedMenuBarItem] {
        entries(in: section).map(\.item)
    }

    func refresh(after delay: TimeInterval = 0) {
        refreshTask?.cancel()
        isRefreshing = true
        statusMessage = ""
        refreshTask = Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            await self?.performRefresh(retriesRemaining: 5)
        }
    }

    func localizationDidChange() {
        localizationRevision += 1
    }

    func requestAccessibilityPermission() {
        MenuBarItemBridge.requestAccessibilityPermission()
        for delay in [1.0, 3.0, 8.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.updatePermissions()
                if self.hasAccessibilityPermission {
                    self.refresh()
                }
            }
        }
    }

    func requestScreenRecordingPermission() {
        MenuBarItemBridge.requestScreenRecordingPermission()
        for delay in [1.0, 3.0, 8.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refresh()
            }
        }
    }

    func move(
        windowID: CGWindowID,
        to destination: MenuBarItemCategory,
        before beforeWindowID: CGWindowID? = nil
    ) {
        guard !isMoving,
              let source = section(containing: windowID),
              let entry = entries[source]?.first(where: { $0.id == windowID })
        else { return }

        var updatedEntries = entries
        updatedEntries[source]?.removeAll { $0.id == windowID }

        let destinationEntries = updatedEntries[destination] ?? []
        if let beforeWindowID,
           let index = destinationEntries.firstIndex(where: { $0.id == beforeWindowID }) {
            updatedEntries[destination, default: []].insert(entry, at: index)
        } else {
            updatedEntries[destination, default: []].append(entry)
        }

        guard updatedEntries.mapValues({ $0.map(\.id) }) != entries.mapValues({ $0.map(\.id) })
        else { return }

        let beforeItem = beforeWindowID.flatMap { id in
            updatedEntries[destination]?.first(where: { $0.id == id })?.item
        }

        entries = updatedEntries
        isMoving = true
        statusMessage = Localization.strings.layoutMoving

        moveNativeItem(entry.item, destination, beforeItem) { [weak self] succeeded in
            guard let self else { return }
            self.isMoving = false
            var classifications = Preferences.itemClassifications
            classifications[entry.item.preferenceKey] = destination.rawValue
            Preferences.itemClassifications = classifications
            Preferences.itemOrder = self.orderedPreferenceKeys()
            Preferences.permanentSectionConfigured = true
            self.statusMessage = succeeded
                ? Localization.strings.layoutMoveSucceeded
                : Localization.strings.layoutMoveFailed
            self.refresh(after: 0.15)
        }
    }

    private func orderedPreferenceKeys() -> [String] {
        [MenuBarItemCategory.permanent, .hidden, .visible].flatMap { category in
            entries[category, default: []].map { $0.item.preferenceKey }
        }
    }

    private func performRefresh(retriesRemaining: Int) async {
        updatePermissions()
        guard let controls = controlWindowIDs() else {
            if retriesRemaining > 0 {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await performRefresh(retriesRemaining: retriesRemaining - 1)
                return
            }
            isRefreshing = false
            statusMessage = Localization.strings.layoutItemsUnavailable
            return
        }

        let excludedWindowIDs = controls.all
        let items = await Task.detached(priority: .userInitiated) {
            MenuBarItemBridge.allItems(excluding: excludedWindowIDs)
        }.value
        guard !Task.isCancelled else { return }

        let classifications = Preferences.itemClassifications
        let migratedPermanentKeys = Preferences.permanentItemKeys
        var updated: [MenuBarItemCategory: [MenuBarLayoutEntry]] = [
            .visible: [],
            .hidden: [],
            .permanent: []
        ]

        for item in items {
            let category: MenuBarItemCategory
            if let rawValue = classifications[item.preferenceKey],
               let stored = MenuBarItemCategory(rawValue: rawValue) {
                category = stored
            } else if migratedPermanentKeys.contains(item.preferenceKey) {
                category = .permanent
            } else if item.sourceBundleIdentifier == "com.apple.controlcenter" {
                category = .visible
            } else {
                category = .hidden
            }
            updated[category, default: []].append(
                MenuBarLayoutEntry(item: item, image: MenuBarItemBridge.settingsPreviewImage(for: item))
            )
        }

        let savedOrder = Preferences.itemOrder
        if !savedOrder.isEmpty {
            let rank = Dictionary(uniqueKeysWithValues: savedOrder.enumerated().map { ($0.element, $0.offset) })
            for category in MenuBarItemCategory.allCases {
                updated[category]?.sort { lhs, rhs in
                    (rank[lhs.item.preferenceKey] ?? Int.max) <
                        (rank[rhs.item.preferenceKey] ?? Int.max)
                }
            }
        }

        entries = updated
        isRefreshing = false
        statusMessage = ""

        let nativeLayout = updated.mapValues { $0.map(\.item) }
        reconcileNativeCategories(nativeLayout) { _ in }
    }

    private func section(containing windowID: CGWindowID) -> MenuBarItemCategory? {
        MenuBarItemCategory.allCases.first { section in
            entries[section]?.contains(where: { $0.id == windowID }) == true
        }
    }

    private func updatePermissions() {
        hasAccessibilityPermission = MenuBarItemBridge.hasAccessibilityPermission
        hasScreenRecordingPermission = MenuBarItemBridge.hasScreenRecordingPermission
    }

    private func observeRunningApplications() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ] {
            let observer = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh(after: 0.8)
                }
            }
            workspaceObservers.append(observer)
        }
    }
}
