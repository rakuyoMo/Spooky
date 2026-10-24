import Foundation

// MARK: - Query

extension RepositoryHistory {
    /// 根集合经 stdin 传给 log 与 rev-list，每行一个对象哈希。
    static func rootsInput(_ roots: [String]) -> Data {
        Data((roots.joined(separator: "\n") + "\n").utf8)
    }

    /// 按查询数出固定根集合里的提交，最多数到 `limit`；数到上限时调用方按 “或更多” 显示。
    public func count(roots: [String], query: HistoryQuery = HistoryQuery(), limit: Int) async throws -> Int {
        guard limit > 0, roots.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.invalidQuery
        }

        guard !roots.isEmpty else {
            return 0
        }

        // 按哈希搜索的结果最多几个，直接数出
        if !query.hashPrefixes.isEmpty {
            return try await min(commits(matchingHashesIn: query, roots: roots).count, limit)
        }

        let output = try await runner.immutableRun(
            RepositoryFileViews.storedPathOptions
                + ["rev-list", "--count", "--max-count=\(limit)"]
                + query.filterArguments
                + ["--stdin", "--"]
                + query.paths,
            input: Self.rootsInput(roots)
        )

        let text = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard let count = Int(text) else {
            throw RepositoryReadError.malformedOutput("rev-list")
        }

        return count
    }

    /// 提交是否能从固定根集合中的某一个沿父提交到达。
    public func contains(_ commit: String, roots: [String]) async throws -> Bool {
        guard GitObjectID.isValid(commit), roots.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.invalidQuery
        }

        guard !roots.isEmpty else {
            return false
        }

        // 排除全部根可达的提交后，什么都不剩就说明这个提交可达
        let excluded = Data(roots.map { "^" + $0 + "\n" }.joined().utf8)
        let output = try await runner.immutableRun(
            ["rev-list", "--max-count=1", "--stdin", commit],
            input: excluded
        )

        return output.isEmpty
    }

    /// 按哈希前缀找到的提交：每个前缀先在仓库里解析成唯一的提交，只保留根可达的，再套用其余条件。
    ///
    /// 前缀不足 4 位、不是十六进制、查不到或有多个提交共用时都没有结果。
    func commits(matchingHashesIn query: HistoryQuery, roots: [String]) async throws -> [HistoryCommit] {
        var candidates: [String] = []

        for prefix in query.hashPrefixes where GitObjectID.isValid(prefix) {
            let resolved = try await runner.execute(
                ["rev-parse", "--verify", "--quiet", prefix + "^{commit}"],
                acceptedExitCodes: [0, 1]
            )
            let id = String(decoding: resolved.standardOutput, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

            guard
                resolved.exitCode == 0,
                GitObjectID.isValid(id),
                !candidates.contains(id),
                try await contains(id, roots: roots)
            else { continue }

            candidates.append(id)
        }

        guard !candidates.isEmpty else {
            return []
        }

        // 只列出这些提交本身，信息、作者、日期与路径条件照常筛选
        let output = try await runner.run(
            RepositoryFileViews.storedPathOptions + Self.logOptions + [
                "log", "--no-color", "--no-decorate", "--no-patch", "-z", HistoryCommit.format, "--no-walk",
            ]
                + query.filterArguments.filter { $0 != "--first-parent" }
                + ["--stdin", "--"]
                + query.paths,
            input: Self.rootsInput(candidates)
        )

        return try HistoryCommit.parse(output)
    }
}
