import Foundation

// MARK: - BranchMetadata

/// 本地分支写在仓库配置里的附加信息：置顶、归档、父分支与分支整理的标记。
///
/// 值存放在 `branch.<名称>` 段，`git branch -m` 改名时随段移动，删除分支时随段清除。
public struct BranchMetadata: Sendable, Equatable {
    /// 置顶标记的配置变量名。
    static let pinnedKey = "spooky-pinned"

    /// 归档标记的配置变量名。
    static let archivedKey = "spooky-archived"

    /// 父分支的配置变量名。
    static let parentKey = "spooky-parent"

    /// 自动归档时跳过的配置变量名。
    static let skipAutoArchiveKey = "spooky-skip-auto-archive"

    /// 自动归档后待审阅的配置变量名。
    static let archiveReviewKey = "spooky-archive-review"

    /// 全部附加信息的配置变量名，一次读出。
    static let keys = [pinnedKey, archivedKey, parentKey, skipAutoArchiveKey, archiveReviewKey]

    /// 是否置顶在侧边栏的 Pinned 分组。
    public var isPinned: Bool

    /// 是否归入 Archived Branches 分组。
    public var isArchived: Bool

    /// 父分支的完整引用名；与基准分支比较、Update Branch 以它为基准。
    public var parent: String?

    /// 自动归档时跳过这个分支。
    public var skipsAutoArchive = false

    /// 由自动归档归入、还没有看过；Archived Branches 分组标题据此显示圆点。
    public var needsArchiveReview = false

    /// 创建一份分支信息，默认既不置顶也不归档、没有父分支，也没有分支整理的标记。
    public init(isPinned: Bool = false, isArchived: Bool = false, parent: String? = nil) {
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.parent = parent
    }

    /// 解析 `config -z --get-regexp` 的记录：每条是键、换行、值，没有值的键只有键本身。
    ///
    /// 键的第一个点与最后一个点之间是分支名，分支名本身可以含点；结果以 `refs/heads/<名称>` 为键。
    static func parse(_ data: Data) throws -> [String: Self] {
        var result: [String: Self] = [:]

        for record in data.split(separator: 0) {
            let key = String(decoding: record.prefix { $0 != 10 }, as: UTF8.self)
            let value = record.firstIndex(of: 10).map { String(decoding: record[($0 + 1)...], as: UTF8.self) }

            guard
                key.hasPrefix("branch."),
                let last = key.lastIndex(of: "."),
                last > key.index(key.startIndex, offsetBy: 6)
            else {
                throw RepositoryReadError.malformedOutput("branch config")
            }

            let name = String(key[key.index(key.startIndex, offsetBy: 7) ..< last])
            let variable = key[key.index(after: last)...].lowercased()
            var metadata = result["refs/heads/" + name] ?? Self()

            // 布尔值沿用 Git 的写法；只写键不写值同样表示真。
            switch variable {
            case pinnedKey:
                metadata.isPinned = isTrue(value)

            case archivedKey:
                metadata.isArchived = isTrue(value)

            case parentKey:
                metadata.parent = value.flatMap { $0.isEmpty ? nil : $0 }

            case skipAutoArchiveKey:
                metadata.skipsAutoArchive = isTrue(value)

            case archiveReviewKey:
                metadata.needsArchiveReview = isTrue(value)

            default:
                continue
            }

            result["refs/heads/" + name] = metadata
        }

        return result
    }

    /// 只接受完整的本地分支引用名，换成 `branch.<名称>.<变量>` 形式的配置键。
    static func configKey(_ variable: String, of branch: String) throws -> String {
        guard branch.hasPrefix("refs/heads/"), branch.count > "refs/heads/".count else {
            throw RepositoryReadError.invalidQuery
        }

        return "branch." + branch.dropFirst("refs/heads/".count) + "." + variable
    }

    /// Git 把 true、yes、on、1 与空值都当作真。
    static func isTrue(_ value: String?) -> Bool {
        guard let value else { return true }
        return ["true", "yes", "on", "1", ""].contains(value.lowercased())
    }
}

// MARK: - RepositoryReferences

extension RepositoryReferences {
    /// 一次读取全部本地分支的置顶、归档、父分支与分支整理的标记；没有任何记录时返回空表。
    public func metadata() async throws -> [String: BranchMetadata] {
        let pattern = "^branch\\..*\\.(" + BranchMetadata.keys.joined(separator: "|") + ")$"

        // 没有匹配的键时 config 以 1 退出，是正常的空结果。
        let result = try await runner.execute(
            ["config", "-z", "--get-regexp", pattern],
            acceptedExitCodes: [0, 1]
        )

        return try BranchMetadata.parse(result.standardOutput)
    }

    /// 置顶或取消置顶若干本地分支，多条配置写入作为一次仓库操作。
    public func setPinned(_ pinned: Bool, branches: [String]) async throws {
        try await setFlag(BranchMetadata.pinnedKey, to: pinned, branches: branches)
    }

    /// 归档或取消归档若干本地分支，多条配置写入作为一次仓库操作。
    ///
    /// 取消归档同时清除待审阅标记；自动归档传入 `review` 为 true，给这批分支记上待审阅。
    public func setArchived(_ archived: Bool, branches: [String], review: Bool = false) async throws {
        try await runner.writeTransaction {
            try await setFlag(BranchMetadata.archivedKey, to: archived, branches: branches)

            if !archived || review {
                try await setFlag(BranchMetadata.archiveReviewKey, to: archived && review, branches: branches)
            }
        }
    }

    /// 设置或取消若干本地分支的 “自动归档时跳过”。
    public func setSkipsAutoArchive(_ skips: Bool, branches: [String]) async throws {
        try await setFlag(BranchMetadata.skipAutoArchiveKey, to: skips, branches: branches)
    }

    /// 清除若干自动归档分支的待审阅标记。
    public func markArchiveReviewed(branches: [String]) async throws {
        try await setFlag(BranchMetadata.archiveReviewKey, to: false, branches: branches)
    }

    /// 设置或移除父分支；父分支必须是完整引用名，传 nil 表示移除。
    public func setParent(_ parent: String?, of branch: String) async throws {
        let key = try BranchMetadata.configKey(BranchMetadata.parentKey, of: branch)

        guard let parent else {
            try await unset(key)
            return
        }

        guard parent.hasPrefix("refs/"), parent != branch else {
            throw RepositoryReadError.invalidQuery
        }

        _ = try await runner.run(["config", "--local", key, parent])
    }

    /// 布尔标记只写 true；取消时删除键，让配置里不留下 false 值。
    private func setFlag(_ variable: String, to value: Bool, branches: [String]) async throws {
        let keys = try branches.map { try BranchMetadata.configKey(variable, of: $0) }

        guard !keys.isEmpty else { throw RepositoryReadError.invalidQuery }

        try await runner.writeTransaction {
            for key in keys {
                if value {
                    _ = try await runner.run(["config", "--local", key, "true"])
                } else {
                    try await unset(key)
                }
            }
        }
    }

    /// 键本来就不存在时 Git 以 5 退出，结果与删除成功相同。
    private func unset(_ key: String) async throws {
        _ = try await runner.execute(["config", "--local", "--unset-all", key], acceptedExitCodes: [0, 5])
    }
}
