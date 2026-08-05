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
    let layoutEditorTitle: String
    let layoutEditorInstructions: String
    let layoutPermanent: String
    let layoutHidden: String
    let layoutVisible: String
    let layoutDropHere: String
    let layoutRefresh: String
    let layoutPermissionHint: String
    let layoutAllowAccessibility: String
    let layoutAllowScreenRecording: String
    let layoutAccessibilityRequired: String
    let layoutItemsUnavailable: String
    let layoutMoving: String
    let layoutMoveSucceeded: String
    let layoutMoveFailed: String
    let layoutUnnamedItem: String
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
    let permanentDividerMarker: String
    let hiddenDividerMarker: String
    let acknowledge: String
    let showHiddenIcons: String
    let showPermanentIcons: String
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
    let screenRecordingTitle: String
    let screenRecordingInstructions: String
    let accessibilityTitle: String
    let accessibilityInstructions: String
    let noPermanentIconsTitle: String
    let noPermanentIconsInstructions: String
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
        settingsSubtitle: "Click the Bichon to open a scrollable icon shelf below the menu bar.",
        settingsInstructions: "Classify every detected menu bar item as always visible, hidden, or always hidden.",
        layoutEditorTitle: "Icon Shelf",
        layoutEditorInstructions: "Drag to classify or reorder. Changes are applied directly to the native menu bar.",
        layoutPermanent: "Hidden",
        layoutHidden: "Collapsed",
        layoutVisible: "Shown",
        layoutDropHere: "Drop icons here",
        layoutRefresh: "Refresh",
        layoutPermissionHint: "Accessibility identifies and moves icons. Screen Recording only improves icon previews.",
        layoutAllowAccessibility: "Allow Accessibility",
        layoutAllowScreenRecording: "Allow Icon Previews",
        layoutAccessibilityRequired: "Allow Accessibility before moving an icon.",
        layoutItemsUnavailable: "Menu bar items are temporarily unavailable. Try Refresh.",
        layoutMoving: "Moving icon…",
        layoutMoveSucceeded: "Shelf group updated.",
        layoutMoveFailed: "The icon could not be moved. Check Accessibility permission and try again.",
        layoutUnnamedItem: "Menu Bar Icon",
        adjustHiddenRange: "Manage Menu Bar Icons…",
        autoCollapse: "Auto collapse",
        autoCollapseDelay: "Rehide delay",
        launchAtLogin: "Launch at login",
        language: "Language",
        automaticSystem: "Automatic (System)",
        shortcutHint: "Left-click: Show or hide　　Right-click: More options",
        launchAtLoginError: "Unable to change the launch-at-login setting",
        arrangeTitle: "Adjust Hidden Range",
        arrangeInstructions: """
        Two separators are now visible. Hold ⌘ and arrange them from left to right:

        1. “P” marker: place it after icons that should always stay hidden.
        2. “H” marker: place it after normally hidden icons.
        3. Bichon: place it immediately to the right of the “H” marker.

        Right-click the Bichon and choose “Finish Adjusting” when done.
        """,
        permanentDividerMarker: "P",
        hiddenDividerMarker: "H",
        acknowledge: "Got It",
        showHiddenIcons: "Show Hidden Icons",
        showPermanentIcons: "Always-Hidden Icons",
        hideIcons: "Hide Icons",
        finishAdjusting: "Finish Adjusting",
        settings: "Settings…",
        quit: "Quit TuckPup",
        invalidPositionTitle: "The separator needs to be repositioned",
        invalidPositionInstructions: """
        Hold ⌘ and arrange the controls from left to right as “P”, “H”, then the Bichon.
        """,
        startAdjusting: "Start Adjusting",
        cancel: "Cancel",
        welcome: "Welcome to TuckPup",
        onboardingInstructions: """
        Left-click the Bichon in the menu bar to show or hide menu bar icons.

        During setup, two separators divide the menu bar into three areas: always-hidden icons, normally hidden icons, and always-visible icons. Hold ⌘ to drag the separators and the Bichon into place.
        """,
        startSetup: "Start Setup",
        later: "Later",
        screenRecordingTitle: "Allow Screen Recording",
        screenRecordingInstructions: "TuckPup needs Screen Recording permission only to display the real menu bar icons in the always-hidden bar. After granting it in System Settings, quit and reopen TuckPup.",
        accessibilityTitle: "Allow Accessibility",
        accessibilityInstructions: "TuckPup needs Accessibility permission to temporarily move and click the selected original menu bar icon.",
        noPermanentIconsTitle: "No always-hidden icons found",
        noPermanentIconsInstructions: "Choose Adjust Hidden Range, then place some icons to the left of the “P” marker."
    )

    private static let simplifiedChinese = AppStrings(
        settingsWindowTitle: "TuckPup 设置",
        settingsSubtitle: "点击比熊头像，在菜单栏下方打开可滑动的图标带。",
        settingsInstructions: "把检测到的每个菜单栏项目分为常显、隐藏或永久隐藏。",
        layoutEditorTitle: "滑动图标带",
        layoutEditorInstructions: "拖动图标进行分类或排序，调整会直接应用到原生菜单栏。",
        layoutPermanent: "隐藏区",
        layoutHidden: "收起区",
        layoutVisible: "显示区",
        layoutDropHere: "把图标拖到这里",
        layoutRefresh: "刷新",
        layoutPermissionHint: "识别所属程序和移动图标需要“辅助功能”权限；“屏幕录制”只用于显示真实图标预览。",
        layoutAllowAccessibility: "允许辅助功能",
        layoutAllowScreenRecording: "允许图标预览",
        layoutAccessibilityRequired: "请先允许“辅助功能”，再移动图标。",
        layoutItemsUnavailable: "暂时读不到菜单栏图标，请点“刷新”重试。",
        layoutMoving: "正在移动图标…",
        layoutMoveSucceeded: "图标带分类已更新。",
        layoutMoveFailed: "图标移动失败，请检查“辅助功能”权限后重试。",
        layoutUnnamedItem: "菜单栏图标",
        adjustHiddenRange: "管理菜单栏图标…",
        autoCollapse: "自动收起",
        autoCollapseDelay: "自动收起等待时间",
        launchAtLogin: "登录时启动",
        language: "语言",
        automaticSystem: "自动（跟随系统）",
        shortcutHint: "左键：展开或收起　　右键：更多选项",
        launchAtLoginError: "无法修改登录启动设置",
        arrangeTitle: "调整隐藏范围",
        arrangeInstructions: """
        菜单栏中已经出现两条分隔线。请按住 ⌘ 键，从左到右排列：

        1. “永”标记：放在“永久隐藏”图标的后面。
        2. “隐”标记：放在“普通隐藏”图标的后面。
        3. 比熊头像：紧贴在“隐”标记右侧。

        调整完后，右键比熊头像并选择“完成调整”。
        """,
        permanentDividerMarker: "永",
        hiddenDividerMarker: "隐",
        acknowledge: "知道了",
        showHiddenIcons: "显示隐藏图标",
        showPermanentIcons: "永久隐藏图标",
        hideIcons: "收起图标",
        finishAdjusting: "完成调整",
        settings: "设置…",
        quit: "退出 TuckPup",
        invalidPositionTitle: "需要重新放置分隔线",
        invalidPositionInstructions: """
        按住 ⌘ 键，从左到右依次放置“永”、“隐”和比熊头像。
        """,
        startAdjusting: "开始调整",
        cancel: "取消",
        welcome: "欢迎使用 TuckPup",
        onboardingInstructions: """
        左键点击比熊头像，即可展开或收起菜单栏图标。

        设置时会出现两条分隔线，把图标划分为“永久隐藏、普通隐藏、始终显示”三个区域。按住 ⌘ 键即可拖动分隔线和比熊头像。
        """,
        startSetup: "开始设置",
        later: "稍后",
        screenRecordingTitle: "请允许屏幕录制",
        screenRecordingInstructions: "TuckPup 只用此权限读取菜单栏图标的真实外观，用于永久隐藏栏。请在系统设置中允许后退出并重新打开 TuckPup。",
        accessibilityTitle: "请允许辅助功能",
        accessibilityInstructions: "TuckPup 需要辅助功能权限，才能把你点击的原生菜单栏图标临时移到可见位置并触发它。",
        noPermanentIconsTitle: "没有找到永久隐藏图标",
        noPermanentIconsInstructions: "请选择“调整隐藏范围”，把需要永久隐藏的图标放到“永”标记左侧。"
    )

    private static let japanese = AppStrings(
        settingsWindowTitle: "TuckPup 設定",
        settingsSubtitle: "ビションをクリックすると、メニューバーの下にスクロール可能なアイコン棚が開きます。",
        settingsInstructions: "検出した各項目を、常に表示・非表示・常に非表示のいずれかに分類します。",
        layoutEditorTitle: "アイコン棚",
        layoutEditorInstructions: "ドラッグして分類または並べ替えます。変更は標準メニューバーに直接反映されます。",
        layoutPermanent: "非表示",
        layoutHidden: "収納",
        layoutVisible: "表示",
        layoutDropHere: "ここにドロップ",
        layoutRefresh: "更新",
        layoutPermissionHint: "アイコンの識別と移動にはアクセシビリティが必要です。画面収録はプレビューにのみ使用します。",
        layoutAllowAccessibility: "アクセシビリティを許可",
        layoutAllowScreenRecording: "プレビューを許可",
        layoutAccessibilityRequired: "移動する前にアクセシビリティを許可してください。",
        layoutItemsUnavailable: "メニューバー項目を取得できません。更新してください。",
        layoutMoving: "アイコンを移動中…",
        layoutMoveSucceeded: "棚の分類を更新しました。",
        layoutMoveFailed: "移動できませんでした。アクセシビリティ権限を確認してください。",
        layoutUnnamedItem: "メニューバーアイコン",
        adjustHiddenRange: "メニューバーアイコンを管理…",
        autoCollapse: "自動収納",
        autoCollapseDelay: "自動収納までの時間",
        launchAtLogin: "ログイン時に起動",
        language: "言語",
        automaticSystem: "自動（システム）",
        shortcutHint: "左クリック：表示／非表示　　右クリック：その他のオプション",
        launchAtLoginError: "ログイン時起動の設定を変更できません",
        arrangeTitle: "非表示範囲を調整",
        arrangeInstructions: """
        2つのマーカーが表示されます。⌘キーを押しながら左から右へ配置してください：

        1. 「常」：常に非表示にするアイコンの後ろ。
        2. 「隠」：通常は非表示にするアイコンの後ろ。
        3. ビション：「隠」のすぐ右。

        完了したら、ビションを右クリックして「調整を完了」を選択してください。
        """,
        permanentDividerMarker: "常",
        hiddenDividerMarker: "隠",
        acknowledge: "了解",
        showHiddenIcons: "非表示アイコンを表示",
        showPermanentIcons: "常に非表示のアイコン",
        hideIcons: "アイコンを収納",
        finishAdjusting: "調整を完了",
        settings: "設定…",
        quit: "TuckPup を終了",
        invalidPositionTitle: "区切り線を配置し直してください",
        invalidPositionInstructions: """
        ⌘キーを押しながら、左から「常」、「隠」、ビションの順に配置してください。
        """,
        startAdjusting: "調整を開始",
        cancel: "キャンセル",
        welcome: "TuckPup へようこそ",
        onboardingInstructions: """
        メニューバーのビションを左クリックすると、アイコンを表示／非表示にできます。

        設定時には2本の区切り線で、常に非表示・通常は非表示・常に表示の3つの領域を作ります。⌘キーを押しながら区切り線とビションを移動してください。
        """,
        startSetup: "設定を開始",
        later: "後で",
        screenRecordingTitle: "画面収録を許可してください",
        screenRecordingInstructions: "常に非表示のバーに実際のメニューバーアイコンを表示するためにのみ使用します。許可後、TuckPup を終了して再度開いてください。",
        accessibilityTitle: "アクセシビリティを許可してください",
        accessibilityInstructions: "選択した元のメニューバーアイコンを一時的に表示してクリックするために必要です。",
        noPermanentIconsTitle: "常に非表示のアイコンがありません",
        noPermanentIconsInstructions: "「非表示範囲を調整」を選び、「常」の左側にアイコンを配置してください。"
    )
}
