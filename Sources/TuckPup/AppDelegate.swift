import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()

        let statusController = StatusBarController()
        let layoutModel = MenuBarLayoutModel(
            controlWindowIDs: { [weak statusController] in
                statusController?.controlWindowIDs
            },
            moveNativeItem: { [weak statusController] item, category, beforeItem, completion in
                statusController?.moveNativeItem(
                    item,
                    to: category,
                    before: beforeItem,
                    completion: completion
                ) ?? completion(false)
            },
            reconcileNativeCategories: { [weak statusController] layout, completion in
                statusController?.reconcileNativeCategories(layout, completion: completion)
                    ?? completion(false)
            }
        )
        let settingsController = SettingsWindowController(
            layoutModel: layoutModel,
            onPrepareLayoutEditing: { [weak statusController] in
                statusController?.prepareForLayoutEditing()
            },
            onFinishLayoutEditing: { [weak statusController] in
                statusController?.finishLayoutEditing()
            },
            onPreferencesChanged: { [weak statusController] in
                statusController?.preferencesDidChange()
            }
        )

        statusController.onShowSettings = { [weak settingsController] in
            settingsController?.show()
        }
        statusController.shelfItemsProvider = { [weak layoutModel] in
            (
                regular: layoutModel?.items(in: .hidden) ?? [],
                permanent: layoutModel?.items(in: .permanent) ?? []
            )
        }

        statusBarController = statusController
        settingsWindowController = settingsController

        // Build the complete off-screen inventory shortly after launch. This
        // does not expand either hidden section and also makes the compact
        // always-hidden bar available without opening Settings first.
        layoutModel.refresh(after: 1.2)

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
            settingsWindowController?.show()
        } else {
            statusBarController.collapseAfterLaunch()
        }
    }
}
