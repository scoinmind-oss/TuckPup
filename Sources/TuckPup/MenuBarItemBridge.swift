import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

private typealias CGSConnectionID = Int32

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSGetWindowCount")
private func CGSGetWindowCount(
    _ connection: CGSConnectionID,
    _ targetConnection: CGSConnectionID,
    _ count: inout Int32
) -> CGError

@_silgen_name("CGSGetProcessMenuBarWindowList")
private func CGSGetProcessMenuBarWindowList(
    _ connection: CGSConnectionID,
    _ targetConnection: CGSConnectionID,
    _ capacity: Int32,
    _ windows: UnsafeMutablePointer<CGWindowID>,
    _ count: inout Int32
) -> CGError

@_silgen_name("CGSGetScreenRectForWindow")
private func CGSGetScreenRectForWindow(
    _ connection: CGSConnectionID,
    _ window: CGWindowID,
    _ rect: inout CGRect
) -> CGError

struct ManagedMenuBarItem: Hashable, Sendable {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let sourcePID: pid_t?
    let ownerName: String
    let sourceName: String
    let sourceBundleIdentifier: String
    let accessibilityTitle: String
    let accessibilityDescription: String
    let accessibilityIdentifier: String
    let title: String
    let isOnScreen: Bool

    init(
        windowID: CGWindowID,
        ownerPID: pid_t,
        sourcePID: pid_t? = nil,
        ownerName: String,
        sourceName: String = "",
        sourceBundleIdentifier: String = "",
        accessibilityTitle: String = "",
        accessibilityDescription: String = "",
        accessibilityIdentifier: String = "",
        title: String,
        isOnScreen: Bool = false
    ) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.sourcePID = sourcePID
        self.ownerName = ownerName
        self.sourceName = sourceName
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.accessibilityTitle = accessibilityTitle
        self.accessibilityDescription = accessibilityDescription
        self.accessibilityIdentifier = accessibilityIdentifier
        self.title = title
        self.isOnScreen = isOnScreen
    }

    var eventPID: pid_t {
        sourcePID ?? ownerPID
    }

    var displayName: String {
        if sourceBundleIdentifier == "com.apple.controlcenter",
           !accessibilityDescription.isEmpty {
            return accessibilityDescription.components(separatedBy: "，").first
                ?? accessibilityDescription
        }
        if !title.isEmpty, !isGenericTitle(title) { return title }
        if !accessibilityDescription.isEmpty { return accessibilityDescription }
        if !accessibilityTitle.isEmpty { return accessibilityTitle }
        if !sourceName.isEmpty { return sourceName }
        if ownerPID != 0 { return ownerName }
        return Localization.strings.layoutUnnamedItem
    }

    var preferenceKey: String {
        if !accessibilityIdentifier.isEmpty {
            return "inventory-v3|\(sourceBundleIdentifier)|ax-\(accessibilityIdentifier)"
        }
        if !sourceBundleIdentifier.isEmpty {
            // Third-party menu bar apps normally expose one item. Their bundle
            // identifier remains stable across launches even when Tahoe names
            // every window `Item-0` and assigns a new CGWindowID.
            if sourceBundleIdentifier != "com.apple.controlcenter" {
                return "inventory-v3|bundle-\(sourceBundleIdentifier)"
            }
            return "inventory-v3|\(sourceBundleIdentifier)|title-\(title)"
        }
        if !sourceName.isEmpty {
            return "inventory-v3|name-\(sourceName)|title-\(title)"
        }

        // Without Accessibility permission, Tahoe can redact both the source
        // application and the window title, or return the same generic
        // `Item-0` title for many unrelated icons. Include the live window ID
        // so dragging one anonymous icon never classifies all of them at once.
        let isRepeatedGenericTitle = title.range(
            of: #"^Item-\d+$"#,
            options: .regularExpression
        ) != nil
        if title.isEmpty || isRepeatedGenericTitle {
            return "inventory-v3|\(ownerName)|window-\(windowID)"
        }
        return "inventory-v3|\(ownerName)|\(title)"
    }

    private func isGenericTitle(_ title: String) -> Bool {
        title.range(of: #"^Item-\d+$"#, options: .regularExpression) != nil ||
        UUID(uuidString: title) != nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowID)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.windowID == rhs.windowID
    }
}

