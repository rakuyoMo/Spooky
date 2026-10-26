import Foundation

// MARK: - WorktreeEntry

/// `git worktree list` 列出的一个工作树。
public struct WorktreeEntry: Sendable, Equatable {
    /// 工作树的绝对路径，位于仓库所在的机器上。
    public let path: String

    /// 检出的分支的完整引用名；分离 HEAD 时为 nil。
    public let branch: String?

    /// 列表与快捷操作里显示的名称：路径的最后一段。
    public var name: String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}

// MARK: - LinkedRepositories

/// 仓库的工作树清单；只读，在仓库所在的机器上执行。
public struct LinkedRepositories: Sendable {
    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 创建只读的清单服务。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 仓库的全部工作树，第一个是主工作树；裸仓库与目录已不存在的工作树不列出。
    public func worktrees() async throws -> [WorktreeEntry] {
        let output = try await runner.run(["worktree", "list", "--porcelain", "-z"])

        return try Self.parseWorktrees(output)
    }
}

// MARK: - Parsing

extension LinkedRepositories {
    /// 解析 `worktree list --porcelain -z` 的输出：属性以 NUL 分隔，每个工作树以一个空属性结束。
    static func parseWorktrees(_ data: Data) throws -> [WorktreeEntry] {
        guard !data.isEmpty else {
            return []
        }

        guard data.count >= 2, data.suffix(2).elementsEqual([0, 0]) else {
            throw RepositoryReadError.malformedOutput("worktree")
        }

        let fields = data.dropLast(2)
            .split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }

        // 空属性把属性序列切成一个个工作树
        let records = fields.split(separator: "", omittingEmptySubsequences: false)

        return try records.compactMap { record in
            guard let first = record.first, first.hasPrefix("worktree "), first.count > "worktree ".count else {
                throw RepositoryReadError.malformedOutput("worktree")
            }

            // 裸仓库没有工作区，目录已不存在的工作树无法打开
            guard !record.contains("bare"), !record.contains(where: { $0 == "prunable" || $0.hasPrefix("prunable ") })
            else { return nil }

            let branch = record.first { $0.hasPrefix("branch ") }.map { String($0.dropFirst("branch ".count)) }

            return WorktreeEntry(path: String(first.dropFirst("worktree ".count)), branch: branch)
        }
    }
}
