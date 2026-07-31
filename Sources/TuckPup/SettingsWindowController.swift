import AppKit
import ServiceManagement

@MainActor
final class SettingsWindowController: NSWindowController {
    private let onBeginArrange: () -> Void
    private let onPreferencesChanged: () -> Void

    private let titleLabel = NSTextField(labelWithString: "TuckPup")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let instructionsLabel = NSTextField(wrappingLabelWithString: "")
    private let arrangeButton = NSButton(title: "", target: nil, action: nil)
    private let autoCollapseCheckbox = NSButton(
        checkboxWithTitle: "",
        target: nil,
        action: nil
    )
    private let delayLabel = NSTextField(labelWithString: "")
    private let delayPopup = NSPopUpButton()
    private let launchAtLoginCheckbox = NSButton(
        checkboxWithTitle: "",
        target: nil,
        action: nil
    )
    private let languageLabel = NSTextField(labelWithString: "")
    private let languagePopup = NSPopUpButton()
    private let shortcutLabel = NSTextField(wrappingLabelWithString: "")

    init(
        onBeginArrange: @escaping () -> Void,
        onPreferencesChanged: @escaping () -> Void
    ) {
        self.onBeginArrange = onBeginArrange
        self.onPreferencesChanged = onPreferencesChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        configureContent()
        applyLocalization()
        refreshControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        applyLocalization()
        refreshControls()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)

        subtitleLabel.textColor = .secondaryLabelColor

        instructionsLabel.maximumNumberOfLines = 0

        arrangeButton.target = self
        arrangeButton.action = #selector(beginArrange)
        arrangeButton.bezelStyle = .rounded

        autoCollapseCheckbox.target = self
        autoCollapseCheckbox.action = #selector(autoCollapseChanged)

        delayPopup.target = self
        delayPopup.action = #selector(delayChanged)

        let delayRow = NSStackView(views: [delayLabel, delayPopup])
        delayRow.orientation = .horizontal
        delayRow.alignment = .centerY
        delayRow.distribution = .fill

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginChanged)

        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        languagePopup.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let languageRow = NSStackView(views: [languageLabel, languagePopup])
        languageRow.orientation = .horizontal
        languageRow.alignment = .centerY
        languageRow.distribution = .fill

        let divider = NSBox()
        divider.boxType = .separator

        shortcutLabel.textColor = .secondaryLabelColor
        shortcutLabel.font = .systemFont(ofSize: 12)

        let stack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            instructionsLabel,
            arrangeButton,
            divider,
            autoCollapseCheckbox,
            delayRow,
            launchAtLoginCheckbox,
            languageRow,
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
            languageRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            languagePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func applyLocalization() {
        let strings = Localization.strings

        window?.title = strings.settingsWindowTitle
        subtitleLabel.stringValue = strings.settingsSubtitle
        instructionsLabel.stringValue = strings.settingsInstructions
        arrangeButton.title = strings.adjustHiddenRange
        autoCollapseCheckbox.title = strings.autoCollapse
        delayLabel.stringValue = strings.autoCollapseDelay
        launchAtLoginCheckbox.title = strings.launchAtLogin
        languageLabel.stringValue = strings.language
        shortcutLabel.stringValue = strings.shortcutHint

        delayPopup.removeAllItems()
        delayPopup.addItems(withTitles: [5, 10, 15, 30].map(Localization.seconds))

        languagePopup.removeAllItems()
        for language in AppLanguage.allCases {
            languagePopup.addItem(withTitle: Localization.displayName(for: language))
            languagePopup.lastItem?.representedObject = language.rawValue
        }
    }

    private func refreshControls() {
        autoCollapseCheckbox.state = Preferences.autoCollapseEnabled ? .on : .off
        delayPopup.isEnabled = Preferences.autoCollapseEnabled

        let delays: [TimeInterval] = [5, 10, 15, 30]
        let delayIndex = delays.firstIndex(of: Preferences.autoCollapseDelay) ?? 1
        delayPopup.selectItem(at: delayIndex)

        let languageIndex = AppLanguage.allCases.firstIndex(of: Preferences.appLanguage) ?? 0
        languagePopup.selectItem(at: languageIndex)

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

    @objc private func languageChanged() {
        guard
            let rawValue = languagePopup.selectedItem?.representedObject as? String,
            let language = AppLanguage(rawValue: rawValue)
        else {
            return
        }

        Preferences.appLanguage = language
        applyLocalization()
        refreshControls()
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
            alert.messageText = Localization.strings.launchAtLoginError
            alert.runModal()
        }
    }
}
