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

    /// 勾选的分支，默认全选。
    @State
    private var selected: Set<String>

    /// 自动归档开关，与侧边栏视图设置、Settings → General 同一个偏好。
    @AppStorage(SidebarPreferences.autoArchiveKey)
    private var autoArchive = SidebarPreferences.defaultFlag(SidebarPreferences.autoArchiveKey)

    /// 对话框骨架里放分支列表与自动归档开关。
    var body: some View {
        RewriteDialogFrame(
            session: session,
            title: AppLocalization.text("review.archive.title"),
            help: AppLocalization.text(automatic ? "review.archive.automaticHelp" : "review.archive.help"),
            primary: AppLocalization.text("review.archive.submit"),
            canSubmit: !selected.isEmpty,
            cancel: close,
            submit: submit,
            content: { content },
            options: { EmptyView() }
        )
    }

    /// 没有建议时说明原因；否则是可勾选的分支列表。
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if candidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.text("review.archive.empty"))
                        .bold()

                    Text(AppLocalization.text("review.archive.emptyHelp"))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                List(candidates) { branch in
                    Toggle(isOn: binding(for: branch.id)) {
                        HStack(spacing: 8) {
                            Text(branch.name)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer(minLength: 8)

                            Text(reason(for: branch))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.bordered)
                .frame(height: min(CGFloat(candidates.count) * 24 + 12, 220))
            }

            Toggle(AppLocalization.text("review.archive.auto"), isOn: $autoArchive)

            Text(AppLocalization.text("review.archive.autoHelp"))
                .font(.system(size: 11))
                .padding(.leading, 19)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 创建对话框，默认勾选全部建议的分支。
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
        _selected = State(initialValue: Set(candidates.map(\.id)))
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

    /// 建议归档的原因：请求已合并，或分支陈旧；两者都满足时写请求已合并。
    private func reason(for branch: RepositoryReference) -> String {
        let merged = session.mergedPullRequest(of: branch) != nil

        return AppLocalization.text(merged ? "pullRequests.state.merged" : "review.filter.stale")
    }

    /// 归档勾选的分支后关闭。
    private func submit() {
        session.archive(candidates.filter { selected.contains($0.id) }, automatic: automatic)
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
