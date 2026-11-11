import AppKit
import SpookyKit
import SwiftUI

// MARK: - GeneralSettingsView

/// 通用设置立即生效，候选仅显示本机已安装的受支持终端。
struct GeneralSettingsView: View {
    /// 偏好只保存终端 Bundle Identifier。
    @AppStorage("terminalApplication")
    private var terminal = TerminalApplication.terminal.rawValue

    /// 单次补丁的警告阈值，单位为 1000 字节。
    @AppStorage("diffWarningKilobytes")
    private var diffWarning = WorkingCopyOperations.defaultWarningKilobytes

    /// 历史每页条数固定为四个档位。
    @AppStorage("historyPageSize")
    private var historyPageSize = 100

    /// 创建和发布分支时实时规范引用名。
    @AppStorage("cleanRefNames")
    private var cleanRefNames = true

    /// 检出、拉取与合并被本地改动挡住时询问是否先储藏。
    @AppStorage("offerAutoStash")
    private var offerAutoStash = true

    /// 自动归档陈旧或请求已合并的分支，与侧边栏视图设置同一个偏好。
    @AppStorage(SidebarPreferences.autoArchiveKey)
    private var autoArchiveBranches = SidebarPreferences.defaultFlag(SidebarPreferences.autoArchiveKey)

    /// 操作改动了已初始化子模块的指针后直接更新它们，不再询问。
    @AppStorage(SubmodulePreferences.alwaysUpdate)
    private var alwaysUpdateSubmodules = false

    /// 在主菜单显示 Developer 菜单。
    @AppStorage(DeveloperPreferences.showsMenuKey)
    private var showsDeveloperMenu = false

    /// General 表单按功能分为七组，组间以分隔线隔开；控件列宽 278 pt。
    var body: some View {
        SettingsForm {
            CloneDirectoryRow()

            terminalRow
                .padding(.top, SettingsFormLayout.popUpSpacing)

            SettingsSeparator()

            operationRows

            SettingsSeparator(next: .checkbox)

            confirmationRows

            SettingsSeparator()

            historyRows

            SettingsSeparator(previous: .comboBox)

            WorkingCopySettingsRows()

            SettingsSeparator()

            WindowSettingsRows()

            SettingsSeparator(next: .checkbox)

            toggleRow("settings.showDeveloperMenu", isOn: $showsDeveloperMenu)
        }
    }
}

// MARK: - Private

extension GeneralSettingsView {
    /// 大 Diff 警告阈值组合框里的预设值，单位为 1000 字节。
    private static let diffWarningChoices = [20, 50, 500, 1000, 5000, 10_000]

    /// 操作相关的设置：自动获取的间隔、被本地改动挡住时询问储藏、自动更新子模块、输入时规范引用名、自动归档分支。
    @ViewBuilder
    private var operationRows: some View {
        AutoFetchSettingsRow()

        // 勾选框组与上方的弹出菜单相隔 12，组内相隔 6
        toggleRow("stash.offerAutoStash", isOn: $offerAutoStash)
            .padding(.top, SettingsFormLayout.checkboxGroupSpacing)

        toggleRow("settings.autoUpdateSubmodules", isOn: $alwaysUpdateSubmodules)
            .padding(.top, SettingsFormLayout.checkboxSpacing)

        toggleRow("branch.cleanNames", isOn: $cleanRefNames)
            .padding(.top, SettingsFormLayout.checkboxSpacing)

        toggleRow("settings.autoArchive", isOn: $autoArchiveBranches)
            .padding(.top, SettingsFormLayout.checkboxSpacing)
    }

    /// 丢弃块的警告与服务器仓库的删除、覆盖确认列在一组，逐项打开或关闭；组内相隔 6。
    private var confirmationRows: some View {
        ForEach(Array(ServerConfirmation.allCases.enumerated()), id: \.element) { index, confirmation in
            ConfirmationRow(confirmation: confirmation)
                .padding(.top, index == 0 ? 0 : SettingsFormLayout.checkboxSpacing)
        }
    }

    /// 历史每页条数、提交日期格式、合并提交的 Diff 方式与大 Diff 的警告阈值。
    @ViewBuilder
    private var historyRows: some View {
        SettingsRow(AppLocalization.text("history.pageSize")) {
            Picker("", selection: $historyPageSize) {
                ForEach([100, 200, 500, 1000], id: \.self) {
                    Text(AppLocalization.text("history.commitCount", $0)).tag($0)
                }
            }
            .labelsHidden()
            .settingsColumnWidth()
            .accessibilityLabel(AppLocalization.text("history.pageSize"))
        }

        CommitDateFormatRow()
            .padding(.top, SettingsFormLayout.popUpSpacing)

        MergeDiffModeRow()
            .padding(.top, SettingsFormLayout.popUpSpacing)

        // 组合框是 AppKit 控件，没有文字基线可对，标签与它按竖直居中对齐。
        SettingsRow(AppLocalization.text("working.diffThreshold"), alignment: .center) {
            LimitComboBox(
                value: $diffWarning,
                choices: Self.diffWarningChoices,
                range: 0 ... 268_435,
                label: AppLocalization.text("working.diffThreshold")
            )
            .settingsColumnWidth()
        }
        .padding(.top, SettingsFormLayout.rowSpacing)
    }

    /// 终端选择行，每个候选显示应用图标与名称。
    private var terminalRow: some View {
        SettingsRow(AppLocalization.text("settings.terminal")) {
            Picker(AppLocalization.text("settings.terminal"), selection: $terminal) {
                ForEach(TerminalApplication.allCases.filter { $0.applicationURL != nil }) { application in
                    HStack(spacing: 8) {
                        if let url = application.applicationURL {
                            Image(nsImage: NSWorkspace.shared.menuIcon(forFile: url.path))
                                .accessibilityHidden(true)
                        }

                        Text(application.displayName)
                    }
                    .tag(application.rawValue)
                }
            }
            .labelsHidden()
            .settingsColumnWidth()
            .accessibilityIdentifier("terminal-application")
        }
    }

    /// 标签列留空、控件列放一个勾选框的一行。
    private func toggleRow(_ key: String, isOn: Binding<Bool>) -> some View {
        SettingsRow {
            Toggle(AppLocalization.text(key), isOn: isOn)
                .fixedSize(horizontal: false, vertical: true)
                .settingsColumnWidth()
        }
    }
}

// MARK: - ConfirmationRow

/// 一项可以关掉的确认：与确认框里的 “Do not ask me again” 读写同一个偏好，勾选后重新确认。
private struct ConfirmationRow: View {
    /// 这一项对应的确认。
    let confirmation: ServerConfirmation

    /// 确认是否打开，没有设置时打开。
    @AppStorage
    private var isOn: Bool

    /// 标签列留空，控件列放勾选框。
    var body: some View {
        SettingsRow {
            Toggle(AppLocalization.text(confirmation.titleKey), isOn: $isOn)
                .fixedSize(horizontal: false, vertical: true)
                .settingsColumnWidth()
        }
    }

    /// 按确认的偏好键读写。
    init(confirmation: ServerConfirmation) {
        self.confirmation = confirmation
        _isOn = AppStorage(wrappedValue: true, confirmation.key)
    }
}
