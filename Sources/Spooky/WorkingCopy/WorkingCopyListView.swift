import AppKit
import SpookyKit
import SwiftUI

// MARK: - WorkingCopyListView

/// 工作区列表保留所有状态条目，刷新期间仍展示旧快照。
struct WorkingCopyListView: View {
    /// 当前仓库会话。
    @Bindable
    var session: RepositorySession

    /// 是否显示被忽略的文件，供视图设置菜单标出勾选。
    @AppStorage(WorkingCopyPreferences.showIgnored)
    private var showsIgnored = false

    /// 是否显示 assume-unchanged 文件，供视图设置菜单标出勾选。
    @AppStorage(WorkingCopyPreferences.showAssumeUnchanged)
    private var showsAssumeUnchanged = false

    /// 分支头、提交区与铺到底的状态表；刷新与写入期间不另显示文字。
    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(session: session)
            branchHeader

            Divider()

            WorkingCopyCommitView(session: session)

            Divider()

            // 服务器仓库的未跟踪文件过多时提示补充忽略规则或加快状态读取
            UntrackedFilesHint(session: session)

            WorkingCopyFileList(session: session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay { emptyListMessage }
        }
    }
}

// MARK: - Private

extension WorkingCopyListView {
    /// 列表顶部的分支摘要与显示模式菜单。
    private var branchHeader: some View {
        HStack(spacing: 8) {
            branchSummary

            Spacer(minLength: 0)

            Menu {
                viewSettings
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
            .accessibilityLabel(AppLocalization.text("working.viewMode"))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 40)
        .background(AppPalette.color("general_header_background_color"))
    }

    /// 视图设置菜单：与主菜单的 Working Copy Status 子菜单发送同一组动作。
    @ViewBuilder
    private var viewSettings: some View {
        Toggle(
            AppLocalization.text("working.tree"),
            isOn: action(#selector(RepositoryWindowController.viewAsTree), isOn: session.listMode.isTree)
        )
        Toggle(
            AppLocalization.text("working.list"),
            isOn: action(#selector(RepositoryWindowController.viewAsList), isOn: session.listMode == .list)
        )

        Divider()

        // 未改动的文件只在树形里显示
        Toggle(
            AppLocalization.text("files.showNonModified"),
            isOn: action(#selector(RepositoryWindowController.toggleNonModifiedItems), isOn: session.listMode == .allFiles)
        )
        .disabled(!session.listMode.isTree)

        Toggle(
            AppLocalization.text("files.showIgnored"),
            isOn: action(#selector(RepositoryWindowController.toggleIgnoredItems), isOn: showsIgnored)
        )
        Toggle(
            AppLocalization.text("files.showAssumeUnchanged"),
            isOn: action(#selector(RepositoryWindowController.toggleAssumeUnchangedItems), isOn: showsAssumeUnchanged)
        )
    }

    /// 列表为空时的说明：搜索没有匹配时写出搜索内容，否则说明工作区没有改动。
    @ViewBuilder
    private var emptyListMessage: some View {
        if let status = session.status {
            let visible = session.listing.entries(status: status.entries, files: session.workingTreeFiles)

            if visible.isEmpty {
                Text(
                    session.searchText.isEmpty
                        ? AppLocalization.text("working.clean")
                        : AppLocalization.text("files.noMatches", session.searchText)
                )
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(20)
            }
        }
    }

    /// 一行当前分支与跟踪分支，有进行中的操作时同样如此；没有上游时明确显示没有上游。
    @ViewBuilder
    private var branchSummary: some View {
        if let branch = session.status?.branch {
            HStack(spacing: 4) {
                Text(branchTitle(branch))
                    .foregroundStyle(.secondary)

                if branch.head != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .accessibilityHidden(true)
                    Text(branch.upstream ?? AppLocalization.text("branch.noTracking"))
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.system(size: 13))
            .lineLimit(1)
            .help(branchTitle(branch))
        } else {
            Text(AppLocalization.text("workspace.title"))
                .foregroundStyle(.secondary)
        }
    }

    /// 分离 HEAD 使用已有哈希的短显示，未出生分支保留其名称。
    private func branchTitle(_ branch: BranchStatus) -> String {
        if let head = branch.head {
            return branch.oid == nil ? AppLocalization.text("branch.unborn", head) : head
        }

        if let oid = branch.oid {
            return AppLocalization.text("branch.detached", String(oid.prefix(12)))
        }

        return AppLocalization.text("branch.noHead")
    }

    /// 菜单里的勾选项：显示当前状态，点击时沿响应链发送与主菜单相同的动作。
    private func action(_ selector: Selector, isOn: Bool) -> Binding<Bool> {
        Binding(
            get: { isOn },
            set: { _ in NSApp.sendAction(selector, to: nil, from: nil) }
        )
    }
}