@MainActor
enum MenuBarItemBridge {
    enum RelativePosition {
        case left
        case right
    }

    private static let windowIDField = CGEventField(rawValue: 0x33)!

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static var hasScreenRecordingPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestAccessibilityPermission() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }

    nonisolated static func frame(of windowID: CGWindowID) -> CGRect? {
        var rect = CGRect.zero
        guard CGSGetScreenRectForWindow(CGSMainConnectionID(), windowID, &rect) == .success else {
            return nil
        }
        return rect
    }

    /// NSStatusBarWindow can report a 64-bit placeholder from `windowNumber`
    /// on newer macOS releases. Resolve the corresponding Core Graphics menu
    /// bar window by matching the owning process and on-screen frame instead.
    static func windowID(for statusWindow: NSWindow) -> CGWindowID? {
        let directNumber = statusWindow.windowNumber
        if directNumber > 0, directNumber <= Int(CGWindowID.max) {
            return CGWindowID(directNumber)
        }

        let targetFrame = statusWindow.frame
        return menuBarWindowIDs()
            .compactMap { windowID -> (CGWindowID, CGFloat)? in
                guard let candidateFrame = frame(of: windowID)
                else { return nil }

                // CGS uses a top-left screen origin while AppKit uses a
                // bottom-left origin. X and size are enough to uniquely match
                // the three status item windows.
                let distance = abs(candidateFrame.minX - targetFrame.minX)
                    + abs(candidateFrame.width - targetFrame.width)
                return (windowID, distance)
            }
            .min { $0.1 < $1.1 }
            .flatMap { match in
                match.1 <= 4 ? match.0 : nil
            }
    }

    static func windowID(
        closestToWidth expectedWidth: CGFloat,
        excluding excludedWindowIDs: Set<CGWindowID> = []
    ) -> CGWindowID? {
        menuBarWindowIDs()
            .filter { !excludedWindowIDs.contains($0) }
            .compactMap { windowID -> (CGWindowID, CGFloat)? in
                guard let candidateFrame = frame(of: windowID) else { return nil }
                return (windowID, abs(candidateFrame.width - expectedWidth))
            }
            .min { $0.1 < $1.1 }
            .flatMap { match in
                match.1 <= 1.5 ? match.0 : nil
            }
    }

    nonisolated static func allItems(
        excluding excludedWindowIDs: Set<CGWindowID>
    ) -> [ManagedMenuBarItem] {
        struct Candidate {
            let windowID: CGWindowID
            let frame: CGRect
            let ownerPID: pid_t
            let ownerName: String
            let title: String
            let isOnScreen: Bool
        }

        let candidates: [Candidate] = menuBarWindowIDs().compactMap { windowID in
            guard !excludedWindowIDs.contains(windowID) else { return nil }
            guard let itemFrame = frame(of: windowID),
                  itemFrame.width > 4,
                  itemFrame.width < 320,
                  itemFrame.height < 60
            else { return nil }

            guard let info = windowInfo(for: windowID) else { return nil }

            let ownerPID = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
            guard ownerPID != ProcessInfo.processInfo.processIdentifier else { return nil }

            let ownerName = info[kCGWindowOwnerName as String] as? String ?? "Menu Bar Item"
            let title = info[kCGWindowName as String] as? String ?? ""
            return Candidate(
                windowID: windowID,
                frame: itemFrame,
                ownerPID: ownerPID,
                ownerName: ownerName,
                title: title,
                isOnScreen: info[kCGWindowIsOnscreen as String] as? Bool ?? false
            )
        }

        let sourceIdentities = MenuBarSourcePIDResolver.resolve(candidates.map {
            MenuBarSourcePIDResolver.Window(
                windowID: $0.windowID,
                ownerPID: $0.ownerPID,
                bounds: $0.frame
            )
        })

        return candidates.map { candidate in
            let sourceIdentity = sourceIdentities[candidate.windowID]
            let sourcePID = sourceIdentity?.pid
            let sourceName = sourcePID
                .flatMap(NSRunningApplication.init(processIdentifier:))?
                .localizedName ?? ""
            let sourceBundleIdentifier = sourcePID
                .flatMap(NSRunningApplication.init(processIdentifier:))?
                .bundleIdentifier ?? ""
            return ManagedMenuBarItem(
                windowID: candidate.windowID,
                ownerPID: candidate.ownerPID,
                sourcePID: sourcePID,
                ownerName: candidate.ownerName,
                sourceName: sourceName,
                sourceBundleIdentifier: sourceBundleIdentifier,
                accessibilityTitle: sourceIdentity?.accessibilityTitle ?? "",
                accessibilityDescription: sourceIdentity?.accessibilityDescription ?? "",
                accessibilityIdentifier: sourceIdentity?.accessibilityIdentifier ?? "",
                title: candidate.title,
                isOnScreen: candidate.isOnScreen
            )
        }
        .sorted { lhs, rhs in
            let lhsX = candidates.first { $0.windowID == lhs.windowID }?.frame.minX ?? 0
            let rhsX = candidates.first { $0.windowID == rhs.windowID }?.frame.minX ?? 0
            return lhsX < rhsX
        }
    }

    static func item(for windowID: CGWindowID) -> ManagedMenuBarItem? {
        guard let info = windowInfo(for: windowID),
              let itemFrame = frame(of: windowID)
        else { return nil }
        let ownerPID = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
            ?? ProcessInfo.processInfo.processIdentifier
        let ownerName = info[kCGWindowOwnerName as String] as? String ?? "TuckPup"
        let title = info[kCGWindowName as String] as? String ?? ""
        let sourceIdentity = MenuBarSourcePIDResolver.resolve([
            MenuBarSourcePIDResolver.Window(
                windowID: windowID,
                ownerPID: ownerPID,
                bounds: itemFrame
            )
        ])[windowID]
        let sourcePID = sourceIdentity?.pid
        return ManagedMenuBarItem(
            windowID: windowID,
            ownerPID: ownerPID,
            sourcePID: sourcePID,
            ownerName: ownerName,
            sourceName: sourcePID
                .flatMap(NSRunningApplication.init(processIdentifier:))?
                .localizedName ?? "",
            sourceBundleIdentifier: sourcePID
                .flatMap(NSRunningApplication.init(processIdentifier:))?
                .bundleIdentifier ?? "",
            accessibilityTitle: sourceIdentity?.accessibilityTitle ?? "",
            accessibilityDescription: sourceIdentity?.accessibilityDescription ?? "",
            accessibilityIdentifier: sourceIdentity?.accessibilityIdentifier ?? "",
            title: title,
            isOnScreen: info[kCGWindowIsOnscreen as String] as? Bool ?? false
        )
    }

    static func image(for item: ManagedMenuBarItem) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            item.windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            return NSRunningApplication(processIdentifier: item.eventPID)?.icon
        }

        let image = NSImage(cgImage: cgImage, size: .zero)
        let targetHeight: CGFloat = 22
        let aspectRatio = CGFloat(cgImage.width) / max(1, CGFloat(cgImage.height))
        image.size = NSSize(width: min(72, max(18, targetHeight * aspectRatio)), height: targetHeight)
        return image
    }

    /// Settings favors a legible application icon over a menu bar snapshot.
    /// Menu bar snapshots often contain white template artwork captured from a
    /// dark or tinted menu bar, which disappears on a light settings window.
    static func settingsPreviewImage(for item: ManagedMenuBarItem) -> NSImage? {
        if isInputMenuItem(item), let icon = currentInputSourceIcon() {
            return icon
        }

        if item.sourceBundleIdentifier == "com.apple.controlcenter",
           let symbolName = controlCenterSymbolName(for: item),
           let symbol = NSImage(
               systemSymbolName: symbolName,
               accessibilityDescription: item.displayName
           )?.withSymbolConfiguration(.init(pointSize: 21, weight: .medium)) {
            symbol.isTemplate = true
            symbol.size = NSSize(width: 28, height: 28)
            return symbol
        }

        if let icon = NSRunningApplication(processIdentifier: item.eventPID)?.icon?.copy() as? NSImage {
            icon.size = NSSize(width: 30, height: 30)
            return icon
        }

        return image(for: item)
    }

    private static func isInputMenuItem(_ item: ManagedMenuBarItem) -> Bool {
        let identity = [
            item.sourceBundleIdentifier,
            item.sourceName,
            item.ownerName,
            item.displayName,
            item.accessibilityTitle,
            item.accessibilityDescription,
            item.accessibilityIdentifier
        ].joined(separator: " ").lowercased()

        return identity.contains("textinputmenuagent")
            || identity.contains("input menu")
            || identity.contains("输入法菜单")
            || identity.contains("入力メニュー")
    }

    private static func currentInputSourceIcon() -> NSImage? {
        let inputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let pointer = TISGetInputSourceProperty(
            inputSource,
            kTISPropertyIconImageURL
        ) else { return nil }

        let iconURL = Unmanaged<CFURL>
            .fromOpaque(pointer)
            .takeUnretainedValue() as URL
        guard let icon = NSImage(contentsOf: iconURL.absoluteURL) else { return nil }

        // Input-source menu artwork is designed as a monochrome menu-bar
        // template. Rendering it like other system symbols keeps it legible on
        // every tile color instead of showing TextInputMenuAgent's generic app
        // icon.
        icon.isTemplate = true
        icon.size = NSSize(width: 28, height: 28)
        return icon
    }

    private static func controlCenterSymbolName(for item: ManagedMenuBarItem) -> String? {
        let identity = [
            item.displayName,
            item.accessibilityDescription,
            item.accessibilityIdentifier,
            item.title
        ].joined(separator: " ").lowercased()

        let symbols: [(terms: [String], symbol: String)] = [
            (["wi-fi", "wifi", "无线局域网"], "wifi"),
            (["battery", "电池"], "battery.75percent"),
            (["clock", "时钟"], "clock"),
            (["now playing", "播放中"], "play.circle.fill"),
            (["input", "keyboard", "输入法", "abc"], "keyboard"),
            (["control center", "控制中心"], "switch.2"),
            (["screen mirroring", "屏幕镜像"], "rectangle.on.rectangle"),
            (["bluetooth", "蓝牙"], "bluetooth"),
            (["sound", "volume", "声音"], "speaker.wave.2.fill"),
            (["focus", "专注"], "moon.fill"),
            (["siri"], "siri")
        ]
        return symbols.first { mapping in
            mapping.terms.contains { identity.contains($0) }
        }?.symbol
    }

    static func move(
        _ item: ManagedMenuBarItem,
        nextTo targetWindowID: CGWindowID,
        completion: @escaping (Bool) -> Void
    ) {
        move(
            item,
            relativeTo: targetWindowID,
            position: .left,
            requireAdjacency: false,
            completion: completion
        )
    }

    static func move(
        _ item: ManagedMenuBarItem,
        relativeTo targetWindowID: CGWindowID,
        position: RelativePosition,
        requireAdjacency: Bool = false,
        completion: @escaping (Bool) -> Void
    ) {
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            completion(false)
            return
        }
        attemptMove(
            item,
            relativeTo: targetWindowID,
            position: position,
            requireAdjacency: requireAdjacency,
            attemptsRemaining: 5,
            completion: completion
        )
    }

    private static func attemptMove(
        _ item: ManagedMenuBarItem,
        relativeTo targetWindowID: CGWindowID,
        position: RelativePosition,
        requireAdjacency: Bool,
        attemptsRemaining: Int,
        completion: @escaping (Bool) -> Void
    ) {
        guard
            attemptsRemaining > 0,
            let itemFrame = frame(of: item.windowID),
            let targetFrame = frame(of: targetWindowID),
            let source = CGEventSource(stateID: .hidSystemState),
            let mouseDown = menuBarEvent(
                type: .leftMouseDown,
                location: CGPoint(x: itemFrame.midX, y: itemFrame.midY),
                itemWindowID: item.windowID,
                eventWindowID: item.windowID,
                targetPID: item.eventPID,
                source: source,
                flags: .maskCommand
            ),
            let mouseUp = menuBarEvent(
                type: .leftMouseUp,
                location: CGPoint(
                    x: position == .left ? targetFrame.minX + 1 : targetFrame.maxX - 1,
                    y: targetFrame.midY
                ),
                itemWindowID: item.windowID,
                eventWindowID: targetWindowID,
                targetPID: item.eventPID,
                source: source,
                flags: []
            )
        else {
            completion(false)
            return
        }

        source.localEventsSuppressionInterval = 0
        mouseDown.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            mouseUp.post(tap: .cghidEventTap)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
                mouseUp.post(tap: .cghidEventTap)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                guard let movedFrame = frame(of: item.windowID),
                      let latestTargetFrame = frame(of: targetWindowID)
                else {
                    completion(false)
                    return
                }

                let reachedDestination: Bool
                switch position {
                case .left:
                    reachedDestination = requireAdjacency
                        ? abs(movedFrame.maxX - latestTargetFrame.minX) <= 6
                        : movedFrame.maxX <= latestTargetFrame.minX + 3
                case .right:
                    reachedDestination = requireAdjacency
                        ? abs(movedFrame.minX - latestTargetFrame.maxX) <= 6
                        : movedFrame.minX >= latestTargetFrame.maxX - 3
                }

                if reachedDestination {
                    completion(true)
                } else if attemptsRemaining > 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        attemptMove(
                            item,
                            relativeTo: targetWindowID,
                            position: position,
                            requireAdjacency: requireAdjacency,
                            attemptsRemaining: attemptsRemaining - 1,
                            completion: completion
                        )
                    }
                } else {
                    completion(false)
                }
            }
        }
    }

    static func click(_ item: ManagedMenuBarItem) {
        guard
            let itemFrame = frame(of: item.windowID),
            let source = CGEventSource(stateID: .hidSystemState),
            let mouseDown = menuBarEvent(
                type: .leftMouseDown,
                location: CGPoint(x: itemFrame.midX, y: itemFrame.midY),
                itemWindowID: item.windowID,
                eventWindowID: item.windowID,
                targetPID: item.eventPID,
                source: source,
                flags: []
            ),
            let mouseUp = menuBarEvent(
                type: .leftMouseUp,
                location: CGPoint(x: itemFrame.midX, y: itemFrame.midY),
                itemWindowID: item.windowID,
                eventWindowID: item.windowID,
                targetPID: item.eventPID,
                source: source,
                flags: []
            )
        else {
            return
        }

        mouseDown.setIntegerValueField(.mouseEventClickState, value: 1)
        mouseUp.setIntegerValueField(.mouseEventClickState, value: 1)
        mouseDown.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            mouseUp.post(tap: .cghidEventTap)
        }
    }

    nonisolated private static func windowInfo(for windowID: CGWindowID) -> [String: Any]? {
        var pointer: UnsafeRawPointer? = UnsafeRawPointer(bitPattern: UInt(windowID))
        guard let array = CFArrayCreate(nil, &pointer, 1, nil),
              let list = CGWindowListCreateDescriptionFromArray(array) as? [[String: Any]]
        else { return nil }
        return list.first
    }

    nonisolated private static func menuBarWindowIDs() -> [CGWindowID] {
        var capacity: Int32 = 0
        guard CGSGetWindowCount(CGSMainConnectionID(), 0, &capacity) == .success,
              capacity > 0
        else { return [] }

        var windowIDs = [CGWindowID](repeating: 0, count: Int(capacity))
        var count: Int32 = 0
        guard CGSGetProcessMenuBarWindowList(
            CGSMainConnectionID(),
            0,
            capacity,
            &windowIDs,
            &count
        ) == .success else { return [] }

        return Array(windowIDs.prefix(Int(count)))
    }

    private static func menuBarEvent(
        type: CGEventType,
        location: CGPoint,
        itemWindowID: CGWindowID,
        eventWindowID: CGWindowID,
        targetPID: pid_t,
        source: CGEventSource,
        flags: CGEventFlags
    ) -> CGEvent? {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: location,
            mouseButton: .left
        ) else {
            return nil
        }

        event.flags = flags
        if targetPID > 0 {
            event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(targetPID))
        }
        event.setIntegerValueField(.eventSourceUserData, value: Int64(itemWindowID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(eventWindowID))
        event.setIntegerValueField(
            .mouseEventWindowUnderMousePointerThatCanHandleThisEvent,
            value: Int64(eventWindowID)
        )
        event.setIntegerValueField(windowIDField, value: Int64(eventWindowID))
        return event
    }
}
