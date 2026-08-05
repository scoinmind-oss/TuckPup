import AppKit

@MainActor
final class StatusBarController: NSObject {
    var onShowSettings: (() -> Void)?
    var shelfItemsProvider: (() -> (regular: [ManagedMenuBarItem], permanent: [ManagedMenuBarItem]))?

    private let toggleItem = NSStatusBar.system.statusItem(withLength: 24)
    private let separatorItem = NSStatusBar.system.statusItem(withLength: 1)
    private let permanentSeparatorItem = NSStatusBar.system.statusItem(withLength: 1)
    private let normalSeparatorLength: CGFloat = 1
    private let layoutHiddenSeparatorLength: CGFloat = 3
    private let layoutPermanentSeparatorLength: CGFloat = 9
    private let collapsePadding: CGFloat = 64

    private var collapsedLength: CGFloat = 1_792
    private var permanentCollapsedLength: CGFloat = 1_792
    private var autoCollapseTimer: Timer?
    private var clickLocked = false
    private var geometryUpdateWorkItem: DispatchWorkItem?
    private var scrollMonitors = [Any]()
    private var pendingRehideWorkItem: DispatchWorkItem?
    private let permanentItemsMenu = NSMenu()
    private var currentPermanentItems = [ManagedMenuBarItem]()
    private lazy var contextMenu = makeContextMenu()

    private var isCollapsed: Bool {
        separatorItem.length > 50
    }

    override init() {
        super.init()
        configureItems()
        // Never restore into a state where a newly-added separator can push
        // TuckPup's own icon offscreen before its position has been configured.
        separatorItem.length = normalSeparatorLength
        permanentSeparatorItem.length = normalSeparatorLength
        updateCollapsedLength()
        observeScreenChanges()
        observeScrollWheel()
    }

