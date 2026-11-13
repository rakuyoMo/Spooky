import Foundation
import SpookyKit

// MARK: - HistorySearchSuggestions

/// 历史与文件历史搜索的补全数据：仓库的作者、提交人与 HEAD 中的文件。
///
/// 贡献者由会话在 HEAD 变化后于后台读取，同一仓库与 HEAD 只读取一次；服务器仓库的文件清单也只取回一次。
/// 读取失败的结果不缓存，下次输入时重试。
@MainActor
final class HistorySearchSuggestions {
    /// 一次读取：仓库位置、HEAD 与读取任务。
    private struct Load<Value: Sendable> {
        /// 读取所在的仓库。
        let location: RepositoryLocation

        /// 读取时的 HEAD 提交。
        let head: String

        /// 读取任务，多次输入共用。
        let task: Task<Value, Error>
    }

    /// 建议列表最多保留的条数。
    private static let limit = 100

    /// 作者与提交人的读取。
    private var contributorsLoad: Load<RepositoryContributors>? = nil

    /// 文件清单的读取。
    private var filesLoad: Load<[String]>? = nil

    /// 文件建议：查询的字符按顺序出现在文件名或路径里即命中，不区分大小写。
    ///
    /// 文件名连续命中的排在最前，其次是文件名按顺序命中、路径连续命中、路径按顺序命中；同一档内路径短的在前。
    static func fileMatches(_ query: String, in paths: [String]) -> [String] {
        let needle = query.lowercased()

        let ranked = paths.compactMap { path -> (rank: Int, path: String)? in
            let lowered = path.lowercased()
            let name = lowered.split(separator: "/").last.map(String.init) ?? lowered

            if name.contains(needle) {
                return (0, path)
            }

            if ContributorSuggestion.isSubsequence(needle, of: name) {
                return (1, path)
            }

            if lowered.contains(needle) {
                return (2, path)
            }

            return ContributorSuggestion.isSubsequence(needle, of: lowered) ? (3, path) : nil
        }

        return ranked
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank {
                    return lhs.rank < rhs.rank
                }

                if lhs.path.count != rhs.path.count {
                    return lhs.path.count < rhs.path.count
                }

                return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
            .prefix(limit)
            .map(\.path)
    }

    /// 整段输入可识别为日期时的 Since Dates 建议，排在其它建议之前；不是日期时为 nil。
    ///
    /// 输入只有一部分是日期（如 “fix tomorrow”）时不算，以免把普通的说明当成日期。
    static func sinceSuggestion(for query: String) -> ContributorSuggestion? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)

        guard
            !trimmed.isEmpty,
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
            let match = detector.firstMatch(in: trimmed, range: range),
            match.range == range,
            let date = match.date
        else {
            return nil
        }

        let title = AppLocalization.text(
            "history.search.since",
            date.formatted(date: .abbreviated, time: .omitted)
        )

        return ContributorSuggestion(
            text: query,
            name: title,
            email: nil,
            showsAvatar: false,
            sinceDate: date
        )
    }

    /// 会话读出新的 HEAD 后在后台读取贡献者，不等到第一次输入；同一仓库与 HEAD 已在读或已读完时不重读。
    ///
    /// 换了仓库或 HEAD 时取消旧的读取；读取不弹出凭据或口令的询问。
    func prepareContributors(runner: GitRunner, head: String) {
        _ = contributorsTask(runner: runner, head: head)
    }

    /// 仓库的作者与提交人；还在读时等这一次读取，读取失败时为空。
    func contributors(runner: GitRunner, head: String) async -> RepositoryContributors {
        let task = contributorsTask(runner: runner, head: head)

        do {
            return try await task.value
        } catch {
            // 失败的读取不留在缓存里，下次输入时重试
            if contributorsLoad?.task == task {
                contributorsLoad = nil
            }

            return RepositoryContributors()
        }
    }

    /// 关闭仓库时取消还在进行的读取，丢掉读到的数据。
    func close() {
        contributorsLoad?.task.cancel()
        contributorsLoad = nil
        filesLoad?.task.cancel()
        filesLoad = nil
    }

    /// 按条件种类给出建议：作者与提交人分别补全仓库的作者与提交人，文件补全 HEAD 中的路径，其余种类没有建议。
    func suggestions(
        for kind: HistorySearchCondition.Kind,
        matching query: String,
        runner: GitRunner,
        head: String
    ) async -> [ContributorSuggestion] {
        let query = query.trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else {
            return []
        }

        switch kind {
        case .author:
            let people = await contributors(runner: runner, head: head)
            return ContributorSuggestion.matches(query, in: people.authors)

        case .committer:
            let people = await contributors(runner: runner, head: head)
            return ContributorSuggestion.matches(query, in: people.committers)

        case .file:
            let files = await load(\.filesLoad, runner: runner, head: head) {
                try await RepositoryFileViews(runner: runner).files(in: head)
                    .filter { !$0.isSubmodule }
                    .map(\.path)
            }

            return Self.fileMatches(query, in: files).map {
                ContributorSuggestion(text: $0, name: $0, email: nil, showsAvatar: false)
            }

        case .message, .hash, .date:
            return []
        }
    }
}

// MARK: - Private

extension HistorySearchSuggestions {
    /// 同一仓库与 HEAD 的贡献者读取：已有就沿用，否则取消旧的读取、在后台开始新的一次。
    private func contributorsTask(runner: GitRunner, head: String) -> Task<RepositoryContributors, Error> {
        if let cached = contributorsLoad, cached.location == runner.location, cached.head == head {
            return cached.task
        }

        contributorsLoad?.task.cancel()

        // 不由用户直接发起的读取，不弹出凭据或口令的询问
        let task = Task {
            try await RemoteCallbackRequest.$allowsInteraction.withValue(false) {
                try await RepositoryFileViews(runner: runner).contributors(at: head)
            }
        }

        contributorsLoad = Load(location: runner.location, head: head, task: task)
        return task
    }

    /// 同一仓库与 HEAD 的读取共用一次结果；读取失败时没有建议，失败的读取不留在缓存里。
    private func load<Value: Sendable>(
        _ cache: ReferenceWritableKeyPath<HistorySearchSuggestions, Load<[Value]>?>,
        runner: GitRunner,
        head: String,
        operation: @escaping @Sendable () async throws -> [Value]
    ) async -> [Value] {
        let task: Task<[Value], Error>

        if let cached = self[keyPath: cache], cached.location == runner.location, cached.head == head {
            task = cached.task
        } else {
            task = Task { try await operation() }
            self[keyPath: cache] = Load(location: runner.location, head: head, task: task)
        }

        do {
            return try await task.value
        } catch {
            if self[keyPath: cache]?.task == task {
                self[keyPath: cache] = nil
            }

            return []
        }
    }
}
