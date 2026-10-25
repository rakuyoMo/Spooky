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

    /// 丢弃块或行之前先确认。
    @AppStorage(WorkingCopyPreferences.warnsDiscardingChunks)
    private var warnsDiscardingChunks = true

    /// 自动归档已完全合并或陈旧的分支，与侧边栏视图设置同一个偏好。
    @AppStorage(SidebarPreferences.autoArchiveKey)
    private var autoArchiveBranches = SidebarPreferences.defaultFlag(SidebarPreferences.autoArchiveKey)

    /// General 表单按功能分为五组，组间以分隔线隔开；控件列固定为 278 pt。
    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            CloneDirectoryRow()

            terminalRow

            Divider()
                .gridCellUnsizedAxes(.horizontal)

            operationRows

            Divider()
                .gridCellUnsizedAxes(.horizontal)

            historyRows

            Divider()
                .gridCellUnsizedAxes(.horizontal)

            WorkingCopySettingsRows()

            Divider()
                .gridCellUnsizedAxes(.horizontal)

            WindowSettingsRows()
        }
        .padding(40)
        .frame(width: 900, alignment: .top)
    }
}

// MARK: - Private

extension GeneralSettingsView {
    /// 操作相关的设置：自动获取的间隔、被本地改动挡住时询问储藏、丢弃块前确认、输入时规范引用名、自动归档分支。
    @ViewBuilder
    private var operationRows: some View {
        AutoFetchSettingsRow()

        toggleRow("stash.offerAutoStash", isOn: $offerAutoStash)

        toggleRow("settings.warnDiscardingChunks", isOn: $warnsDiscardingChunks)

        toggleRow("branch.cleanNames", isOn: $cleanRefNames)

        toggleRow("settings.autoArchive", isOn: $autoArchiveBranches)
    }

    /// 历史每页条数、提交日期格式、合并提交的 Diff 方式与大 Diff 的警告阈值。
    @ViewBuilder
    private var historyRows: some View {
        GridRow {
            Text(AppLocalization.text("history.pageSize"))
            Picker("", selection: $historyPageSize) {
                ForEach([100, 200, 500, 1000], id: \.self) {
                    Text(AppLocalization.text("history.commitCount", $0)).tag($0)
                }
            }
            .labelsHidden()
            .frame(width: 278)
            .accessibilityLabel(AppLocalization.text("history.pageSize"))
        }

        CommitDateFormatRow()

        MergeDiffModeRow()

        GridRow {
            Text(AppLocalization.text("working.diffThreshold"))
                .gridColumnAlignment(.trailing)
            TextField("", value: $diffWarning, format: .number.grouping(.never))
                .frame(width: 100, alignment: .leading)
                .accessibilityLabel(AppLocalization.text("working.diffThreshold"))
                .onChange(of: diffWarning) { diffWarning = max(0, min(diffWarning, 268_435)) }
        }
    }

    /// 终端选择行，每个候选显示应用图标与名称。
    private var terminalRow: some View {
        GridRow {
            Text(AppLocalization.text("settings.terminal"))
                .gridColumnAlignment(.trailing)

            Picker(AppLocalization.text("settings.terminal"), selection: $terminal) {
                ForEach(TerminalApplication.allCases.filter { $0.applicationURL != nil }) { application in
                    HStack(spacing: 8) {
                        if let url = application.applicationURL {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .frame(width: 16, height: 16)
                                .accessibilityHidden(true)
                        }

                        Text(application.displayName)
                    }
                    .tag(application.rawValue)
                }
            }
            .labelsHidden()
            .frame(width: 278)
            .accessibilityIdentifier("terminal-application")
        }
    }

    /// 标签列留空、控件列放一个勾选框的一行。
    private func toggleRow(_ key: String, isOn: Binding<Bool>) -> some View {
        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Toggle(AppLocalization.text(key), isOn: isOn)
                .frame(width: 278, alignment: .leading)
        }
    }
}
