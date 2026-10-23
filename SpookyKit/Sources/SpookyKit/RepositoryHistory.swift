import Foundation

/// 结构化 Git 输出损坏时拒绝显示不完整或错位的数据。
public enum RepositoryReadError: Error, Sendable, Equatable {
    /// 发生格式错误的查询名称。
    case malformedOutput(String)

    /// 查询参数不能表示单个提交或有界分页。
    case invalidQuery
}

/// 历史中的不可变提交元信息，日期以 64 位 Unix 秒读取。
public struct HistoryCommit: Sendable, Equatable, Identifiable {
    /// 完整对象标识，不限定 SHA-1 的长度。
    public let id: String

    /// 提交对应的树对象。
    public let tree: String

    /// 按 Git 原始顺序排列的父提交。
    public let parents: [String]

    /// 原始作者姓名。
    public let author: String

    /// 原始作者邮箱。
    public let authorEmail: String

    /// 作者日期。
    public let authorDate: Date

    /// 实际提交人姓名。
    public let committer: String

    /// 实际提交人邮箱。
    public let committerEmail: String

    /// 列表使用提交人日期。
    public let commitDate: Date

    /// 包含标题和正文的完整提交信息。
    public let message: String

    /// 列表只展示第一行，详情保留全文。
    public var subject: String { String(message.prefix { $0 != "\n" }) }

    /// 短哈希只用于显示，动作始终使用完整对象标识。
    public var shortID: String { String(id.prefix(8)) }

    /// 逐组读取固定数量的 NUL 字段，正文中的换行和分隔控制字符不影响边界。
    static func parse(_ data: Data) throws -> [Self] {
        guard !data.isEmpty else { return [] }
        guard data.last == 0 else { throw RepositoryReadError.malformedOutput("log") }
        let fields = data.dropLast().split(separator: 0, omittingEmptySubsequences: false)
        guard fields.count.isMultiple(of: 10) else { throw RepositoryReadError.malformedOutput("log") }

        return try stride(from: 0, to: fields.count, by: 10)
            .map { start in
                let values = fields[start..<(start + 10)].map { String(decoding: $0, as: UTF8.self) }
                let parents = values[2].split(separator: " ").map(String.init)

                guard GitObjectID.isValid(values[0]), GitObjectID.isValid(values[1]),
                    parents.allSatisfy(GitObjectID.isValid),
                    let authorTime = Int64(values[5]), let commitTime = Int64(values[8])
                else { throw RepositoryReadError.malformedOutput("log") }

                return Self(
                    id: values[0],
                    tree: values[1],
                    parents: parents,
                    author: values[3],
                    authorEmail: values[4],
                    authorDate: Date(timeIntervalSince1970: Double(authorTime)),
                    committer: values[6],
                    committerEmail: values[7],
                    commitDate: Date(timeIntervalSince1970: Double(commitTime)),
                    message: values[9]
                )
            }
    }
}

/// 一页历史与继续加载标记，额外读取一条即可判断是否存在下一页。
public struct HistoryPage: Sendable {
    /// 当前页的提交。
    public let commits: [HistoryCommit]

    /// 下一页是否仍有数据。
    public let hasMore: Bool
}

/// 提交变更集中的单个文件，路径来自 NUL 字段而非补丁标题。
public struct CommitFileChange: Sendable, Equatable, Identifiable {
    /// 新路径作为变更集内的稳定标识。
    public var id: String { path }

    /// 修改后的路径，删除时为原路径。
    public let path: String

    /// 重命名或复制的来源路径。
    public let originalPath: String?

    /// Git raw 格式中的状态字母，包含类型变化。
    public let status: String

    /// 文本新增行数，二进制为 nil。
    public var additions: Int?

    /// 文本删除行数，二进制为 nil。
    public var deletions: Int?

    /// raw 与 numstat 通过原始路径配对，二进制和重命名不会让后续统计错位。
    static func parse(_ data: Data) throws -> [Self] {
        guard !data.isEmpty else { return [] }
        guard data.last == 0 else { throw RepositoryReadError.malformedOutput("changeset") }
        let fields = data.dropLast().split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }
        var files: [Self] = []
        var indices: [String: Int] = [:]
        var counted = Set<String>()
        var cursor = 0

        while cursor < fields.count {
            let field = fields[cursor]
            cursor += 1

            if field.hasPrefix(":") {
                let header = field.dropFirst().split(separator: " ")
                guard header.count == 5,
                    header[0].count == 6, header[1].count == 6,
                    header[0].allSatisfy({ "01234567".contains($0) }),
                    header[1].allSatisfy({ "01234567".contains($0) }),
                    GitObjectID.isValid(String(header[2])), GitObjectID.isValid(String(header[3])),
                    let status = header[4].first, "ADMCRTU".contains(status),
                    cursor < fields.count
                else { throw RepositoryReadError.malformedOutput("changeset") }

                let original = fields[cursor]
                cursor += 1
                let renamed = status == "R" || status == "C"
                guard !renamed || cursor < fields.count else {
                    throw RepositoryReadError.malformedOutput("changeset")
                }
                let path = renamed ? fields[cursor] : original
                if renamed { cursor += 1 }
                guard !path.isEmpty, !original.isEmpty, indices[path] == nil else {
                    throw RepositoryReadError.malformedOutput("changeset")
                }
                indices[path] = files.count
                files.append(
                    Self(
                        path: path,
                        originalPath: renamed ? original : nil,
                        status: String(status),
                        additions: nil,
                        deletions: nil
                    )
                )
            } else {
                let stats = field.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
                guard stats.count == 3 else { throw RepositoryReadError.malformedOutput("numstat") }
                var path = String(stats[2])
                var original: String?

                // 重命名统计使用空路径字段，随后是两个独立的 NUL 路径。
                if path.isEmpty {
                    guard cursor + 1 < fields.count else {
                        throw RepositoryReadError.malformedOutput("numstat")
                    }
                    original = fields[cursor]
                    path = fields[cursor + 1]
                    cursor += 2
                }

                let binary = stats[0] == "-" && stats[1] == "-"
                let additions = Int(stats[0])
                let deletions = Int(stats[1])
                guard let index = indices[path], !counted.contains(path),
                    files[index].originalPath == original,
                    binary || (additions != nil && deletions != nil && additions! >= 0 && deletions! >= 0)
                else { throw RepositoryReadError.malformedOutput("numstat") }
                files[index].additions = additions
                files[index].deletions = deletions
                counted.insert(path)
            }
        }

