import SpookyKit
import SwiftUI

// MARK: - ArchiveBranchesDialog

/// 批量归档对话框：列出建议归档的分支，勾选的一并归档；自动归档前用同一个对话框列出待处理的分支请用户确认。
struct ArchiveBranchesDialog: View {
    /// 发起归档的窗口会话。
    let session: RepositorySession

    /// 是否为自动归档前的确认。
    let automatic: Bool

    /// 建议归档的分支。
    let candidates: [RepositoryReference]

    /// 关闭 sheet。
    let close: () -> Void

    /// 勾选的分支，每次打开都从空开始。
    @State
    private var selected: Set<String> = []

    /// 自动归档开关，与侧边栏视图设置、Settings → General 同一个偏好。
    @AppStorage(SidebarPreferences.autoArchiveKey)
    private var autoArchive = SidebarPreferences.defaultFlag(SidebarPreferences.autoArchiveKey)

    /// 对话框骨架里放分支列表与自动归档开关。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("review.archive.title"),
            message: AppLocalization.text(automatic ? "review.archive.automaticHelp" : "review.archive.help"),
            submitTitle: AppLocalization.text("review.archive.submit"),
            error: "",
            isValid: !selected.isEmpty,
            cancel: close,
            submit: submit
        ) {
            content
        }
    }

    /// 分支列表在上，自动归档开关在下，两者相隔 12 pt。
    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            branches

            VStack(alignment: .leading, spacing: 8) {
                Toggle(AppLocalization.text("review.archive.auto"), isOn: $autoArchive)

                Text(AppLocalization.text("review.archive.autoHelp"))
                    .font(.system(size: 11))
                    .padding(.leading, 19)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 没有建议时说明原因；否则是分组名与勾选计数在上、可勾选的分支列表在下。
    @ViewBuilder
    private var branches: some View {
        if candidates.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.text("review.archive.empty"))
                    .bold()

                Text(AppLocalization.text("review.archive.emptyHelp"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                header
                list
            }
        }
    }

    /// 列表上方：左边是分组名，右边是已勾选的数量与总数，随勾选实时更新。
    private var header: some View {
        HStack(spacing: 8) {
            Text(AppLocalization.text("branch.group"))
                .bold()

            Spacer(minLength: 8)

            Text(AppLocalization.text("review.archive.selection", selected.count, candidates.count))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// 首行是 Select All，其下每个分支一行，最高 220 pt。
    private var list: some View {
        List {
            Toggle(AppLocalization.text("menu.selectAll"), isOn: allSelected)

            ForEach(candidates) { branch in
                Toggle(isOn: binding(for: branch.id)) {
                    row(branch)
                }
            }
        }
        .listStyle(.bordered)
        .frame(height: min(CGFloat(candidates.count + 1) * 24 + 12, 220))
    }

    /// Select All 的勾选状态：全部勾上时为开；勾上时选中全部分支，取消时一个都不选。
    private var allSelected: Binding<Bool> {
        Binding(
            get: { selected.count == candidates.count },
            set: { checked in
                selected = checked ? Set(candidates.map(\.id)) : []
            }
        )
    }

    /// 创建对话框，一个分支都不勾选。
    init(
        session: RepositorySession,
        automatic: Bool,
        candidates: [RepositoryReference],
        close: @escaping () -> Void
    ) {
        self.session = session
        self.automatic = automatic
        self.candidates = candidates
        self.close = close
    }

    /// 一个分支的勾选状态。
    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selected.contains(id) },
            set: { checked in
                if checked {
                    selected.insert(id)
                } else {
                    selected.remove(id)
                }
            }
        )
    }

    /// 一行分支：分支图标、名称，右侧是建议归档的原因。
    private func row(_ branch: RepositoryReference) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(branch.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            reasonBadge(for: branch)
        }
    }

    /// 建议归档的原因胶囊：请求已合并是紫色，写明是哪种请求；陈旧是橙色。两者都满足时写请求已合并。
    private func reasonBadge(for branch: RepositoryReference) -> some View {
        let merged = session.mergedPullRequest(of: branch) != nil
        let color: Color = merged ? .purple : .orange
        let reason = merged ? session.pullRequestText("archive.merged") : AppLocalization.text("review.filter.stale")

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .accessibilityHidden(true)

            Text(reason)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(color.opacity(0.15), in: Capsule())
        .fixedSize()
    }

    /// 归档勾选的分支后关闭；对话框开着时分支可能已被删除、置顶或归档，只归档仍在建议里的分支。
    private func submit() {
        let current = Set(session.archiveCandidates(automatic: automatic).map(\.id))
        let branches = candidates.filter { selected.contains($0.id) && current.contains($0.id) }

        session.archive(branches, automatic: automatic)
        close()
    }
}

// MARK: - ArchiveNoticeView

/// 归档完成后的一行说明：归档了几个分支，可以撤销，也可以关闭。
struct ArchiveNoticeView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 有刚归档的分支时显示。
    var body: some View {
        if let branches = session.branchesReview.archivedBranches {
            HStack(spacing: 6) {
                Image(systemName: "archivebox")
                    .accessibilityHidden(true)

                Text(
                    branches.count == 1
                        ? AppLocalization.text("review.archived.one")
                        : AppLocalization.text("review.archived.many", branches.count)
                )
                .lineLimit(1)

                Spacer(minLength: 4)

                Button(AppLocalization.text("review.archived.undo")) {
                    session.undoArchive()
                }
                .disabled(!session.canWrite)

                Button {
                    session.branchesReview.archivedBranches = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(AppLocalization.text("action.close"))
            }
            .font(.system(size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()
        }
    }
}

// MARK: - ArchiveFooterButton

/// 侧边栏底栏的归档按钮：自动归档关闭、且有建议归档的分支时显示数量，点开批量归档对话框。
struct ArchiveFooterButton: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 自动归档开关。
    @AppStorage(SidebarPreferences.autoArchiveKey)
    private var autoArchive = SidebarPreferences.defaultFlag(SidebarPreferences.autoArchiveKey)

    /// 陈旧阈值变化时重算数量。
    @AppStorage(SidebarPreferences.staleIntervalKey)
    private var staleInterval = SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey)

    /// 20 pt 高的徽标按钮：归档图标加数量。
    var body: some View {
        let months =
            SidebarPreferences.isValid(staleInterval, for: SidebarPreferences.staleIntervalKey)
                ? staleInterval
                : SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey)
        let candidates = autoArchive ? [] : session.archiveCandidates(automatic: false, staleMonths: months)

        if !candidates.isEmpty {
            Button {
                session.branchesReview.onArchiveRequest?(false, candidates)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 13))

                    Text(candidates.count.formatted())
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(height: 20)
            .help(AppLocalization.text("review.archive.title"))
            .accessibilityLabel(AppLocalization.text("review.archive.count", candidates.count))
        }
    }
}
