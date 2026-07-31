import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()

        let statusController = StatusBarController()
        let settingsController = SettingsWindowController(
            onBeginArrange: { [weak statusController] in
                statusController?.beginArrangeMode()
            },
            onPreferencesChanged: { [weak statusController] in
                statusController?.preferencesDidChange()
            }
        )

        statusController.onShowSettings = { [weak settingsController] in
            settingsController?.show()
        }

        statusBarController = statusController
        settingsWindowController = settingsController

        if Preferences.hasCompletedOnboarding {
            statusController.collapseAfterLaunch()
        } else {
            showOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showOnboarding() {
        guard let statusBarController else { return }
        let strings = Localization.strings

        let alert = NSAlert()
        alert.messageText = strings.welcome
        alert.informativeText = strings.onboardingInstructions
        alert.alertStyle = .informational
        alert.addButton(withTitle: strings.startSetup)
        alert.addButton(withTitle: strings.later)

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        Preferences.hasCompletedOnboarding = true

        if response == .alertFirstButtonReturn {
            statusBarController.beginArrangeMode()
        } else {
            statusBarController.collapseAfterLaunch()
        }
    }
}