        guard counted.count == files.count else { throw RepositoryReadError.malformedOutput("numstat") }
        return files
    }
}

/// 历史补丁只读，沿用工作区的大 Diff 阈值与解析器。
public struct CommitDiff: Sendable {
    /// 单次补丁字节数。
    public let byteCount: Int

    /// 超过阈值时等待用户放行。
    public let diff: RepositoryDiff?
}

/// 历史读取在仓库所在机器完成；分页的根固定为对象哈希，避免新提交导致翻页重复。
public struct RepositoryHistory: Sendable {
    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 创建只读历史服务。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 读取固定根集合的一页；空集合表示仓库没有可显示的提交。
    public func page(roots: [String], offset: Int = 0, limit: Int = 100) async throws -> HistoryPage {
        guard offset >= 0, (1...1000).contains(limit), roots.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.invalidQuery
        }
        guard !roots.isEmpty else { return HistoryPage(commits: [], hasMore: false) }

        // 根集合经 stdin 传递，引用数量不会扩大进程参数长度；固定根的分页结果不再变化，可按哈希复用。
        let output = try await runner.immutableRun(
            Self.logOptions + [
                "log", "--no-color", "--no-decorate", "--no-patch", "--topo-order", "-z",
                "--format=tformat:%H%x00%T%x00%P%x00%an%x00%ae%x00%at%x00%cn%x00%ce%x00%ct%x00%B",
                "--max-count=\(limit + 1)", "--skip=\(offset)", "--stdin", "--",
            ],
            input: Data((roots.joined(separator: "\n") + "\n").utf8)
        )
        let commits = try HistoryCommit.parse(output)
        return HistoryPage(commits: Array(commits.prefix(limit)), hasMore: commits.count > limit)
    }

    /// 根提交显式显示全部新增，合并提交统一比较第一父提交；变更集只由提交哈希决定，按哈希复用。
    public func changes(in commit: String) async throws -> [CommitFileChange] {
        guard GitObjectID.isValid(commit) else { throw RepositoryReadError.invalidQuery }
        let output = try await runner.immutableRun(
            Self.logOptions + [
                "show", "--format=", "--root", "--diff-merges=first-parent", "--no-color",
                "--no-ext-diff", "--no-textconv", "--raw", "--numstat", "--no-abbrev", "-z", "-M", "-C",
                commit, "--",
            ]
        )
        return try CommitFileChange.parse(output)
    }

    /// 按需加载指定提交的文件补丁，不沿历史搜索更早修改；补丁按提交哈希与路径复用。
    public func diff(
        in commit: String,
        file: CommitFileChange,
        warningKilobytes: Int = WorkingCopyOperations.defaultWarningKilobytes,
        showLarge: Bool = false
    ) async throws -> CommitDiff {
        guard GitObjectID.isValid(commit) else { throw RepositoryReadError.invalidQuery }
        let paths = [file.path] + (file.originalPath.map { [$0] } ?? [])
        let patch = try await runner.immutableRun(
            ["--literal-pathspecs"] + Self.logOptions + [
                "show", "--format=", "--root", "--diff-merges=first-parent", "--no-color",
                "--word-diff=none", "--no-ext-diff", "--no-textconv", "--full-index", "-M", "-C",
                "--src-prefix=a/", "--dst-prefix=b/", "--unified=3", commit, "--",
            ] + paths
        )
        let threshold = max(0, min(warningKilobytes, Int.max / 1000)) * 1000
        let binary = patch.range(of: Data("\nBinary files ".utf8)) != nil
        return CommitDiff(
            byteCount: patch.count,
            diff: patch.count <= threshold || showLarge || binary ? try RepositoryDiff(patch: patch) : nil
        )
    }

    /// 屏蔽用户配置中的签名、编码与根提交显示选项，保持协议稳定。
    private static let logOptions = [
        "-c", "log.showSignature=false", "-c", "i18n.logOutputEncoding=UTF-8",
        "-c", "log.date=default", "-c", "log.showRoot=true",
    ]
}

/// 对象参数只接受十六进制，长度由仓库算法决定。
enum GitObjectID {
    /// 拒绝空值、选项和修订表达式，允许 Git 支持的动态哈希长度。
    static func isValid(_ value: String) -> Bool {
        value.count >= 4 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}
