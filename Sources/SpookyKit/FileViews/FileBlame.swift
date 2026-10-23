import Foundation

// MARK: - BlameCommit

/// Blame 结果中引入某些行的提交，只包含 `--porcelain` 给出的元信息。
public struct BlameCommit: Sendable, Equatable, Identifiable {
    /// 完整对象标识，不限定 SHA-1 的长度。
    public let id: String

    /// 作者姓名。
    public let author: String

    /// 作者邮箱，不含尖括号。
    public let authorEmail: String

    /// 作者日期。
    public let authorDate: Date

    /// 提交人姓名。
    public let committer: String

    /// 提交人邮箱，不含尖括号。
    public let committerEmail: String

    /// 提交人日期。
    public let commitDate: Date

    /// 提交标题。
    public let summary: String

    /// 短哈希只用于显示，动作始终使用完整对象标识。
    public var shortID: String { String(id.prefix(8)) }
}

// MARK: - BlameGroup

/// 连续来自同一提交的一段行；Git 按原文件中连续的行分段，相邻两段可以属于同一提交。
public struct BlameGroup: Sendable, Equatable {
    /// 引入这些行的提交。
    public let commitID: String

    /// 本段第一行在当前版本中的行号，从 1 开始。
    public let firstLine: Int

    /// 本段的行数。
    public let lineCount: Int

    /// 本段第一行在引入它的提交中的行号。
    public let originalLine: Int
}

// MARK: - FileBlame

/// 一个版本的逐行追溯结果：按段排列的提交归属与各行原文。
public struct FileBlame: Sendable, Equatable {
    /// 结果中出现的提交，按完整哈希索引。
    public let commits: [String: BlameCommit]

    /// 覆盖全部行、按行号排列的段。
    public let groups: [BlameGroup]

    /// 各行原文，不含行尾换行。
    public let lines: [String]

    /// 解析 `blame --porcelain`：每行先有 “哈希 原行号 终行号 [段行数]” 的头，
    /// 提交第一次出现时随后给出元信息，最后是以制表符开头的原文。
    static func parse(_ data: Data) throws -> Self {
        var parser = Parser()

        // 每条记录以换行结尾，最后一行原文后同样有换行
        guard data.isEmpty || data.last == 10 else {
            throw RepositoryReadError.malformedOutput("blame")
        }

        for record in data.split(separator: 10, omittingEmptySubsequences: false).dropLast() {
            try parser.consume(record)
        }

        return try parser.finish()
    }
}

// MARK: FileBlame.Parser

extension FileBlame {
    /// 逐条消费 porcelain 记录的状态机，任何错位都视为格式错误。
    private struct Parser {
        /// 已完成元信息的提交。
        var commits: [String: BlameCommit] = [:]

        /// 已开始的段。
        var groups: [BlameGroup] = []

        /// 已读到的各行原文。
        var lines: [String] = []

        /// 当前行的提交；读到头之后、原文之前不为 nil。
        var pendingCommit: String? = nil

        /// 第一次出现的提交正在收集的元信息。
        var fields: [String: String] = [:]

        /// 当前段还剩多少行。
        var remainingInGroup = 0

        /// 处理一条记录：头、元信息或原文。
        mutating func consume(_ record: Data) throws {
            // 原文以制表符开头；原文本身可以含有任意字符
            if record.first == 9 {
                try finishLine(String(decoding: record.dropFirst(), as: UTF8.self))
                return
            }

            let text = String(decoding: record, as: UTF8.self)

            guard pendingCommit != nil else {
                try startLine(text)
                return
            }

            // 元信息形如 “键 值”，boundary 等标记没有值
            let pair = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
            fields[String(pair[0])] = pair.count > 1 ? String(pair[1]) : ""
        }

        /// 读到行头：段的第一行带段行数，其余行必须延续当前段的提交与行号。
        mutating func startLine(_ header: String) throws {
            let values = header.split(separator: " ").map(String.init)

            guard
                [3, 4].contains(values.count),
                GitObjectID.isValid(values[0]),
                let original = Int(values[1]), original > 0,
                let final = Int(values[2]), final == lines.count + 1
            else { throw RepositoryReadError.malformedOutput("blame") }

            if values.count == 4 {
                guard remainingInGroup == 0, let count = Int(values[3]), count > 0 else {
                    throw RepositoryReadError.malformedOutput("blame")
                }

                groups.append(
                    BlameGroup(commitID: values[0], firstLine: final, lineCount: count, originalLine: original)
                )
                remainingInGroup = count
            } else {
                guard remainingInGroup > 0, groups.last?.commitID == values[0] else {
                    throw RepositoryReadError.malformedOutput("blame")
                }
            }

            pendingCommit = values[0]
            fields = [:]
        }

        /// 读到原文：提交第一次出现时用收集到的元信息建立记录。
        mutating func finishLine(_ content: String) throws {
            guard let commit = pendingCommit else {
                throw RepositoryReadError.malformedOutput("blame")
            }

            if commits[commit] == nil {
                commits[commit] = try makeCommit(commit)
            }

            lines.append(content)
            remainingInGroup -= 1
            pendingCommit = nil
        }

        /// 结果必须以完整的段结束。
        func finish() throws -> FileBlame {
            guard pendingCommit == nil, remainingInGroup == 0 else {
                throw RepositoryReadError.malformedOutput("blame")
            }

            return FileBlame(commits: commits, groups: groups, lines: lines)
        }

        /// 提交第一次出现时必须带齐作者、提交人与标题。
        private func makeCommit(_ id: String) throws -> BlameCommit {
            guard
                let author = fields["author"],
                let authorEmail = fields["author-mail"],
                let authorTime = fields["author-time"].flatMap({ Int64($0) }),
                let committer = fields["committer"],
                let committerEmail = fields["committer-mail"],
                let commitTime = fields["committer-time"].flatMap({ Int64($0) }),
                let summary = fields["summary"]
            else { throw RepositoryReadError.malformedOutput("blame") }

            return BlameCommit(
                id: id,
                author: author,
                authorEmail: Self.unwrapped(authorEmail),
                authorDate: Date(timeIntervalSince1970: Double(authorTime)),
                committer: committer,
                committerEmail: Self.unwrapped(committerEmail),
                commitDate: Date(timeIntervalSince1970: Double(commitTime)),
                summary: summary
            )
        }

        /// 去掉邮箱两侧的尖括号。
        private static func unwrapped(_ email: String) -> String {
            guard email.hasPrefix("<"), email.hasSuffix(">"), email.count >= 2 else {
                return email
            }

            return String(email.dropFirst().dropLast())
        }
    }
}
