import Foundation
import SpookyKit

// MARK: - HistorySearchSuggestions

/// 历史搜索的补全数据：仓库的作者与 HEAD 中的文件。
///
/// 同一仓库与 HEAD 只读取一次，服务器仓库的文件清单也只取回一次；读取失败的结果不缓存，下次输入时重试。
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

    /// 作者的读取。
    private var authorsLoad: Load<[FileContributor]>? = nil

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

            if isSubsequence(needle, of: name) {
                return (1, path)
            }

            if lowered.contains(needle) {
                return (2, path)
            }

            return isSubsequence(needle, of: lowered) ? (3, path) : nil
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

    /// 按条件种类给出建议：作者与提交人补全仓库的作者，文件补全 HEAD 中的路径，其余种类没有建议。
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
        case .author, .committer:
            let authors = await load(\.authorsLoad, runner: runner, head: head) {
                try await RepositoryFileViews(runner: runner).contributors(of: nil, at: head)
            }

            return ContributorSuggestion.matches(query, in: authors)

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
    /// needle 的字符是否按顺序出现在 haystack 里。
    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var remaining = needle[...]

        for character in haystack where character == remaining.first {
            remaining = remaining.dropFirst()

            if remaining.isEmpty {
                return true
            }
        }

        return remaining.isEmpty
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
