import AppKit
import SpookyKit
import SwiftUI

// MARK: - HistoryBaseBranchHeader

/// 打开 Compare Branches 时替换列表头左侧：“Compare to:” 与基准分支下拉，后面是冲突与落后的徽标。
struct HistoryBaseBranchHeader: View {
    /// 历史状态。
    let history: RepositoryHistoryState

    /// 冲突文件列表的弹出状态。
    @State
    private var showsConflicts = false

    /// 一行排开，与普通表头同高。
    var body: some View {
        if let comparison = history.baseComparison {
            HStack(spacing: 6) {
                Text(AppLocalization.text("history.compareTo"))
                    .lineLimit(1)
                    .fixedSize()

                baseMenu(comparison)

                if !comparison.conflicts.isEmpty {
                    conflictBadge(comparison)
                }

                if let behind = comparison.comparison?.divergence.behind, behind > 0 {
                    HistoryBadge(symbol: "arrow.down", count: behind)
                        .help(
                            AppLocalization.text(
                                "history.behindBase",
                                comparison.branch.name,
                                behind,
                                comparison.base.name
                            )
                        )
                }
            }
        }
    }

    /// 基准分支下拉：除所选分支外的本地分支，当前基准打勾。
    private func baseMenu(_ comparison: HistoryBaseComparison) -> some View {
        Menu {
            ForEach(history.branches.filter { $0.isLocal && $0.id != comparison.branch.id }) { branch in
                Toggle(
                    branch.name,
                    isOn: Binding(
                        get: { branch.id == comparison.base.id },
                        set: { _ in history.selectComparisonBase(branch.id) }
                    )
                )
            }
        } label: {
            Text(comparison.base.name)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(comparison.base.name)
        .accessibilityLabel(AppLocalization.text("history.compareTo"))
    }

    /// 冲突徽标：点开列出冲突文件。
    private func conflictBadge(_ comparison: HistoryBaseComparison) -> some View {
        let tip = AppLocalization.text("review.conflictsTip", comparison.conflicts.count)

        return Button {
            showsConflicts = true
        } label: {
            HistoryBadge(symbol: "exclamationmark.triangle.fill", count: comparison.conflicts.count)
        }
        .buttonStyle(.plain)
        .help(tip)
        .popover(isPresented: $showsConflicts, arrowEdge: .bottom) {
            ConflictFileList(title: tip, paths: comparison.conflicts)
        }
    }
}

// MARK: - HistoryBadge

/// 表头里的小徽标：图标加 11 pt 半粗的数字。
struct HistoryBadge: View {
    /// SF Symbol 名。
    let symbol: String

    /// 显示的数字。
    let count: Int

    /// 胶囊底色与侧边栏的徽标一致。
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 9))

            Text(count.formatted())
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(AppPalette.color("sidebarBadgeBackgroundColor"), in: Capsule())
        .fixedSize()
    }
}

// MARK: - CompareBranchesToggle

/// 列表头的 Compare Branches 开关：20 × 20 的图标按钮，打开时填色。
struct CompareBranchesToggle: View {
    /// 历史状态，决定能不能比较。
    let history: RepositoryHistoryState

    /// Compare Branches 开关，与 View › History 的菜单项同一个偏好。
    @AppStorage(RepositoryHistoryState.comparesBranchesKey)
    private var comparesBranches = false

    /// 只有单选本地分支时可用。
    var body: some View {
        Button {
            comparesBranches.toggle()
        } label: {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 13))
                .foregroundStyle(comparesBranches ? Color.accentColor : .secondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.borderless)
        .disabled(history.selectedLocalBranch == nil)
        .help(AppLocalization.text("history.compareBranches"))
        .accessibilityLabel(AppLocalization.text("history.compareBranches"))
        .accessibilityValue(comparesBranches ? AppLocalization.text("history.compareOn") : "")
    }
}

// MARK: - IntegrateParentButton

