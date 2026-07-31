import AppKit

@MainActor
final class StatusBarController: NSObject {
    var onShowSettings: (() -> Void)?

    private let toggleItem = NSStatusBar.system.statusItem(withLength: 24)
    private let separatorItem = NSStatusBar.system.statusItem(withLength: 1)
    private let normalSeparatorLength: CGFloat = 1
    private let arrangeSeparatorLength: CGFloat = 18

    private var collapsedLength: CGFloat = 2_000
    private var isArranging = false
    private var autoCollapseTimer: Timer?
    private var clickLocked = false

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
        expand()
        isArranging = true
        separatorItem.length = arrangeSeparatorLength
        separatorItem.button?.title = "│"
        separatorItem.button?.font = .systemFont(ofSize: 13, weight: .semibold)
        separatorItem.button?.toolTip = "按住 ⌘ 拖动这条分隔线"

        let alert = NSAlert()
        alert.messageText = "调整隐藏范围"
        alert.informativeText = """
        菜单栏中已经出现一条细分隔线。请按住 ⌘ 键完成两步：

        1. 把比熊头像拖到隐藏区与常显区之间。
        2. 把细分隔线紧贴在比熊头像左侧。

        分隔线左侧的图标会被收纳，头像右侧的图标始终显示。调整完后，右键比熊头像并选择“完成调整”。
        """
        alert.addButton(withTitle: "知道了")
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
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "TuckPup：左键展开或收起，右键打开菜单"
        }

        if let separatorButton = separatorItem.button {
            separatorButton.title = ""
            separatorButton.target = self
            separatorButton.action = #selector(separatorPressed(_:))
            separatorButton.sendAction(on: [.rightMouseUp])
            separatorButton.toolTip = "TuckPup 隐藏范围分隔线"
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
        updateCollapsedLength()
        if wasCollapsed {
            separatorItem.length = collapsedLength
        }
    }

    private func updateCollapsedLength() {
        let widestScreen = NSScreen.screens.map(\.frame.width).max() ?? 1_728
        collapsedLength = max(500, min(widestScreen * 2, 10_000))
    }

    @objc private func toggleButtonPressed(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(from: sender)
            return
        }

        guard !clickLocked else { return }
        clickLocked = true
        toggle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
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
        let menu = makeContextMenu()
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.maxY + 5),
            in: button
        )
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()

        let toggleTitle = isCollapsed ? "显示隐藏图标" : "收起图标"
        let toggleMenuItem = NSMenuItem(
            title: toggleTitle,
            action: #selector(toggleFromMenu),
            keyEquivalent: ""
        )
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        if isArranging {
            let finishItem = NSMenuItem(
                title: "完成调整",
                action: #selector(finishArrangeMode),
                keyEquivalent: ""
            )
            finishItem.target = self
            menu.addItem(finishItem)
        } else {
            let arrangeItem = NSMenuItem(
                title: "调整隐藏范围…",
                action: #selector(beginArrangeFromMenu),
                keyEquivalent: ""
            )
            arrangeItem.target = self
            menu.addItem(arrangeItem)
        }

        menu.addItem(.separator())

        let autoItem = NSMenuItem(
            title: "自动收起",
            action: #selector(toggleAutoCollapse),
            keyEquivalent: ""
        )
        autoItem.target = self
        autoItem.state = Preferences.autoCollapseEnabled ? .on : .off
        menu.addItem(autoItem)

        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 TuckPup",
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
        let alert = NSAlert()
        alert.messageText = "需要重新放置分隔线"
        alert.informativeText = """
        按住 ⌘ 键，先把比熊头像拖到隐藏区与常显区之间，再把分隔线紧贴头像左侧。
        """
        alert.addButton(withTitle: "开始调整")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            beginArrangeMode()
        }
    }
}
