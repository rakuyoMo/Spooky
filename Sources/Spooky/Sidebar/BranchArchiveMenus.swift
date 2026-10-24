import SpookyKit
import SwiftUI

// MARK: - ArchivedGroupHeader

/// Archived Branches 分组标题：有自动归档后还没看过的分支时，标题右侧 4 pt 多一个 6 pt 的强调色圆点，右键可以全部标为已看过。
///
/// 整行仍是归档拖放的落点。
struct ArchivedGroupHeader: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 拖放的参数表单入口。
    let request: (RepositoryActionRequest) -> Void

    /// 标题、圆点与撑满整行的空白。
    var body: some View {
        let unreviewed = unreviewedBranches

        HStack(spacing: 4) {
            Text(AppLocalization.text("sidebar.archived"))

            if !unreviewed.isEmpty {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel(AppLocalization.text("sidebar.needsReview"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(RepositoryDropTarget(session: session, destination: .archived, request: request))
        .contextMenu {
            if !unreviewed.isEmpty {
                Button(AppLocalization.text("sidebar.markAllReviewed")) {
                    session.markArchiveReviewed(unreviewed)
                }
                .disabled(!session.canWrite)
            }
        }
    }

    /// 已归档且待审阅的本地分支。
    private var unreviewedBranches: [RepositoryReference] {
        guard let snapshot = session.history.snapshot else {
            return []
        }

        return session.history.branches.filter { branch in
            let metadata = snapshot.metadata(for: branch.id)
            return branch.isLocal && metadata.isArchived && metadata.needsArchiveReview
        }
    }
}

// MARK: - BranchArchiveOptions

/// 归档菜单项下的两个勾选项：自动归档时跳过这个分支、不再显示它的完全合并提示。
struct BranchArchiveOptions: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 右键的本地分支。
    let branch: RepositoryReference

    /// 分支的附加信息。
    let metadata: BranchMetadata

    /// 两个勾选项，状态取自仓库配置。
    var body: some View {
        Toggle(
            AppLocalization.text("review.skipAutoArchive"),
            isOn: Binding(
                get: { metadata.skipsAutoArchive },
                set: { session.setSkipsAutoArchive($0, branches: [branch]) }
            )
        )
        .disabled(!session.canSetArchived([branch]))

        Toggle(
            AppLocalization.text("review.hideMergedHint"),
            isOn: Binding(
                get: { metadata.hidesMergedHint },
                set: { session.setHidesMergedHint($0, branches: [branch]) }
            )
        )
        .disabled(!session.canSetArchived([branch]))
    }
}

// MARK: - ParentBranchMenuItems

/// HEAD 分支右键里与父分支有关的两项：并入父分支、变基到父分支上；按住 ⌥ 时换成跳过对话框的快速版本。
struct ParentBranchMenuItems: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 右键的分支。
    let reference: RepositoryReference

    /// 合并对话框由窗口呈现。
    let request: (RepositoryActionRequest) -> Void

    /// 只有 HEAD 分支设了仍存在的父分支时出现。
    var body: some View {
        if reference.isLocal, reference.name == session.status?.branch.head, let parent = session.parentBranch(of: reference) {
            Button(AppLocalization.text("branch.mergeWith", parent.name)) {
                request(RepositoryActionRequest(kind: .merge, reference: parent.id))
            }
            .disabled(!session.canMerge(parent))
            .modifierKeyAlternate(.option) {
                Button(AppLocalization.text("branch.quickMergeInto", parent.name, reference.name)) {
                    session.quickMerge(parent)
                }
                .disabled(!session.canMerge(parent))
            }

            Button(AppLocalization.text("branch.rebaseOn", parent.name)) {
                session.onRebaseRequest?(parent.id)
            }
            .disabled(!session.canRebase)
            .modifierKeyAlternate(.option) {
                Button(AppLocalization.text("branch.quickRebaseOn", reference.name, parent.name)) {
                    session.quickRebase(onto: parent)
                }
                .disabled(!session.canRebase)
            }
        }
    }
}
