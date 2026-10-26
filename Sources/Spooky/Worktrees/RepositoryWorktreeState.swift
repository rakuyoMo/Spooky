import Foundation
import Observation
import SpookyKit

// MARK: - RepositoryWorktreeState

/// 一个仓库窗口的工作树清单；过期请求的结果不能倒灌。
@MainActor
@Observable
final class RepositoryWorktreeState {
    /// 最近一次读取的全部工作树，第一个是主工作树。
    private(set) var items: [Worktree] = []

    /// 第一次读取完成前不显示空状态。
    private(set) var isLoaded = false

    /// 最近一次读取清单的失败。
    private(set) var failure: AppFailure? = nil

    /// 工作树详情里显示的工作树路径。
    var selectedPath: String? = nil

    /// 工作树的对话框由窗口呈现。
    @ObservationIgnored
    var onRequest: ((WorktreeRequest) -> Void)? = nil

    /// 清单读取任务。
    private var task: Task<Void, Never>? = nil

    /// 请求代数，写入或关闭后递增，旧请求的结果被丢弃。
    private var generation = 0

    /// 除本窗口仓库之外的工作树，按名称排序；侧边栏与快捷操作列出这些。
    var others: [Worktree] {
        items
            .filter { !$0.isCurrent && !$0.isBare }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 详情里显示的工作树；已不存在时为 nil。
    var selected: Worktree? {
        selectedPath.flatMap { path in items.first { $0.path == path } }
    }

    /// 在别的工作树里检出的分支：完整引用名对应那个工作树。
    var branchWorktrees: [String: Worktree] {
        Dictionary(
            others.compactMap { worktree in worktree.branch.map { ($0, worktree) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// 读取工作树清单；正在读取时不重复发起。
    func refresh(runner: GitRunner) {
        guard task == nil else { return }

        let request = generation

        task = Task { [weak self] in
            do {
                let worktrees = try await RepositoryWorktrees(runner: runner).list()
                guard let self, generation == request, !Task.isCancelled else { return }

                items = worktrees
                failure = nil
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }
                failure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, generation == request else { return }
            isLoaded = true
            task = nil
        }
    }

    /// 写入前取消读取，避免旧清单在写入后覆盖新快照。
    func suspend() {
        generation += 1
        task?.cancel()
        task = nil
    }

    /// 关闭仓库时清除全部快照。
    func close() {
        suspend()
        items = []
        isLoaded = false
        failure = nil
        selectedPath = nil
    }
}
