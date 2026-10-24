import Foundation

// MARK: - RepositoryUndoError

/// 记录或恢复仓库状态时的拒绝原因；Git 本身的失败仍以 ``GitError`` 抛出。
public enum RepositoryUndoError: Error, Sendable, Equatable {
    /// 合并、变基、摘取或反转正在进行。
    case operationInProgress

    /// 索引里有未解决的冲突，写不出树。
    case unresolvedConflicts

    /// 仓库现状已不是记录时的状态。
    case repositoryChanged

    /// 未跟踪文件会被覆盖，或要恢复的未跟踪文件找不回内容。
    case untrackedFiles

    /// 标为 assume-unchanged 的文件有看不到的本地改动，或仓库用了 skip-worktree。
    case hiddenChanges
}

// MARK: - StashRecord

/// 储藏列表里的一项，恢复储藏列表时按原说明重新登记。
public struct StashRecord: Sendable, Equatable {
    /// 储藏提交的完整哈希。
    public let id: String

    /// 储藏在引用日志里的说明，即 `stash list` 显示的那一句。
    public let message: String

    /// 带未跟踪文件保存时的第三个父提交；没有时为 nil。
    public let untracked: String?
}

// MARK: - BranchSetting

/// 仓库配置里 `branch.<名称>` 段的一项：上游、合并方式，以及置顶、归档与父分支。
public struct BranchSetting: Sendable, Equatable {
    /// 段所属的分支名。
    public let branch: String

    /// 完整的配置键，如 `branch.main.remote`。
    public let key: String

    /// 配置值；只写键不写值时为 nil。
    public let value: String?
}

// MARK: - RepositoryState

/// 撤销与重做比较、恢复的仓库状态：分支与标签、HEAD、分支的配置段、储藏列表、索引与工作区。
///
/// 工作区只记已跟踪文件的内容（`stash create` 写出的树）；未跟踪文件只记路径，内容不进快照。
public struct RepositoryState: Sendable, Equatable {
    /// HEAD 指向的分支的完整引用名；分离 HEAD 时为 nil。
    public let headBranch: String?

    /// HEAD 所在的提交；未出生分支为 nil。
    public let head: String?

    /// `refs/heads` 与 `refs/tags` 下的引用指向的对象；附注标签是标签对象本身。
    public let references: [String: String]

    /// 同一组引用剥离附注标签后的目标，与界面的引用快照比较时使用。
    public let peeledReferences: [String: String]

    /// 仓库配置里各分支段的全部项，按配置文件中的顺序。
    public let branchSettings: [BranchSetting]

    /// 储藏列表，从新到旧。
    public let stashes: [StashRecord]

    /// 索引写成的树。
    public let index: String

    /// 已跟踪文件在工作区里的内容写成的树；工作区与索引一致时与 ``index`` 相同。
    public let worktree: String

    /// 同一时刻的文件状态，未跟踪文件逐个列出。
    public let entries: [StatusEntry]

    /// 未跟踪文件的路径。
    public var untracked: [String] {
        entries.filter { $0.kind == .untracked }.map(\.path)
    }

    /// 用界面已经读到的结果粗略比较：HEAD、文件状态、分支与标签、储藏都一致才返回 true。
    ///
    /// 一致不代表文件内容相同，恢复前仍要完整核对；参数为 nil 的部分不参与比较。
    ///
    /// - Parameters:
    ///   - status: 最近一次读取的工作区状态。
    ///   - references: 分支与标签剥离附注标签后的目标，以完整引用名为键。
    ///   - stashes: 储藏提交的哈希，从新到旧。
    public func resembles(
        status: WorkingCopyStatus,
        references: [String: String]?,
        stashes: [String]?
    ) -> Bool {
        let headBranch = status.branch.head.map { "refs/heads/" + $0 }

        guard
            headBranch == self.headBranch,
            status.branch.oid == head,
            status.entries == entries
        else { return false }

        if let references, references != peeledReferences {
            return false
        }

        if let stashes, stashes != self.stashes.map(\.id) {
            return false
        }

        return true
    }
}