/// 列表头的集成父分支改动按钮：所选分支落后父分支时显示落后数，点开选择合并或变基。
struct IntegrateParentButton: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 弹出状态。
    @State
    private var showsPopover = false

    /// 没有父分支或不落后时不显示。
    var body: some View {
        if
            let comparison = session.history.parentComparison,
            let behind = comparison.comparison?.divergence.behind,
            behind > 0
        {
            Button {
                showsPopover = true
            } label: {
                HistoryBadge(symbol: "arrow.down", count: behind)
            }
            .buttonStyle(.plain)
            .help(AppLocalization.text("history.behindBase", comparison.branch.name, behind, comparison.base.name))
            .accessibilityLabel(AppLocalization.text("review.updateBranch"))
            .popover(isPresented: $showsPopover, arrowEdge: .bottom) {
                UpdateBranchPopover(session: session, comparison: comparison) { showsPopover = false }
            }
        }
    }
}

// MARK: - UpdateBranchPopover

/// 集成父分支改动：说明要并入多少提交或会冲突的文件，用户明确选择合并或变基后执行。
struct UpdateBranchPopover: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 所选分支与父分支的比较。
    let comparison: HistoryBaseComparison

    /// 关闭弹窗。
    let close: () -> Void

    /// 说明、预览状态与 Merge ▾ Rebase 按钮。
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if comparison.conflicts.isEmpty {
                Text(
                    AppLocalization.text(
                        "review.update.summary",
                        comparison.base.name,
                        comparison.branch.name,
                        comparison.comparison?.divergence.behind ?? 0
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
            } else {
                ConflictFileList(
                    title: AppLocalization.text("review.conflictsTip", comparison.conflicts.count),
                    paths: comparison.conflicts
                )
                .padding(-16)
            }

            UpdateBranchStatus(comparison: comparison)

            HStack {
                Spacer()

                Menu(AppLocalization.text("review.update.merge")) {
                    Button(AppLocalization.text("review.update.rebase")) { run(rebase: true) }
                } primaryAction: {
                    run(rebase: false)
                }
                .fixedSize()
                .disabled(!session.canUpdateBranch(comparison.branch))
            }
        }
        .font(.system(size: 13))
        .padding(20)
        .frame(width: 340)
    }

    /// 关闭弹窗后执行；冲突与本地改动由仓库窗口承接。
    private func run(rebase: Bool) {
        close()
        session.updateBranch(comparison.branch, rebase: rebase)
    }
}

// MARK: - UpdateBranchStatus

/// Update Branch 的预览状态：一行图标与说明。
struct UpdateBranchStatus: View {
    /// 所选分支与父分支的比较。
    let comparison: HistoryBaseComparison

    /// 18 pt 图标加 12 pt 说明。
    var body: some View {
        let (symbol, color, key) = status

        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            Text(AppLocalization.text(key))
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }

    /// 正在检查、没有可并入的改动、没有冲突、有冲突或无法检查。
    private var status: (String, Color, String) {
        guard let result = comparison.comparison else {
            return ("clock", .secondary, "merge.checking")
        }

        if result.divergence.behind == 0 {
            return ("equal.circle", .secondary, "review.update.noChanges")
        }

        switch result.merge {
        case .conflicts:
            return ("exclamationmark.triangle.fill", .yellow, "review.update.conflicts")

        case .unavailable:
            return ("questionmark.circle", .secondary, "merge.unavailable")

        case .clean, .unchanged:
            return ("checkmark.circle.fill", .green, "review.update.clean")
        }
    }
}

// MARK: - HistoryForkPointRow

/// 分叉点行：分支图标与 “Fork point of parent branch “X””，提交图照常穿过。
struct HistoryForkPointRow: View {
    /// 基准分支名。
    let base: String

    /// 穿过这一行的提交图。
    let graph: HistoryGraphView?

    /// 图在左，说明在右。
    var body: some View {
        HStack(spacing: 8) {
            if let graph {
                graph
                    .frame(width: graph.width)
                    .accessibilityHidden(true)
            }

            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 13))
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text(AppLocalization.text("history.forkPoint", base))
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - HistoryNoNewCommitsRow

/// 所选分支没有自己的提交：左侧竖线、对勾图标与两行说明。
struct HistoryNoNewCommitsRow: View {
    /// 基准分支名。
    let base: String

    /// 竖线、图标与说明。
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .frame(width: 2)
                .foregroundStyle(.tertiary)

            Image(systemName: "checkmark.circle")
                .font(.system(size: 18))
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppLocalization.text("history.noNewCommits"))

                Text(AppLocalization.text("history.identicalToParent", base))
            }
            .font(.system(size: 13))
            .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.leading, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
