import SwiftUI

// MARK: - SettingsPage

/// 设置窗口的一页：页签名、页签图标与内容视图。
///
/// 页签按 ``all`` 的顺序排列；加一页只需定义它并把它放进 ``all``。
@MainActor
struct SettingsPage {
    /// 页签名的资源键，也是这一页在页签控制器里的标识。
    let key: String

    /// 页签图标的 SF Symbol。
    let symbol: String

    /// 生成这一页的内容视图。
    let content: () -> AnyView
}

// MARK: - Pages

extension SettingsPage {
    /// 页签的顺序。
    static let all: [SettingsPage] = [
        .general,
        .appearance,
        .gitConfig,
        .text,
        .editor,
        .themes,
        .userProfiles,
        .integration,
        .environment,
        .updates,
    ]

    /// 克隆目录、终端、自动获取、历史、工作区列表与窗口恢复等通用设置。
    static let general = SettingsPage(key: "settings.general", symbol: "gearshape") {
        AnyView(GeneralSettingsView())
    }

    /// App 的浅色、深色或跟随系统外观。
    static let appearance = SettingsPage(key: "settings.appearance", symbol: "paintpalette") {
        AnyView(AppearanceSettingsView())
    }

    /// 本机全局 Git 配置里的提交人身份与提交签名。
    static let gitConfig = SettingsPage(key: "settings.gitConfig", symbol: "arrow.triangle.branch") {
        AnyView(GitConfigSettingsView())
    }

    /// 语法着色、不可见字符与 Tab 宽度。
    static let text = SettingsPage(key: "settings.text", symbol: "note.text") {
        AnyView(TextSettingsView())
    }

    /// 提交信息编辑器的字数、折行与注释行。
    static let editor = SettingsPage(key: "settings.editor", symbol: "square.and.pencil") {
        AnyView(EditorSettingsView())
    }

    /// 文本区主题。
    static let themes = SettingsPage(key: "settings.themes", symbol: "paintbrush") {
        AnyView(ThemesSettingsView())
    }

    /// 身份档案。
    static let userProfiles = SettingsPage(key: "settings.profiles", symbol: "rectangle.stack.person.crop") {
        AnyView(UserProfilesSettingsView())
    }

    /// Gerrit 推送、Issue 追踪与 SSH agent 等与外部服务和工具的集成。
    static let integration = SettingsPage(key: "settings.integration", symbol: "gearshape.2") {
        AnyView(IntegrationSettingsView())
    }

    /// 本机执行 Git 时附加的环境变量。
    static let environment = SettingsPage(key: "settings.environment", symbol: "apple.terminal") {
        AnyView(EnvironmentSettingsView())
    }

    /// 更新通道、自动检查与下载、检查间隔与最近一次检查。
    static let updates = SettingsPage(key: "settings.updates", symbol: "arrow.down.circle") {
        AnyView(UpdatesSettingsView())
    }
}
