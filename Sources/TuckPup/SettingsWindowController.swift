import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let layoutModel: MenuBarLayoutModel
    private let onPrepareLayoutEditing: () -> Void
    private let onFinishLayoutEditing: () -> Void
    private let onPreferencesChanged: () -> Void

    private let layoutHostingView: NSHostingView<MenuBarLayoutEditorView>
    private let autoCollapseCheckbox = NSButton(
        checkboxWithTitle: "",
        target: nil,
        action: nil
    )
    private let delayPopup = NSPopUpButton()
    private let launchAtLoginCheckbox = NSButton(
        checkboxWithTitle: "",
        target: nil,
        action: nil
    )
    private let languageLabel = NSTextField(labelWithString: "")
    private let languagePopup = NSPopUpButton()

    init(
        layoutModel: MenuBarLayoutModel,
        onPrepareLayoutEditing: @escaping () -> Void,
        onFinishLayoutEditing: @escaping () -> Void,
        onPreferencesChanged: @escaping () -> Void
    ) {
        self.layoutModel = layoutModel
        self.onPrepareLayoutEditing = onPrepareLayoutEditing
        self.onFinishLayoutEditing = onFinishLayoutEditing
        self.onPreferencesChanged = onPreferencesChanged
        self.layoutHostingView = NSHostingView(
            rootView: MenuBarLayoutEditorView(model: layoutModel)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 430),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 760, height: 410)
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        // The layout editor needs to receive drag gestures anywhere in its
        // content. Only the actual title bar should move the settings window.
        window.isMovableByWindowBackground = false
        window.backgroundColor = .clear
        window.center()

        super.init(window: window)
        window.delegate = self
        configureContent()
        applyLocalization()
        refreshControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        onPrepareLayoutEditing()
        applyLocalization()
        refreshControls()
        layoutModel.refresh(after: 0.3)
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        let backgroundView = NSVisualEffectView(frame: contentView.bounds)
        backgroundView.material = .underWindowBackground
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.autoresizingMask = [.width, .height]
        contentView.addSubview(backgroundView)

        // A restrained neutral wash keeps the desktop color from becoming too
        // prominent while preserving one continuous material under the titlebar.
        let backgroundTint = NSView(frame: contentView.bounds)
        backgroundTint.wantsLayer = true
        backgroundTint.layer?.backgroundColor = NSColor.windowBackgroundColor
            .withAlphaComponent(0.58).cgColor
        backgroundTint.autoresizingMask = [.width, .height]
        contentView.addSubview(backgroundTint, positioned: .above, relativeTo: backgroundView)

        autoCollapseCheckbox.target = self
        autoCollapseCheckbox.action = #selector(autoCollapseChanged)
        autoCollapseCheckbox.font = .systemFont(ofSize: 13)

        delayPopup.target = self
        delayPopup.action = #selector(delayChanged)
        delayPopup.font = .systemFont(ofSize: 13)
        delayPopup.setContentHuggingPriority(.required, for: .horizontal)

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginChanged)
        launchAtLoginCheckbox.font = .systemFont(ofSize: 13)

        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        languagePopup.font = .systemFont(ofSize: 13)
        languageLabel.font = .systemFont(ofSize: 13)
        languagePopup.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let languageRow = NSStackView(views: [languageLabel, languagePopup])
        languageRow.orientation = .horizontal
        languageRow.alignment = .centerY
        languageRow.distribution = .fill

        let behaviorRow = NSStackView(views: [autoCollapseCheckbox, delayPopup])
        behaviorRow.orientation = .horizontal
        behaviorRow.alignment = .centerY
        behaviorRow.spacing = 10

        let firstSeparator = NSBox()
        firstSeparator.boxType = .separator
        let secondSeparator = NSBox()
        secondSeparator.boxType = .separator

        let preferencesStack = NSStackView(views: [
            behaviorRow,
            firstSeparator,
            launchAtLoginCheckbox,
            secondSeparator,
            languageRow
        ])
        preferencesStack.orientation = .horizontal
        preferencesStack.alignment = .centerY
        preferencesStack.spacing = 16
        preferencesStack.translatesAutoresizingMaskIntoConstraints = false

        let preferencesCard = NSView()
        preferencesCard.wantsLayer = true
        preferencesCard.layer?.backgroundColor = NSColor.controlBackgroundColor
            .withAlphaComponent(0.46).cgColor
        preferencesCard.layer?.cornerRadius = 13
        preferencesCard.layer?.cornerCurve = .continuous
        preferencesCard.layer?.borderWidth = 0.5
        preferencesCard.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.28).cgColor
        preferencesCard.addSubview(preferencesStack)
        NSLayoutConstraint.activate([
            preferencesStack.leadingAnchor.constraint(equalTo: preferencesCard.leadingAnchor, constant: 14),
            preferencesStack.trailingAnchor.constraint(lessThanOrEqualTo: preferencesCard.trailingAnchor, constant: -14),
            preferencesStack.centerYAnchor.constraint(equalTo: preferencesCard.centerYAnchor),
            firstSeparator.heightAnchor.constraint(equalToConstant: 24),
            secondSeparator.heightAnchor.constraint(equalToConstant: 24),
            delayPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 86)
        ])

        let stack = NSStackView(views: [
            layoutHostingView,
            preferencesCard
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack, positioned: .above, relativeTo: backgroundTint)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            layoutHostingView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            layoutHostingView.heightAnchor.constraint(greaterThanOrEqualToConstant: 246),
            preferencesCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            preferencesCard.heightAnchor.constraint(equalToConstant: 54),
            languagePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 142),
        ])
    }

    private func applyLocalization() {
        let strings = Localization.strings

        window?.title = strings.settingsWindowTitle
        autoCollapseCheckbox.title = strings.autoCollapse
        launchAtLoginCheckbox.title = strings.launchAtLogin
        languageLabel.stringValue = strings.language

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

    func windowWillClose(_ notification: Notification) {
        onFinishLayoutEditing()
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
        layoutModel.localizationDidChange()
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
