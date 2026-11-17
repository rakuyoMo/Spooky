import AppKit
import SpookyKit
import SwiftUI

// MARK: - BranchesReviewDetailView

/// 分支整理的详情：40 pt 头部是 “分支 → 基准”、冲突按钮与 `Commits | Changeset`，下面是摘要与从分叉点到分支顶端的比较。
struct BranchesReviewDetailView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 单选时显示比较，多选或没有选择时显示空状态。
    var body: some View {
        let state = session.branchesReview
        let selected = state.selectedIDs

        if selected.count > 1 {
            EmptyStateView(
                title: AppLocalization.text("review.selected", selected.count),
                message: "",
                symbol: AppSymbol.branch
            )
        } else if
            let id = selected.first,
            let branch = session.history.branches.first(where: { $0.id == id })
        {
            VStack(spacing: 0) {
                BranchesReviewDetailHeader(session: session, branch: branch)
                Divider()

                BranchesReviewSummary(session: session, branch: branch)

                RevisionComparisonView(
                    state: state.comparison,
                    session: session,
                    showsHeader: false,
                    showsExpandAll: false
                )
            }
        } else {
            EmptyStateView(
                title: AppLocalization.text("review.noSelection"),
                message: "",
                symbol: AppSymbol.branch
            )
        }
    }
}

// MARK: - BranchesReviewDetailHeader

/// 详情头部：分支名、比较图标与基准名，冲突时多一个列出冲突文件的按钮，右端切换提交与改动。
private struct BranchesReviewDetailHeader: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 所选分支。
    let branch: RepositoryReference

    /// 冲突文件列表的弹出状态。
    @State
    private var showsConflicts = false

    /// 40 pt 高，与其它详情头部一致。
    var body: some View {
        let state = session.branchesReview

        HStack(spacing: 6) {
            Text(branch.name)
                .bold()
                .lineLimit(1)
                .truncationMode(.middle)

            Image(systemName: "arrow.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            // 宽度不够时先截断分支名，基准名保持完整
            Text(state.base?.name ?? "")
                .bold()
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)

            if case .conflicts(let paths) = state.comparisons[branch.id]?.merge {
                conflictButton(paths)
            }

            Spacer(minLength: 8)

            Picker("", selection: Bindable(state.comparison).showsChangeset) {
                Text(AppLocalization.text("compare.commits")).tag(false)
                Text(AppLocalization.text("history.changeset")).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
            .accessibilityLabel(AppLocalization.text("compare.view"))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 20)
        .frame(height: 40)
        .background(.bar)
    }

    /// 冲突数的徽标按钮；点开列出冲突文件。
    private func conflictButton(_ paths: [String]) -> some View {
        Button {
            showsConflicts = true
        } label: {
            Label(paths.count.formatted(), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(AppLocalization.text("review.conflictsTip", paths.count))
        .popover(isPresented: $showsConflicts, arrowEdge: .bottom) {
            ConflictFileList(
                title: AppLocalization.text("review.conflictsTip", paths.count),
                paths: paths
            )
        }
    }
}

// MARK: - ConflictFileList

/// 合并会冲突的文件列表，供分支整理与集成父分支改动的弹窗共用。
struct ConflictFileList: View {
    /// 列表上方的说明。
    let title: String

    /// 冲突的文件路径。
    let paths: [String]

    /// 说明加最多约十行高的路径列表，路径可以选中复制。
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.multicolor)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(paths, id: \.self) { path in
                        Text(path)
                            .font(.system(size: 11))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .padding(16)
        .frame(width: 320)
    }
}

// MARK: - BranchesReviewMenu

/// 列表行的右键菜单，与侧边栏同一分支的菜单相同：右键点在多选之内时作用于全部所选，否则只作用于被点的一行。
struct BranchesReviewMenu: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 被右键点中的行。
    let item: BranchesReviewItem

    /// 当前列表的全部行。
    let items: [BranchesReviewItem]

    /// 新建分支等参数表单由窗口呈现。
    let request: (RepositoryActionRequest) -> Void

    /// 侧边栏的分支菜单；只作用于一个分支且并入基准会冲突时，最后加解决冲突一项。
    var body: some View {
        let selected = session.branchesReview.selectedIDs
        let targets =
            selected.contains(item.id) && selected.count > 1
                ? items.filter { selected.contains($0.id) }.map(\.reference)
                : [item.reference]

        BranchMenu(session: session, references: targets, request: request)

        if targets.count == 1, case .conflicts = item.comparison?.merge, let base = session.branchesReview.base {
            Divider()

            Button(AppLocalization.text("review.resolveConflicts")) {
                session.mergeBase(base, into: item.reference)
            }
            .disabled(!session.canWrite || session.context?.operation != nil)
        }
    }
}
