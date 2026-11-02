import Foundation
import Observation
import SpookyKit

// MARK: - PullRequestConversationState

/// 讨论列出的提交，以及各请求在讨论里的选择与提交组的折叠。
///
/// 提交在仓库所在的机器上读出，读完比较范围里的全部提交才交给讨论；选择与折叠只记在内存里。
@MainActor
@Observable
final class PullRequestConversationState {
    /// 比较范围里的全部提交，按拓扑序从新到旧；还没读完、需要获取或比较没打开时为 nil。
    private(set) var commits: [HistoryCommit]? = nil

    /// 各请求在讨论里选中的行。
    @ObservationIgnored
    var selections: [PullRequestID: Set<PullRequestConversationItem.Key>] = [:]

    /// 各请求折叠着的提交组，按组所在那天的零点记。
    @ObservationIgnored
    var collapsedGroups: [PullRequestID: Set<Date>] = [:]

    /// 读取任务，关闭或换一组版本时取消。
    @ObservationIgnored
    private var task: Task<Void, Never>? = nil

    /// 关闭或换一组版本时递增，丢弃迟到的结果。
    @ObservationIgnored
    private var generation = 0

    /// 读出比较范围里的全部提交；读完之前保留上一次的结果，重新读取同一个请求时讨论不闪动。
    ///
    /// - Parameters:
    ///   - base: 比较基准的完整哈希。
    ///   - target: 源分支提交的完整哈希。
    func load(base: String, target: String, runner: GitRunner) {
        task?.cancel()
        generation += 1

        let request = generation
        let comparison = RevisionComparison(runner: runner, base: base, target: target)

        task = Task { [weak self] in
            do {
                // 一页最多 1000 条，读到没有下一页为止
                var commits: [HistoryCommit] = []
                var hasMore = true

                while hasMore {
                    try Task.checkCancellation()

                    let page = try await comparison.commits(offset: commits.count, limit: 1000)
                    commits += page.commits
                    hasMore = page.hasMore
                }

                guard let self, generation == request else { return }
                self.commits = commits
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }
                commits = nil
            }
        }
    }

    /// 不再列出提交并取消读取；选择与折叠的记忆保留。
    func close() {
        generation += 1
        task?.cancel()
        task = nil
        commits = nil
    }
}
