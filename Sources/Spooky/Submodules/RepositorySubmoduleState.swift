import Foundation
import Observation
import SpookyKit

// MARK: - RepositorySubmoduleState

/// 一个仓库窗口的子模块清单、各子模块的工作区概况与父仓库位置；过期请求的结果不能倒灌。
@MainActor
@Observable
final class RepositorySubmoduleState {
    /// 最近一次读取的子模块，按路径排序。
    private(set) var items: [Submodule] = []

    /// 已检出子模块的工作区概况，按路径保存；读不到的不在其中。
    private(set) var summaries: [String: SubmoduleSummary] = [:]

    /// 已检出子模块里可以检出的分支与标签，按路径保存，右键菜单的 Checkout Revision 使用。
    private(set) var revisions: [String: [SubmoduleRevision]] = [:]

    /// 本仓库作为子模块时父仓库工作区的绝对路径；不是子模块时为 nil。
    private(set) var superproject: String? = nil

    /// 第一次读取完成前不显示空状态。
    private(set) var isLoaded = false

    /// 最近一次读取清单的失败。
    private(set) var failure: AppFailure? = nil

    /// 子模块详情里显示的子模块路径。
    var selectedPath: String? = nil

    /// 刚结束的写操作改动了指针、还没有更新的已初始化子模块，写入结束后询问是否更新。
    @ObservationIgnored
    var outdated: [Submodule]? = nil

    /// 子模块的对话框与询问由窗口呈现。
    @ObservationIgnored
    var onRequest: ((SubmoduleRequest) -> Void)? = nil

    /// 清单与概况的读取任务。
    private var task: Task<Void, Never>? = nil

    /// 请求代数，写入或关闭后递增，旧请求的结果被丢弃。
    private var generation = 0

    /// 清单与概况的读取记进的 Activity 列表，由会话设成它自己的列表。
    @ObservationIgnored
    var activities = RepositoryActivities.shared

    /// 详情里显示的子模块；已不存在时为 nil。
    var selected: Submodule? {
        selectedPath.flatMap { path in items.first { $0.path == path } }
    }

    /// 已初始化、写入前后用来比较指针的子模块。
    var initialized: [Submodule] {
        items.filter(\.isInitialized)
    }

    /// 各已检出子模块的概况与可以检出的版本，并发读取；单个子模块读取失败时不显示它的徽标与版本。
    private nonisolated static func details(
        of submodules: [Submodule],
        service: RepositorySubmodules
    ) async -> [String: (summary: SubmoduleSummary?, revisions: [SubmoduleRevision]?)] {
        await withTaskGroup(of: (String, SubmoduleSummary?, [SubmoduleRevision]?).self) { group in
            for submodule in submodules where submodule.isValid && submodule.isPopulated {
                group.addTask {
                    async let summary = try? service.summary(of: submodule)
                    async let revisions = try? service.revisions(of: submodule)
                    return (submodule.path, await summary, await revisions)
                }
            }

            var details: [String: (summary: SubmoduleSummary?, revisions: [SubmoduleRevision]?)] = [:]

            for await (path, summary, revisions) in group {
                details[path] = (summary, revisions)
            }

            return details
        }
    }

    /// 读取清单、父仓库位置与已检出子模块的概况；记录时写出子模块与上一次记录相比的增减。
    ///
    /// - Parameters:
    ///   - activities: 读取记进的 Activity 列表。
    ///   - records: 是否记进 Activity。
    /// - Returns: 子模块、父仓库位置与各已检出子模块的概况和可以检出的版本。
    private static func load(
        runner: GitRunner,
        activities: RepositoryActivities,
        records: Bool
    ) async throws -> (
        submodules: [Submodule],
        superproject: String?,
        details: [String: (summary: SubmoduleSummary?, revisions: [SubmoduleRevision]?)]
    ) {
        let location = runner.location
        let service = RepositorySubmodules(runner: runner)

        return try await activities.recordRead(
            [AppLocalization.text("activity.read.submodules")],
            in: location,
            records: records,
            results: { loaded in
                let items = ActivityInventory.submodules(
                    loaded.submodules,
                    summaries: loaded.details.compactMapValues(\.summary)
                )

                return [await activities.changes(of: .submodules, items: items, in: location)]
            }
        ) {
            async let listed = service.list()
            async let parent = service.superproject()

            let submodules = try await listed
            let superproject = try? await parent
            let details = await Self.details(of: submodules, service: service)

            return (submodules, superproject, details)
        }
    }

    /// 读取清单、父仓库位置与已检出子模块的概况；正在读取时不重复发起。
    ///
    /// - Parameter records: 是否记进 Activity；自动刷新引起的重读不记。
    func refresh(runner: GitRunner, records: Bool = true) {
        guard task == nil else { return }

        let request = generation
        let activities = activities

        task = Task { [weak self] in
            do {
                let (submodules, superproject, details) = try await Self.load(
                    runner: runner,
                    activities: activities,
                    records: records
                )

                guard let self, generation == request, !Task.isCancelled else { return }

                items = submodules
                summaries = details.compactMapValues(\.summary)
                revisions = details.compactMapValues(\.revisions)
                self.superproject = superproject
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
        summaries = [:]
        revisions = [:]
        superproject = nil
        isLoaded = false
        failure = nil
        selectedPath = nil
        outdated = nil
    }
}
