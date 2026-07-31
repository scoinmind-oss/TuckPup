import AppKit
import ServiceManagement

@MainActor
final class SettingsWindowController: NSWindowController {
    private let onBeginArrange: () -> Void
    private let onPreferencesChanged: () -> Void

    private let autoCollapseCheckbox = NSButton(
        checkboxWithTitle: "展开后自动收起",
        target: nil,
        action: nil
    )
    private let delayPopup = NSPopUpButton()
    private let launchAtLoginCheckbox = NSButton(
        checkboxWithTitle: "登录 Mac 时自动启动",
        target: nil,
        action: nil
    )

    init(
        onBeginArrange: @escaping () -> Void,
        onPreferencesChanged: @escaping () -> Void
    ) {
        self.onBeginArrange = onBeginArrange
        self.onPreferencesChanged = onPreferencesChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "TuckPup 设置"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        configureContent()
        refreshControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refreshControls()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        let titleLabel = NSTextField(labelWithString: "TuckPup")
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)

        let subtitleLabel = NSTextField(
            wrappingLabelWithString: "点击菜单栏里的比熊头像，展开或收起你选择的图标。"
        )
        subtitleLabel.textColor = .secondaryLabelColor

        let instructions = NSTextField(
            wrappingLabelWithString: """
            设置隐藏范围：点击下面的按钮后，按住 ⌘ 键，先把比熊头像拖到隐藏区与常显区之间，再把细分隔线紧贴头像左侧。左侧图标会被收纳，右侧图标始终显示。
            """
        )
        instructions.maximumNumberOfLines = 0

        let arrangeButton = NSButton(
            title: "调整隐藏范围…",
            target: self,
            action: #selector(beginArrange)
        )
        arrangeButton.bezelStyle = .rounded

        autoCollapseCheckbox.target = self
        autoCollapseCheckbox.action = #selector(autoCollapseChanged)

        delayPopup.addItems(withTitles: ["5 秒", "10 秒", "15 秒", "30 秒"])
        delayPopup.target = self
        delayPopup.action = #selector(delayChanged)

        let delayRow = NSStackView(views: [
            NSTextField(labelWithString: "自动收起等待时间"),
            delayPopup
        ])
        delayRow.orientation = .horizontal
        delayRow.alignment = .centerY
        delayRow.distribution = .fill

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginChanged)

        let divider = NSBox()
        divider.boxType = .separator

        let shortcutLabel = NSTextField(
            wrappingLabelWithString: "左键：展开或收起　　右键：更多选项"
        )
        shortcutLabel.textColor = .secondaryLabelColor
        shortcutLabel.font = .systemFont(ofSize: 12)

        let stack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            instructions,
            arrangeButton,
            divider,
            autoCollapseCheckbox,
            delayRow,
            launchAtLoginCheckbox,
            shortcutLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            delayRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func refreshControls() {
        autoCollapseCheckbox.state = Preferences.autoCollapseEnabled ? .on : .off
        delayPopup.isEnabled = Preferences.autoCollapseEnabled

        let delays: [TimeInterval] = [5, 10, 15, 30]
        let index = delays.firstIndex(of: Preferences.autoCollapseDelay) ?? 1
        delayPopup.selectItem(at: index)

        if #available(macOS 13.0, *) {
            launchAtLoginCheckbox.state =
                SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            launchAtLoginCheckbox.isEnabled = false
        }
    }

    @objc private func beginArrange() {
        window?.orderOut(nil)
        onBeginArrange()
    }

    @objc private func autoCollapseChanged() {
        Preferences.autoCollapseEnabled = autoCollapseCheckbox.state == .on
        delayPopup.isEnabled = Preferences.autoCollapseEnabled
        onPreferencesChanged()
    }

    @objc private func delayChanged() {
        let delays: [TimeInterval] = [5, 10, 15, 30]
        let index = max(0, delayPopup.indexOfSelectedItem)
        Preferences.autoCollapseDelay = delays[index]
        onPreferencesChanged()
    }

    @objc private func launchAtLoginChanged() {
        guard #available(macOS 13.0, *) else { return }

        do {
            if launchAtLoginCheckbox.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginCheckbox.state =
                SMAppService.mainApp.status == .enabled ? .on : .off

            let alert = NSAlert(error: error)
            alert.messageText = "无法修改登录启动设置"
            alert.runModal()
        }
    }
}
