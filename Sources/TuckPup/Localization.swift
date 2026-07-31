import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"

    var resolved: ResolvedLanguage {
        switch self {
        case .system:
            return ResolvedLanguage.system
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .japanese:
            return .japanese
        }
    }
}

enum ResolvedLanguage {
    case english
    case simplifiedChinese
    case japanese

    static var system: ResolvedLanguage {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? "en"

        if preferredLanguage.hasPrefix("zh") {
            return .simplifiedChinese
        }
        if preferredLanguage.hasPrefix("ja") {
            return .japanese
        }
        return .english
    }
}

struct AppStrings {
    let settingsWindowTitle: String
    let settingsSubtitle: String
    let settingsInstructions: String
    let adjustHiddenRange: String
    let autoCollapse: String
    let autoCollapseDelay: String
    let launchAtLogin: String
    let language: String
    let automaticSystem: String
    let shortcutHint: String
    let launchAtLoginError: String
    let arrangeTitle: String
    let arrangeInstructions: String
    let acknowledge: String
    let showHiddenIcons: String
    let hideIcons: String
    let finishAdjusting: String
    let settings: String
    let quit: String
    let invalidPositionTitle: String
    let invalidPositionInstructions: String
    let startAdjusting: String
    let cancel: String
    let welcome: String
    let onboardingInstructions: String
    let startSetup: String
    let later: String
}

enum Localization {
    static var language: ResolvedLanguage {
        Preferences.appLanguage.resolved
    }

    static var strings: AppStrings {
        switch language {
        case .english:
            return english
        case .simplifiedChinese:
            return simplifiedChinese
        case .japanese:
            return japanese
        }
    }

    static func displayName(for language: AppLanguage) -> String {
        switch language {
        case .system:
            return strings.automaticSystem
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .japanese:
            return "日本語"
        }
    }

    static func seconds(_ value: Int) -> String {
        switch language {
        case .english:
            return value == 1 ? "\(value) second" : "\(value) seconds"
        case .simplifiedChinese:
            return "\(value) 秒"
        case .japanese:
            return "\(value) 秒"
        }
    }

    private static let english = AppStrings(
        settingsWindowTitle: "TuckPup Settings",
        settingsSubtitle: "Click the Bichon in the menu bar to show or hide your chosen icons.",
        settingsInstructions: """
        To choose the hidden range, click the button below. Hold ⌘ and drag the Bichon between the hidden and always-visible icons, then place the thin separator directly to its left. Icons on the left will be tucked away.
        """,
        adjustHiddenRange: "Adjust Hidden Range…",
        autoCollapse: "Automatically rehide after expanding",
        autoCollapseDelay: "Rehide delay",
        launchAtLogin: "Launch at login",
        language: "Language",
        automaticSystem: "Automatic (System)",
        shortcutHint: "Left-click: Show or hide　　Right-click: More options",
        launchAtLoginError: "Unable to change the launch-at-login setting",
        arrangeTitle: "Adjust Hidden Range",
        arrangeInstructions: """
        A thin separator is now visible in the menu bar. Hold ⌘ and complete these two steps:

        1. Drag the Bichon between the icons you want to hide and the icons you want to keep visible.
        2. Drag the thin separator directly to the left of the Bichon.

        Icons to the left of the separator will be tucked away. Icons to the right of the Bichon will remain visible. When finished, right-click the Bichon and choose “Finish Adjusting.”
        """,
        acknowledge: "Got It",
        showHiddenIcons: "Show Hidden Icons",
        hideIcons: "Hide Icons",
        finishAdjusting: "Finish Adjusting",
        settings: "Settings…",
        quit: "Quit TuckPup",
        invalidPositionTitle: "The separator needs to be repositioned",
        invalidPositionInstructions: """
        Hold ⌘, drag the Bichon between the hidden and always-visible icons, then place the separator directly to its left.
        """,
        startAdjusting: "Start Adjusting",
        cancel: "Cancel",
        welcome: "Welcome to TuckPup",
        onboardingInstructions: """
        Left-click the Bichon in the menu bar to show or hide menu bar icons.

        First, choose the hidden range: hold ⌘ and drag the Bichon between the icons you want to hide and the icons you want to keep visible. Then place the temporary separator directly to the left of the Bichon. Icons to the left of the separator will be tucked away.
        """,
        startSetup: "Start Setup",
        later: "Later"
    )

