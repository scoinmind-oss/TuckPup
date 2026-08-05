import Foundation

enum Preferences {
    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let autoCollapseEnabled = "autoCollapseEnabled"
        static let autoCollapseDelay = "autoCollapseDelay"
        static let appLanguage = "appLanguage"
        static let permanentSectionConfigured = "permanentSectionConfigured"
        static let didRepairStatusItemPositionsV2 = "didRepairStatusItemPositionsV2"
        static let permanentItemKeys = "permanentItemKeys"
        static let itemClassifications = "itemClassifications"
        static let itemOrder = "itemOrder"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.hasCompletedOnboarding: false,
            Key.autoCollapseEnabled: false,
            Key.autoCollapseDelay: 10.0,
            Key.appLanguage: AppLanguage.system.rawValue,
            Key.permanentSectionConfigured: false,
            Key.permanentItemKeys: [String](),
            Key.itemClassifications: [String: String](),
            Key.itemOrder: [String]()
        ])

        // Earlier builds could leave TuckPup's own controls underneath the
        // camera notch. Give the Bichon and its two section dividers stable,
        // rightmost preferred positions once, before any NSStatusItem exists.
        // Users can still Command-drag menu bar items after this migration.
        if !UserDefaults.standard.bool(forKey: Key.didRepairStatusItemPositionsV2) {
            UserDefaults.standard.set(0.0, forKey: "NSStatusItem Preferred Position tuckpup.toggle")
            UserDefaults.standard.set(1.0, forKey: "NSStatusItem Preferred Position tuckpup.separator")
            UserDefaults.standard.set(2.0, forKey: "NSStatusItem Preferred Position tuckpup.permanent-separator")
            UserDefaults.standard.set(true, forKey: Key.didRepairStatusItemPositionsV2)
        }
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

    static var appLanguage: AppLanguage {
        get {
            let rawValue = UserDefaults.standard.string(forKey: Key.appLanguage)
            return AppLanguage(rawValue: rawValue ?? "") ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.appLanguage) }
    }

    static var permanentSectionConfigured: Bool {
        get { UserDefaults.standard.bool(forKey: Key.permanentSectionConfigured) }
        set { UserDefaults.standard.set(newValue, forKey: Key.permanentSectionConfigured) }
    }

    static var permanentItemKeys: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: Key.permanentItemKeys) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: Key.permanentItemKeys)
        }
    }

    static var itemClassifications: [String: String] {
        get {
            UserDefaults.standard.dictionary(forKey: Key.itemClassifications)
                as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.itemClassifications)
        }
    }

    static var itemOrder: [String] {
        get { UserDefaults.standard.stringArray(forKey: Key.itemOrder) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Key.itemOrder) }
    }
}
