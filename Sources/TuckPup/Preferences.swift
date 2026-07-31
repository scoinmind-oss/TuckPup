import Foundation

enum Preferences {
    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let autoCollapseEnabled = "autoCollapseEnabled"
        static let autoCollapseDelay = "autoCollapseDelay"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.hasCompletedOnboarding: false,
            Key.autoCollapseEnabled: false,
            Key.autoCollapseDelay: 10.0
        ])
    }

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Key.hasCompletedOnboarding) }
        set { UserDefaults.standard.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    static var autoCollapseEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.autoCollapseEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.autoCollapseEnabled) }
    }

    static var autoCollapseDelay: TimeInterval {
        get {
            let value = UserDefaults.standard.double(forKey: Key.autoCollapseDelay)
            return value > 0 ? value : 10
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.autoCollapseDelay) }
    }
}