    private static let simplifiedChinese = AppStrings(
        settingsWindowTitle: "TuckPup 设置",
        settingsSubtitle: "点击菜单栏里的比熊头像，展开或收起你选择的图标。",
        settingsInstructions: """
        设置隐藏范围：点击下面的按钮后，按住 ⌘ 键，先把比熊头像拖到隐藏区与常显区之间，再把细分隔线紧贴头像左侧。左侧图标会被收纳，右侧图标始终显示。
        """,
        adjustHiddenRange: "调整隐藏范围…",
        autoCollapse: "展开后自动收起",
        autoCollapseDelay: "自动收起等待时间",
        launchAtLogin: "登录 Mac 时自动启动",
        language: "语言",
        automaticSystem: "自动（跟随系统）",
        shortcutHint: "左键：展开或收起　　右键：更多选项",
        launchAtLoginError: "无法修改登录启动设置",
        arrangeTitle: "调整隐藏范围",
        arrangeInstructions: """
        菜单栏中已经出现一条细分隔线。请按住 ⌘ 键完成两步：

        1. 把比熊头像拖到隐藏区与常显区之间。
        2. 把细分隔线紧贴在比熊头像左侧。

        分隔线左侧的图标会被收纳，头像右侧的图标始终显示。调整完后，右键比熊头像并选择“完成调整”。
        """,
        acknowledge: "知道了",
        showHiddenIcons: "显示隐藏图标",
        hideIcons: "收起图标",
        finishAdjusting: "完成调整",
        settings: "设置…",
        quit: "退出 TuckPup",
        invalidPositionTitle: "需要重新放置分隔线",
        invalidPositionInstructions: """
        按住 ⌘ 键，先把比熊头像拖到隐藏区与常显区之间，再把分隔线紧贴头像左侧。
        """,
        startAdjusting: "开始调整",
        cancel: "取消",
        welcome: "欢迎使用 TuckPup",
        onboardingInstructions: """
        左键点击比熊头像，即可展开或收起菜单栏图标。

        第一次需要设置隐藏范围：按住 ⌘ 键，先把比熊头像拖到隐藏区与常显区之间，再把临时出现的分隔线紧贴头像左侧。分隔线左侧的图标会被收纳。
        """,
        startSetup: "开始设置",
        later: "稍后"
    )

    private static let japanese = AppStrings(
        settingsWindowTitle: "TuckPup 設定",
        settingsSubtitle: "メニューバーのビションをクリックすると、選択したアイコンを表示／非表示にできます。",
        settingsInstructions: """
        非表示にする範囲を設定するには、下のボタンをクリックします。⌘キーを押しながら、ビションを非表示にするアイコンと常に表示するアイコンの間へドラッグし、細い区切り線をビションのすぐ左に置きます。区切り線の左側にあるアイコンが収納されます。
        """,
        adjustHiddenRange: "非表示範囲を調整…",
        autoCollapse: "展開後に自動で収納",
        autoCollapseDelay: "自動収納までの時間",
        launchAtLogin: "ログイン時に起動",
        language: "言語",
        automaticSystem: "自動（システム）",
        shortcutHint: "左クリック：表示／非表示　　右クリック：その他のオプション",
        launchAtLoginError: "ログイン時起動の設定を変更できません",
        arrangeTitle: "非表示範囲を調整",
        arrangeInstructions: """
        メニューバーに細い区切り線が表示されました。⌘キーを押しながら、次の2つの操作を行ってください：

        1. ビションを、非表示にするアイコンと常に表示するアイコンの間へドラッグします。
        2. 細い区切り線をビションのすぐ左へドラッグします。

        区切り線の左側にあるアイコンが収納され、ビションの右側にあるアイコンは常に表示されます。完了したら、ビションを右クリックして「調整を完了」を選択してください。
        """,
        acknowledge: "了解",
        showHiddenIcons: "非表示アイコンを表示",
        hideIcons: "アイコンを収納",
        finishAdjusting: "調整を完了",
        settings: "設定…",
        quit: "TuckPup を終了",
        invalidPositionTitle: "区切り線を配置し直してください",
        invalidPositionInstructions: """
        ⌘キーを押しながら、ビションを非表示にするアイコンと常に表示するアイコンの間へドラッグし、区切り線をビションのすぐ左に置いてください。
        """,
        startAdjusting: "調整を開始",
        cancel: "キャンセル",
        welcome: "TuckPup へようこそ",
        onboardingInstructions: """
        メニューバーのビションを左クリックすると、アイコンを表示／非表示にできます。

        初回は非表示範囲の設定が必要です。⌘キーを押しながら、ビションを非表示にするアイコンと常に表示するアイコンの間へドラッグし、一時的に表示される区切り線をビションのすぐ左に置きます。区切り線の左側にあるアイコンが収納されます。
        """,
        startSetup: "設定を開始",
        later: "後で"
    )
}
