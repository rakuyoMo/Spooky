import Foundation
import SpookyKit

// MARK: - Reads

extension RepositoryActivities {
    /// 把一次读取记进 Repository 页：读取结束时按标题各插入一条已结束的记录，开始时刻是读取开始的时刻。
    ///
    /// 成功写 Finished，一行结果同时作为日志；任务被取消或被新的读取取代时写 Cancelled；失败写 Failed，日志是错误说明。
    /// 读取的结果与错误照常交给调用方。
    ///
    /// - Parameters:
    ///   - titles: 各条记录的标题；一次读取同时读出几类内容时，按类各记一条。
    ///   - repository: 读取所属的仓库。
    ///   - records: 是否记录；自动刷新引起的读取不记。
    ///   - results: 成功时各条记录的一行结果，与标题按位置对应；只在记录成功的读取时调用。
    ///   - read: 读取本身。
    /// - Returns: 读取的结果。
    func recordRead<Value>(
        _ titles: [String],
        in repository: RepositoryLocation,
        records: Bool = true,
        results: (Value) -> [String?] = { _ in [] },
        _ read: () async throws -> Value
    ) async throws -> Value {
        guard records else {
            return try await read()
        }

        let started = Date()

        do {
            let value = try await read()

            // 取消读取的任务已不再使用这次的结果，按取消记
            guard !Task.isCancelled else {
                insertReads(titles, in: repository, started: started, state: "activity.cancelled")
                return value
            }

            insertReads(titles, in: repository, started: started, state: "activity.finished", results: results(value))
            return value
        } catch {
            let cancelled = Task.isCancelled
                || error is CancellationError
                || ((error as? GitError)?.isCancelled ?? false)

            guard !cancelled else {
                insertReads(titles, in: repository, started: started, state: "activity.cancelled")
                throw error
            }

            // 日志写错误的原文，与界面上显示的相同
            let failure = AppFailure(error: error, opening: false, location: repository)

            insertReads(
                titles,
                in: repository,
                started: started,
                state: "activity.failed",
                failure: failure.details
            )

            throw error
        }
    }

    /// 与这个仓库这一类的基准比较，写出更新、新增与删除的个数，并把基准换成这次的清单。
    ///
    /// 新出现的身份算新增，消失的算删除，身份相同而比较值不同算更新；没有基准时全算新增。
    ///
    /// - Parameters:
    ///   - inventory: 清单的种类。
    ///   - items: 这次读到的清单，每项是 “身份 → 比较值的摘要”。
    ///   - repository: 清单所属的仓库；同一仓库的各窗口共用一份基准。
    /// - Returns: 已本地化的一行结果。
    func changes(
        of inventory: ActivityInventory,
        items: [String: String],
        in repository: RepositoryLocation
    ) -> String {
        let previous = baselines[repository]?[inventory] ?? [:]
        baselines[repository, default: [:]][inventory] = items

        let updated = items.count { identity, value in
            previous[identity].map { $0 != value } ?? false
        }

        let added = items.keys.count { previous[$0] == nil }
        let deleted = previous.keys.count { items[$0] == nil }

        return AppLocalization.text("activity.result.changes", updated, added, deleted)
    }

    /// 按标题各插入一条已结束的读取记录。
    ///
    /// - Parameters:
    ///   - titles: 各条记录的标题。
    ///   - started: 读取开始的时刻。
    ///   - state: 结束的状态键。
    ///   - results: 成功时各条的一行结果，与标题按位置对应，缺的一条没有结果。
    ///   - failure: 失败时写进日志的错误说明。
    private func insertReads(
        _ titles: [String],
        in repository: RepositoryLocation,
        started: Date,
        state: String,
        results: [String?] = [],
        failure: String? = nil
    ) {
        for (index, title) in titles.enumerated() {
            let activity = RepositoryActivity(kind: .repository, repository: repository, title: title, started: started)
            let result = results.indices.contains(index) ? results[index] : nil

            activity.state = state
            activity.result = result

            // 成功时一行结果就是日志，失败时日志是错误说明
            if let result {
                activity.append(.standardOutput(Data(result.utf8)))
            }

            if let failure {
                activity.append(.standardError(Data(failure.utf8)))
            }

            insert(activity)
            finish(activity)
        }
    }
}
