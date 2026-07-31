import AppKit

@MainActor
final class StatusBarController: NSObject {
    var onShowSettings: (() -> Void)?

    private let toggleItem = NSStatusBar.system.statusItem(withLength: 24)
    private let separatorItem = NSStatusBar.system.statusItem(withLength: 1)
    private let normalSeparatorLength: CGFloat = 1
    private let arrangeSeparatorLength: CGFloat = 18
    private let collapsePadding: CGFloat = 64

    private var collapsedLength: CGFloat = 1_792
    private var isArranging = false
    private var autoCollapseTimer: Timer?
    private var clickLocked = false
    private lazy var contextMenu = makeContextMenu()

    private var isCollapsed: Bool {
        separatorItem.length > 50
    }

    override init() {
        super.init()
        updateCollapsedLength()
        configureItems()
        observeScreenChanges()
    }

    func collapseAfterLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.collapse()
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
        let strings = Localization.strings

        expand()
        isArranging = true
        separatorItem.length = arrangeSeparatorLength
        separatorItem.button?.title = "│"
        separatorItem.button?.font = .systemFont(ofSize: 13, weight: .semibold)

        let alert = NSAlert()
        alert.messageText = strings.arrangeTitle
        alert.informativeText = strings.arrangeInstructions
        alert.addButton(withTitle: strings.acknowledge)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func configureItems() {
        toggleItem.autosaveName = "tuckpup.toggle"
        separatorItem.autosaveName = "tuckpup.separator"
        toggleItem.isVisible = true
        separatorItem.isVisible = true

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        let wasCollapsed = isCollapsed
        updateCollapsedLength(preferLiveGeometry: !wasCollapsed)
        if wasCollapsed {
            separatorItem.length = collapsedLength
        }
    }

    private func updateCollapsedLength(preferLiveGeometry: Bool = true) {
        let widestScreen = NSScreen.screens.map(\.frame.width).max() ?? 1_728
        let fallbackLength = min(widestScreen + collapsePadding, 10_000)

        guard
            preferLiveGeometry,
            let window = separatorItem.button?.window,
            let screen = window.screen
        else {
            collapsedLength = max(500, fallbackLength)
            return
        }

        let distanceFromScreenLeft = window.frame.minX - screen.frame.minX
        let requiredLength = distanceFromScreenLeft + collapsePadding
        let screenBound = screen.frame.width + collapsePadding
        collapsedLength = max(500, min(requiredLength, screenBound))
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
        isCollapsed ? expand() : collapse()
    }

    private func collapse() {
        guard !isCollapsed else { return }
        guard hasValidItemOrder else {
            presentInvalidOrderHelp()
            return
        }

        isArranging = false
        separatorItem.button?.title = ""
        updateCollapsedLength()
        separatorItem.length = collapsedLength
        autoCollapseTimer?.invalidate()
    }

    private func expand() {
        guard isCollapsed else {
            if Preferences.autoCollapseEnabled {
                scheduleAutoCollapse()
            }
            return
        }

        separatorItem.length = isArranging ? arrangeSeparatorLength : normalSeparatorLength
        if Preferences.autoCollapseEnabled {
            scheduleAutoCollapse()
        }
    }

    private var hasValidItemOrder: Bool {
        guard
            let toggleX = toggleItem.button?.window?.frame.minX,
            let separatorX = separatorItem.button?.window?.frame.minX
        else {
            return true
        }
        return toggleX >= separatorX
    }

    private func scheduleAutoCollapse() {
        autoCollapseTimer?.invalidate()
        guard Preferences.autoCollapseEnabled, !isCollapsed, !isArranging else { return }

        autoCollapseTimer = Timer.scheduledTimer(
            withTimeInterval: Preferences.autoCollapseDelay,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isMouseInMenuBar {
                    self.scheduleAutoCollapse()
                } else {
                    self.collapse()
                }
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
        guard contextMenu.items.count >= 7 else { return }
        let strings = Localization.strings

        contextMenu.items[0].title =
            isCollapsed ? strings.showHiddenIcons : strings.hideIcons

        let arrangeItem = contextMenu.items[1]
        arrangeItem.title =
            isArranging ? strings.finishAdjusting : strings.adjustHiddenRange
        arrangeItem.action = isArranging
            ? #selector(finishArrangeMode)
            : #selector(beginArrangeFromMenu)

        contextMenu.items[3].title = strings.autoCollapse
        contextMenu.items[3].state = Preferences.autoCollapseEnabled ? .on : .off
        contextMenu.items[4].title = strings.settings
        contextMenu.items[6].title = strings.quit
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
        isArranging = false
        separatorItem.button?.title = ""
        separatorItem.length = normalSeparatorLength
        Preferences.hasCompletedOnboarding = true
    }

    @objc private func toggleAutoCollapse() {
        Preferences.autoCollapseEnabled.toggle()
        preferencesDidChange()
    }

    @objc private func showSettings() {
        onShowSettings?()
    }

    private func presentInvalidOrderHelp() {
        let strings = Localization.strings
        let alert = NSAlert()
        alert.messageText = strings.invalidPositionTitle
        alert.informativeText = strings.invalidPositionInstructions
        alert.addButton(withTitle: strings.startAdjusting)
        alert.addButton(withTitle: strings.cancel)
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            beginArrangeMode()
        }
    }
}
