import Foundation

// MARK: - Query

extension RepositoryHistory {
    /// 根集合经 stdin 传给 log 与 rev-list，每行一个对象哈希。
    static func rootsInput(_ roots: [String]) -> Data {
        Data((roots.joined(separator: "\n") + "\n").utf8)
    }

    /// 从 rev-list 每行一个哈希的输出里找出提交的下标；不在其中时为 nil，有一行不是哈希时报告格式错误。
    static func position(of commit: String, in output: Data) throws -> Int? {
        let lines = String(decoding: output, as: UTF8.self)
            .split(separator: "\n")
            .map(String.init)

        guard lines.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.malformedOutput("rev-list")
        }

        return lines.firstIndex(of: commit)
    }

    /// 按查询数出固定根集合里的提交，最多数到 `limit`；数到上限时调用方按 “或更多” 显示，条件编译不了时为 0。
    public func count(roots: [String], query: HistoryQuery = HistoryQuery(), limit: Int) async throws -> Int {
        guard limit > 0, roots.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.invalidQuery
        }

        // 条件编译不了时没有结果，不执行 Git
        guard !roots.isEmpty, let query = try await resolved(query) else {
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

    /// 提交在固定根集合按查询排序、筛选后的历史里的下标（0 起），只看前 `limit` 个；不在其中或条件编译不了时为 nil。
    ///
    /// 顺序与 ``page(roots:query:offset:limit:)`` 相同，回到历史时据此判断要找的提交排在多后面；不支持哈希条件。
    public func position(
        of commit: String,
        roots: [String],
        query: HistoryQuery = HistoryQuery(),
        limit: Int
    ) async throws -> Int? {
        guard
            limit > 0,
            GitObjectID.isValid(commit),
            roots.allSatisfy(GitObjectID.isValid),
            query.hashPrefixes.isEmpty
        else {
            throw RepositoryReadError.invalidQuery
        }

        // 条件编译不了时不在其中，不执行 Git
        guard !roots.isEmpty, let query = try await resolved(query) else {
            return nil
        }

        // 与分页相同的排序与筛选，只列出哈希
        let output = try await runner.immutableRun(
            RepositoryFileViews.storedPathOptions
                + ["rev-list"]
                + query.orderArguments
                + query.filterArguments
                + ["--max-count=\(limit)", "--stdin", "--"]
                + query.paths,
            input: Self.rootsInput(roots)
        )

        return try Self.position(of: commit, in: output)
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

    /// 按仓库生效的配置定下说明、作者与提交人条件的写法；条件编译不了时为 nil，调用方直接给出空结果。
    ///
    /// 没有这几类条件时原样返回，不读配置。
    func resolved(_ query: HistoryQuery) async throws -> HistoryQuery? {
        guard !query.patternConditions.isEmpty else {
            return query
        }

        var query = query
        query.patternType = try await patternType()

        guard query.patternType == .perl else {
            return query.hasInvalidPattern ? nil : query
        }

        return try await perlPatternsCompile(query) ? query : nil
    }

    /// 仓库生效的配置下 `git log` 匹配说明、作者与提交人的写法。
    ///
    /// 与 Git 相同：`grep.patternType` 是 basic、extended、fixed 或 perl 时照它；
    /// 是 default、没有配置或取值无效时，`grep.extendedRegexp` 为真取扩展正则，否则取基本正则。
    func patternType() async throws -> HistoryQuery.PatternType {
        let pattern = "^grep\\.(patterntype|extendedregexp)$"

        // 布尔值由 Git 规范成 true 或 false，数字与 yes、on 等写法都与 log 的解读相同
        let result = try await runner.execute(
            ["config", "-z", "--type=bool-or-str", "--get-regexp", pattern],
            acceptedExitCodes: [0, 1]
        )
        let values = try ConfigRecords.parse(result.standardOutput, pattern: pattern, context: "grep config")

        if let type = values["grep.patterntype"].flatMap({ $0 }).flatMap(HistoryQuery.PatternType.init(rawValue:)) {
            return type
        }

        let extended = values["grep.extendedregexp"].map(ConfigRecords.boolean) ?? false
        return extended ? .extended : .basic
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

    /// Perl 正则交给仓库所在机器上的 Git 编译；Git 不支持 Perl 正则时照 Git 的原文报错。
    private func perlPatternsCompile(_ query: HistoryQuery) async throws -> Bool {
        // 空的根集合只编译条件、不遍历提交
        let check = try await runner.execute(
            ["rev-list", "--stdin"] + query.filterArguments,
            input: Data(),
            acceptedExitCodes: [0, 128]
        )

        guard check.exitCode != 0 else {
            return true
        }

        // 一个必定合法的条件也编译不了，说明失败不是条件本身的问题，抛出 Git 的错误
        _ = try await runner.run(["rev-list", "--stdin", "-i", "--perl-regexp", "--grep=."], input: Data())

        return false
    }
}