    func collapseAfterLaunch() {
        separatorItem.length = normalSeparatorLength
        permanentSeparatorItem.length = normalSeparatorLength
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            self?.repairControlOrderIfNeeded { [weak self] _ in
                self?.collapse()
            }
        }
    }

    func preferencesDidChange() {
        if Preferences.autoCollapseEnabled, !isCollapsed {
            scheduleAutoCollapse()
        } else {
            autoCollapseTimer?.invalidate()
        }
    }

    func beginArrangeMode() {
        onShowSettings?()
    }

    /// Applies a Settings drag directly to the native menu bar. Hidden and
    /// permanent items are placed on the left side of their separators;
    /// visible items are placed to the right of the hidden boundary.
    func moveNativeItem(
        _ item: ManagedMenuBarItem,
        to category: MenuBarItemCategory,
        before beforeItem: ManagedMenuBarItem?,
        completion: @escaping (Bool) -> Void
    ) {
        revealNativeItemsForReordering()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self, let controls = self.controlWindowIDs else {
                completion(false)
                return
            }

            let targetWindowID: CGWindowID
            if let beforeItem {
                targetWindowID = beforeItem.windowID
            } else {
                switch category {
                case .permanent: targetWindowID = controls.permanentDivider
                case .hidden: targetWindowID = controls.hiddenDivider
                case .visible: targetWindowID = controls.toggle
                }
            }

            MenuBarItemBridge.move(
                item,
                relativeTo: targetWindowID,
                position: .left,
                requireAdjacency: beforeItem != nil
            ) { [weak self] succeeded in
                guard let self else {
                    completion(false)
                    return
                }
                self.finishNativeReordering {
                    completion(succeeded)
                }
            }
        }
    }

    /// Repairs category boundaries after launch or when a new menu bar app
    /// appears. Items already in the correct native region are left untouched.
    func reconcileNativeCategories(
        _ layout: [MenuBarItemCategory: [ManagedMenuBarItem]],
        completion: @escaping (Bool) -> Void
    ) {
        guard let controls = controlWindowIDs else {
            completion(false)
            return
        }

        let orderedCategories: [MenuBarItemCategory] = [.permanent, .hidden, .visible]
        let moves = orderedCategories.flatMap { category in
            (layout[category] ?? [])
                .filter { !isItem($0, in: category, controls: controls) }
                .map { ($0, category) }
        }
        guard !moves.isEmpty else {
            completion(true)
            return
        }

        revealNativeItemsForReordering()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.performNativeCategoryMoves(
                moves,
                index: 0,
                allSucceeded: true,
                completion: completion
            )
        }
    }

    private func performNativeCategoryMoves(
        _ moves: [(ManagedMenuBarItem, MenuBarItemCategory)],
        index: Int,
        allSucceeded: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        guard index < moves.count, let controls = controlWindowIDs else {
            finishNativeReordering {
                completion(allSucceeded && index == moves.count)
            }
            return
        }

        let (item, category) = moves[index]
        let targetWindowID: CGWindowID
        switch category {
        case .permanent: targetWindowID = controls.permanentDivider
        case .hidden: targetWindowID = controls.hiddenDivider
        case .visible: targetWindowID = controls.toggle
        }

        MenuBarItemBridge.move(
            item,
            relativeTo: targetWindowID,
            position: .left
        ) { [weak self] succeeded in
            self?.performNativeCategoryMoves(
                moves,
                index: index + 1,
                allSucceeded: allSucceeded && succeeded,
                completion: completion
            )
        }
    }

    private func isItem(
        _ item: ManagedMenuBarItem,
        in category: MenuBarItemCategory,
        controls: MenuBarControlWindowIDs
    ) -> Bool {
        guard let itemFrame = MenuBarItemBridge.frame(of: item.windowID),
              let permanentFrame = MenuBarItemBridge.frame(of: controls.permanentDivider),
              let hiddenFrame = MenuBarItemBridge.frame(of: controls.hiddenDivider)
        else { return false }

        switch category {
        case .permanent:
            return itemFrame.maxX <= permanentFrame.minX + 3
        case .hidden:
            return itemFrame.minX >= permanentFrame.maxX - 3 &&
                itemFrame.maxX <= hiddenFrame.maxX + 3
        case .visible:
            return itemFrame.minX >= hiddenFrame.maxX - 3
        }
    }

    private func revealNativeItemsForReordering() {
        autoCollapseTimer?.invalidate()
        separatorItem.length = normalSeparatorLength
        permanentSeparatorItem.length = normalSeparatorLength
    }

    /// Old builds and duplicate app instances could leave the three TuckPup
    /// controls in the wrong native order. Repair them automatically so the
    /// hidden boundary always sits to the left of the visible area and dog.
    private func repairControlOrderIfNeeded(completion: @escaping (Bool) -> Void) {
        revealNativeItemsForReordering()
        guard !hasValidItemOrder else {
            completion(true)
            return
        }

        guard let controls = controlWindowIDs,
              let hiddenItem = MenuBarItemBridge.item(for: controls.hiddenDivider),
              let permanentItem = MenuBarItemBridge.item(for: controls.permanentDivider)
        else {
            completion(false)
            return
        }

        MenuBarItemBridge.move(
            hiddenItem,
            relativeTo: controls.toggle,
            position: .left
        ) { [weak self] hiddenMoved in
            guard let self, let latestControls = self.controlWindowIDs else {
                completion(false)
                return
            }
            if self.hasValidItemOrder {
                completion(hiddenMoved)
                return
            }
            MenuBarItemBridge.move(
                permanentItem,
                relativeTo: latestControls.hiddenDivider,
                position: .left
            ) { [weak self] permanentMoved in
                guard let self else {
                    completion(false)
                    return
                }
                completion(hiddenMoved && permanentMoved && self.hasValidItemOrder)
            }
        }
    }

    private func finishNativeReordering(completion: @escaping () -> Void = {}) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.repairControlOrderIfNeeded { [weak self] _ in
                self?.collapse()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    completion()
                }
            }
        }
    }

    var controlWindowIDs: MenuBarControlWindowIDs? {
        let permanentID = permanentSeparatorItem.button?.window.flatMap(windowID(for:))
            ?? MenuBarItemBridge.windowID(
                closestToWidth: layoutPermanentSeparatorLength + 16
            )
        let hiddenID = separatorItem.button?.window.flatMap(windowID(for:))
            ?? MenuBarItemBridge.windowID(
                closestToWidth: layoutHiddenSeparatorLength + 16,
                excluding: Set([permanentID].compactMap { $0 })
            )
        let toggleID = toggleItem.button?.window.flatMap(windowID(for:))
            ?? MenuBarItemBridge.windowID(
                closestToWidth: toggleItem.length + 16,
                excluding: Set([permanentID, hiddenID].compactMap { $0 })
            )

        guard let toggleID, let hiddenID, let permanentID
        else { return nil }
        return MenuBarControlWindowIDs(
            toggle: toggleID,
            hiddenDivider: hiddenID,
            permanentDivider: permanentID
        )
    }

    private func windowID(for window: NSWindow) -> CGWindowID? {
        MenuBarItemBridge.windowID(for: window)
    }

    func prepareForLayoutEditing() {
        autoCollapseTimer?.invalidate()
        // Do not expand either section here. WindowServer keeps menu bar item
        // windows for items that are hidden or displaced by the notch, and the
        // settings inventory reads those off-screen windows directly. Changing
        // either separator before scanning would alter the layout and can make
        // macOS evict a different group of items.
        Preferences.permanentSectionConfigured = true
        Preferences.hasCompletedOnboarding = true
    }

    func finishLayoutEditing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.collapse()
        }
    }

    private func configureItems() {
        toggleItem.autosaveName = "tuckpup.toggle"
        separatorItem.autosaveName = "tuckpup.separator"
        permanentSeparatorItem.autosaveName = "tuckpup.permanent-separator"
        toggleItem.isVisible = true
        separatorItem.isVisible = true
        setPermanentSeparatorVisible(true)

        if let button = toggleItem.button {
            button.image = loadMenuIcon()
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(toggleButtonPressed(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        if let separatorButton = separatorItem.button {
            separatorButton.title = ""
            separatorButton.target = self
            separatorButton.action = #selector(separatorPressed(_:))
            separatorButton.sendAction(on: [.rightMouseDown])
        }

        if let separatorButton = permanentSeparatorItem.button {
            separatorButton.title = ""
            separatorButton.target = self
            separatorButton.action = #selector(separatorPressed(_:))
            separatorButton.sendAction(on: [.rightMouseDown])
        }
    }

    /// NSStatusItem deletes its saved preferred position when it is hidden.
    /// Restore the value immediately so the permanent divider returns to its
    /// configured position instead of reappearing underneath the camera notch.
    private func setPermanentSeparatorVisible(_ isVisible: Bool) {
        let key = "NSStatusItem Preferred Position tuckpup.permanent-separator"
        let defaults = UserDefaults.standard
        let savedPosition = defaults.object(forKey: key) ?? 2.0
        defaults.set(savedPosition, forKey: key)
        permanentSeparatorItem.isVisible = isVisible
        defaults.set(savedPosition, forKey: key)
    }

    private func loadMenuIcon() -> NSImage? {
        guard
            let url = Bundle.main.url(forResource: "BichonMenuIcon", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return NSImage(systemSymbolName: "dog.fill", accessibilityDescription: "TuckPup")
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        image.accessibilityDescription = "TuckPup"
        return image
    }

    private func observeScreenChanges() {
        let center = NotificationCenter.default

        center.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Adding or removing a menu bar app can move either separator window
        // without changing the screen parameters. This is especially visible
        // on a Mac with a camera notch, where the usable menu bar is split.
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            center.addObserver(
                self,
                selector: #selector(statusBarWindowDidChange(_:)),
                name: name,
                object: nil
            )
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func statusBarWindowDidChange(_ notification: Notification) {
        guard
            let changedWindow = notification.object as? NSWindow,
            isCollapsed
                || permanentSeparatorItem.length > 50
                || changedWindow === separatorItem.button?.window
                || changedWindow === permanentSeparatorItem.button?.window
        else {
            return
        }

        scheduleGeometryUpdate()
    }

    @objc private func screenParametersChanged() {
        let wasCollapsed = isCollapsed
        let wasPermanentCollapsed = permanentSeparatorItem.length > 50
        updateCollapsedLength()
        if wasCollapsed {
            separatorItem.length = collapsedLength
        }
        if wasPermanentCollapsed {
            permanentSeparatorItem.length = permanentCollapsedLength
        }
    }

    private func scheduleGeometryUpdate() {
        geometryUpdateWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            let wasCollapsed = self.isCollapsed
            self.updateCollapsedLength()

            if wasCollapsed, abs(self.separatorItem.length - self.collapsedLength) > 1 {
                self.separatorItem.length = self.collapsedLength
            }
            if self.permanentSeparatorItem.length > 50,
               abs(self.permanentSeparatorItem.length - self.permanentCollapsedLength) > 1 {
                self.permanentSeparatorItem.length = self.permanentCollapsedLength
            }
        }

        geometryUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func updateCollapsedLength() {
        let widestScreen = NSScreen.screens.map(\.frame.width).max() ?? 1_728
        let fallbackLength = min(widestScreen + collapsePadding, 10_000)

        collapsedLength = collapsedLength(for: separatorItem, fallback: fallbackLength)
        permanentCollapsedLength = collapsedLength(
            for: permanentSeparatorItem,
            fallback: fallbackLength
        )
    }

    private func collapsedLength(for item: NSStatusItem, fallback fallbackLength: CGFloat) -> CGFloat {
        guard let window = item.button?.window, let screen = window.screen else {
            return max(500, fallbackLength)
        }

        // The separator expands toward the left. Its right edge stays at the
        // hidden/visible boundary even after it has been collapsed, so use
        // maxX instead of minX. On a notched Mac, the right side of the menu
        // bar starts at auxiliaryTopRightArea.minX; using screen.frame.minX
        // would treat the camera housing as usable space and leave the first
        // status item temporarily hidden by macOS.
        let usableLeftEdge = menuBarUsableLeftEdge(for: window, on: screen)
        let distanceFromScreenLeft = window.frame.maxX - usableLeftEdge
        let requiredLength = distanceFromScreenLeft + collapsePadding
        let screenBound = screen.frame.maxX - usableLeftEdge + collapsePadding
        return max(500, min(requiredLength, screenBound))
    }

    private func menuBarUsableLeftEdge(for window: NSWindow, on screen: NSScreen) -> CGFloat {
        guard let topRightArea = screen.auxiliaryTopRightArea else {
            return screen.frame.minX
        }

        // Status items created by this app live in the right-hand status area.
        // Keep the fallback for displays without a notch and for a transient
        // layout state while macOS is moving the status item windows.
        guard window.frame.maxX >= topRightArea.minX else {
            return screen.frame.minX
        }

        return topRightArea.minX
    }

    @objc private func toggleButtonPressed(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        guard !event.modifierFlags.contains(.command) else { return }

        if event.type == .rightMouseDown {
            showContextMenu(from: sender)
            return
        }

        guard !clickLocked else { return }
        clickLocked = true
        DispatchQueue.main.async { [weak self] in
            self?.toggle()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.clickLocked = false
        }
    }

    @objc private func separatorPressed(_ sender: NSStatusBarButton) {
        showContextMenu(from: sender)
    }

    private func toggle() {
        if isCollapsed {
            expand()
        } else {
            collapse()
        }
    }

    private func collapse() {
        autoCollapseTimer?.invalidate()
        guard !isCollapsed else {
            permanentSeparatorItem.length = normalSeparatorLength
            return
        }
        guard hasValidItemOrder else {
            presentInvalidOrderHelp()
            return
        }

        separatorItem.button?.title = ""
        permanentSeparatorItem.button?.title = ""
        updateCollapsedLength()
        // Hide the entire left side first, then release the permanent divider.
        // This prevents permanently hidden icons flashing during the transition.
        separatorItem.length = collapsedLength
        permanentSeparatorItem.length = normalSeparatorLength
    }

    private func expand() {
        guard isCollapsed else {
            scheduleAutoCollapse()
            return
        }
        guard hasValidItemOrder else {
            presentInvalidOrderHelp()
            return
        }

        separatorItem.button?.title = ""
        permanentSeparatorItem.button?.title = ""
        updateCollapsedLength()

        // Keep the permanent region hidden before exposing the regular hidden
        // region. Only icons between the two dividers return to the menu bar.
        permanentSeparatorItem.length = permanentCollapsedLength
        separatorItem.length = normalSeparatorLength
        scheduleAutoCollapse()
    }

    private var hasValidItemOrder: Bool {
        guard let controls = controlWindowIDs,
              let toggle = MenuBarItemBridge.frame(of: controls.toggle),
              let hidden = MenuBarItemBridge.frame(of: controls.hiddenDivider),
              let permanent = MenuBarItemBridge.frame(of: controls.permanentDivider)
        else { return false }
        return permanent.maxX <= hidden.minX + 2 && hidden.maxX <= toggle.minX + 2
    }

    private func observeScrollWheel() {
        if let local = NSEvent.addLocalMonitorForEvents(
            matching: .scrollWheel,
            handler: { [weak self] event in
                self?.handleScrollWheel(event)
                return event
            }
        ) {
            scrollMonitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: .scrollWheel,
            handler: { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleScrollWheel(event)
                }
            }
        ) {
            scrollMonitors.append(global)
        }
    }

    private func handleScrollWheel(_ event: NSEvent) {
        guard let window = toggleItem.button?.window else { return }
        guard window.frame.insetBy(dx: -4, dy: -4).contains(NSEvent.mouseLocation) else { return }
        guard abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) else { return }

        if event.scrollingDeltaY > 0, isCollapsed {
            expand()
        } else if event.scrollingDeltaY < 0, !isCollapsed {
            collapse()
        }
    }

    private func scheduleAutoCollapse() {
        autoCollapseTimer?.invalidate()
        guard Preferences.autoCollapseEnabled, !isCollapsed else { return }

        autoCollapseTimer = Timer.scheduledTimer(
            withTimeInterval: Preferences.autoCollapseDelay,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.collapse()
            }
        }
    }

    private var isMouseInMenuBar: Bool {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            mouse.x >= screen.frame.minX
                && mouse.x <= screen.frame.maxX
                && mouse.y >= screen.visibleFrame.maxY
                && mouse.y <= screen.frame.maxY
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        updateContextMenu()
        contextMenu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.minY - 2),
            in: button
        )
    }

    private func updateContextMenu() {
        guard contextMenu.items.count >= 8 else { return }
        let strings = Localization.strings

        contextMenu.items[0].title = isCollapsed
            ? strings.showHiddenIcons
            : strings.hideIcons

        let permanentItemsMenuItem = contextMenu.items[1]
        permanentItemsMenuItem.title = strings.showPermanentIcons
        rebuildPermanentItemsMenu()

        let arrangeItem = contextMenu.items[2]
        arrangeItem.title = strings.adjustHiddenRange
        arrangeItem.action = #selector(beginArrangeFromMenu)

        contextMenu.items[4].title = strings.autoCollapse
        contextMenu.items[4].state = Preferences.autoCollapseEnabled ? .on : .off
        contextMenu.items[5].title = strings.settings
        contextMenu.items[7].title = strings.quit
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()

        let toggleMenuItem = NSMenuItem(
            title: "",
            action: #selector(toggleFromMenu),
            keyEquivalent: ""
        )
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        let permanentItemsMenuItem = NSMenuItem(
            title: "",
            action: nil,
            keyEquivalent: ""
        )
        permanentItemsMenuItem.submenu = permanentItemsMenu
        menu.addItem(permanentItemsMenuItem)

        let arrangeItem = NSMenuItem(
            title: "",
            action: #selector(beginArrangeFromMenu),
            keyEquivalent: ""
        )
        arrangeItem.target = self
        menu.addItem(arrangeItem)

        menu.addItem(.separator())

        let autoItem = NSMenuItem(
            title: "",
            action: #selector(toggleAutoCollapse),
            keyEquivalent: ""
        )
        autoItem.target = self
        menu.addItem(autoItem)

        let settingsItem = NSMenuItem(
            title: "",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        return menu
    }

    @objc private func toggleFromMenu() {
        toggle()
    }

    @objc private func beginArrangeFromMenu() {
        beginArrangeMode()
    }

    @objc private func finishArrangeMode() {
        onShowSettings?()
    }

    private func rebuildPermanentItemsMenu() {
        permanentItemsMenu.removeAllItems()
        currentPermanentItems = shelfItemsProvider?().permanent ?? []

        guard !currentPermanentItems.isEmpty else {
            let emptyItem = NSMenuItem(title: "—", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            permanentItemsMenu.addItem(emptyItem)
            return
        }

        for (index, item) in currentPermanentItems.enumerated() {
            let menuItem = NSMenuItem(
                title: item.displayName,
                action: #selector(permanentMenuItemPressed(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.tag = index
            if let sourceImage = MenuBarItemBridge.settingsPreviewImage(for: item),
               let image = sourceImage.copy() as? NSImage {
                image.size = NSSize(width: 18, height: 18)
                menuItem.image = image
            }
            permanentItemsMenu.addItem(menuItem)
        }
    }

    @objc private func permanentMenuItemPressed(_ sender: NSMenuItem) {
        guard currentPermanentItems.indices.contains(sender.tag) else { return }
        temporarilyShowAndClick(currentPermanentItems[sender.tag])
    }

    private var statusItemWindowIDs: Set<CGWindowID> {
        Set([
            toggleItem.button?.window,
            separatorItem.button?.window,
            permanentSeparatorItem.button?.window
        ].compactMap { window in
            window.flatMap(windowID(for:))
        })
    }

    private func temporarilyShowAndClick(_ item: ManagedMenuBarItem) {
        guard MenuBarItemBridge.hasAccessibilityPermission else {
            MenuBarItemBridge.requestAccessibilityPermission()
            presentPermissionHelp(
                title: Localization.strings.accessibilityTitle,
                message: Localization.strings.accessibilityInstructions
            )
            return
        }
        guard let toggleWindowID = toggleItem.button?.window.flatMap(windowID(for:)) else {
            return
        }

        guard let controls = controlWindowIDs else { return }
        let storedCategory = Preferences.itemClassifications[item.preferenceKey]
            .flatMap(MenuBarItemCategory.init(rawValue:))
        let returnTargetWindowID = storedCategory == .permanent
            ? controls.permanentDivider
            : controls.hiddenDivider

        pendingRehideWorkItem?.cancel()
        MenuBarItemBridge.move(item, nextTo: toggleWindowID) { [weak self] moved in
            guard let self else { return }
            if moved {
                MenuBarItemBridge.click(item)
            }

            let workItem = DispatchWorkItem {
                Task { @MainActor in
                    MenuBarItemBridge.move(item, nextTo: returnTargetWindowID) { _ in }
                }
            }
            self.pendingRehideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: workItem)
        }
    }

    private func presentPermissionHelp(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: Localization.strings.acknowledge)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func toggleAutoCollapse() {
        Preferences.autoCollapseEnabled.toggle()
        preferencesDidChange()
    }

    @objc private func showSettings() {
        onShowSettings?()
    }

    private func presentInvalidOrderHelp() {
        onShowSettings?()
    }
}
