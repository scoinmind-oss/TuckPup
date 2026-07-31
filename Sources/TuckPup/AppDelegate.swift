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

        let alert = NSAlert()
        alert.messageText = "欢迎使用 TuckPup"
        alert.informativeText = """
        左键点击比熊头像，即可展开或收起菜单栏图标。

        第一次需要设置隐藏范围：按住 ⌘ 键，先把比熊头像拖到隐藏区与常显区之间，再把临时出现的分隔线紧贴头像左侧。分隔线左侧的图标会被收纳。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "开始设置")
        alert.addButton(withTitle: "稍后")

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