// MARK: - Parsing

extension RepositoryState {
    /// 读取分支、标签与储藏引用的 for-each-ref 格式：引用名、对象与剥离后的对象，各以 NUL 结尾。
    static let referenceFormat = "--format=%(refname)%00%(objectname)%00%(*objectname)%00"

    /// 读取储藏列表的格式：哈希、父提交与说明，各以 NUL 结尾。
    static let stashFormat = "--format=tformat:%H%x00%P%x00%gs"

    /// 解析 for-each-ref：返回分支与标签的对象、剥离后的对象，以及是否存在储藏。
    ///
    /// for-each-ref 会在每条记录后补一个换行，按 NUL 切开后下一条的引用名开头会多出这个换行。
    static func parseReferences(
        _ data: Data
    ) throws -> (references: [String: String], peeled: [String: String], hasStash: Bool) {
        var references: [String: String] = [:]
        var peeled: [String: String] = [:]
        var hasStash = false

        guard !data.isEmpty else { return ([:], [:], false) }

        var fields = data
            .split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }

        // 最后一个 NUL 之后只剩换行
        if let last = fields.last, last.trimmingCharacters(in: .newlines).isEmpty {
            fields.removeLast()
        }

        guard fields.count.isMultiple(of: 3) else { throw RepositoryReadError.malformedOutput("for-each-ref") }

        for start in stride(from: 0, to: fields.count, by: 3) {
            let name = fields[start].trimmingCharacters(in: .newlines)
            let object = fields[start + 1]
            let target = fields[start + 2]

            guard
                name.hasPrefix("refs/"), GitObjectID.isValid(object),
                target.isEmpty || GitObjectID.isValid(target)
            else { throw RepositoryReadError.malformedOutput("for-each-ref") }

            if name == "refs/stash" {
                hasStash = true
            } else {
                references[name] = object
                peeled[name] = target.isEmpty ? object : target
            }
        }

        return (references, peeled, hasStash)
    }

    /// 解析 `config -z --get-regexp` 读出的分支段：每条是键、换行、值，没有值的键只有键本身。
    ///
    /// 键的第一个点与最后一个点之间是分支名，分支名本身可以含点。
    static func parseBranchSettings(_ data: Data) throws -> [BranchSetting] {
        try data.split(separator: 0).map { record in
            let key = String(decoding: record.prefix { $0 != 10 }, as: UTF8.self)
            let value = record.firstIndex(of: 10).map { String(decoding: record[($0 + 1)...], as: UTF8.self) }

            guard
                key.hasPrefix("branch."),
                let last = key.lastIndex(of: "."),
                last > key.index(key.startIndex, offsetBy: 7)
            else { throw RepositoryReadError.malformedOutput("branch config") }

            let branch = String(key[key.index(key.startIndex, offsetBy: 7) ..< last])
            return BranchSetting(branch: branch, key: key, value: value)
        }
    }

    /// 解析 `stash list -z` 按 ``stashFormat`` 的输出，每条三个字段。
    static func parseStashes(_ data: Data) throws -> [StashRecord] {
        guard !data.isEmpty else { return [] }
        guard data.last == 0 else { throw RepositoryReadError.malformedOutput("stash list") }

        let fields = data
            .dropLast()
            .split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }

        guard fields.count.isMultiple(of: 3) else { throw RepositoryReadError.malformedOutput("stash list") }

        return try stride(from: 0, to: fields.count, by: 3)
            .map { start in
                let parents = fields[start + 1].split(separator: " ").map(String.init)

                guard
                    GitObjectID.isValid(fields[start]), (2 ... 3).contains(parents.count),
                    parents.allSatisfy(GitObjectID.isValid)
                else { throw RepositoryReadError.malformedOutput("stash list") }

                return StashRecord(
                    id: fields[start],
                    message: fields[start + 2],
                    untracked: parents.count == 3 ? parents[2] : nil
                )
            }
    }
}
