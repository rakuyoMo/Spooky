import Foundation

// MARK: - Worktree

/// `git worktree list` 列出的一个工作树。
public struct Worktree: Sendable, Hashable, Identifiable {
    /// 以路径区分工作树。
    public var id: String { path }

    /// 工作树的绝对路径，位于仓库所在的机器上。
    public let path: String

    /// 检出的提交；还没有提交的分支为 nil。
    public let head: String?

    /// 检出的分支的完整引用名；分离 HEAD 时为 nil。
    public let branch: String?

    /// 是主工作树，即列表里的第一个；主工作树不能移动或删除。
    public let isMain: Bool

    /// 是执行命令的这个仓库自己。
    public let isCurrent: Bool

    /// 主工作树是裸仓库，没有工作区。
    public let isBare: Bool

    /// 已锁定；有说明时为说明，没有说明时为空字符串，没有锁定时为 nil。
    public let lockReason: String?

    /// 目录已不存在等原因使工作树失效；有效时为 nil。
    public let prunableReason: String?

    /// 列表与快捷操作里显示的名称：路径的最后一段。
    public var name: String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    /// 工作树有效，可以打开。
    public var isValid: Bool {
        prunableReason == nil && !isBare
    }

    /// 检出分支的简短名称；分离 HEAD 时为 nil。
    public var branchName: String? {
        branch.map { $0.hasPrefix("refs/heads/") ? String($0.dropFirst("refs/heads/".count)) : $0 }
    }

    /// 创建工作树；解析与测试使用。
    public init(
        path: String,
        head: String?,
        branch: String?,
        isMain: Bool,
        isCurrent: Bool = false,
        isBare: Bool = false,
        lockReason: String? = nil,
        prunableReason: String? = nil
    ) {
        self.path = path
        self.head = head
        self.branch = branch
        self.isMain = isMain
        self.isCurrent = isCurrent
        self.isBare = isBare
        self.lockReason = lockReason
        self.prunableReason = prunableReason
    }
}

// MARK: - Parsing

extension Worktree {
    /// 解析 `worktree list --porcelain -z` 的输出：属性以 NUL 分隔，每个工作树以一个空属性结束，第一个是主工作树。
    static func parseList(_ data: Data) throws -> [Worktree] {
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

        return try records.enumerated().map { index, record in
            guard let first = record.first, first.hasPrefix("worktree "), first.count > "worktree ".count else {
                throw RepositoryReadError.malformedOutput("worktree")
            }

            return Worktree(
                path: String(first.dropFirst("worktree ".count)),
                head: Self.value(of: "HEAD", in: record),
                branch: Self.value(of: "branch", in: record),
                isMain: index == 0,
                isBare: record.contains("bare"),
                lockReason: Self.value(of: "locked", in: record, flag: true),
                prunableReason: Self.value(of: "prunable", in: record, flag: true)
            )
        }
    }

    /// 一个属性的值：`名称 值` 取值；可以只有名称的属性没有值时为空字符串。
    private static func value(of name: String, in record: ArraySlice<String>, flag: Bool = false) -> String? {
        for field in record {
            if field.hasPrefix(name + " ") {
                return String(field.dropFirst(name.count + 1))
            }

            if flag, field == name {
                return ""
            }
        }

        return nil
    }
}
