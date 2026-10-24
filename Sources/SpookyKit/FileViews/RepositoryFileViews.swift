import Foundation

// MARK: - TreeEntry

/// 某个版本的树中的一个文件条目：普通文件、可执行文件、符号链接或子模块。
public struct TreeEntry: Sendable, Equatable {
    /// 六位八进制模式，如 `100644`、`120000`、`160000`。
    public let mode: String

    /// 对象类型：文件为 `blob`，子模块为 `commit`。
    public let type: String

    /// 对象哈希，长度随仓库的哈希算法变化。
    public let objectID: String

    /// 仓库内的相对路径，保留树中存储的 Unicode 形式。
    public let path: String

    /// 子模块条目没有可读取的文件内容。
    public var isSubmodule: Bool { type == "commit" }

    /// 解析 `ls-tree -z` 的输出：每条记录形如 “模式 类型 哈希\t路径”，以 NUL 结尾。
    static func parse(_ data: Data) throws -> [Self] {
        guard !data.isEmpty else {
            return []
        }

        guard data.last == 0 else {
            throw RepositoryReadError.malformedOutput("ls-tree")
        }

        return try data.dropLast().split(separator: 0, omittingEmptySubsequences: false).map { record in
            // 路径本身可以含有制表符，只在第一个制表符处切开头部与路径
            guard let tab = record.firstIndex(of: 9) else {
                throw RepositoryReadError.malformedOutput("ls-tree")
            }

            let header = String(decoding: record[record.startIndex ..< tab], as: UTF8.self)
                .split(separator: " ", omittingEmptySubsequences: false)
                .map(String.init)
            let path = String(decoding: record[record.index(after: tab)...], as: UTF8.self)

            guard
                header.count == 3,
                header[0].count == 6,
                header[0].allSatisfy({ "01234567".contains($0) }),
                ["blob", "commit"].contains(header[1]),
                GitObjectID.isValid(header[2]),
                !path.isEmpty
            else { throw RepositoryReadError.malformedOutput("ls-tree") }

            return Self(mode: header[0], type: header[1], objectID: header[2], path: path)
        }
    }
}

// MARK: - FileHistoryFilter

/// 文件历史的筛选条件：搜索框按范围匹配作者、提交人或版本；空条件表示全部历史。
public struct FileHistoryFilter: Sendable, Equatable {
    /// 搜索框的匹配范围。
    public enum Scope: String, Sendable, CaseIterable {
        /// 作者的姓名或邮箱，忽略大小写的字面匹配。
        case author

        /// 提交人的姓名或邮箱，忽略大小写的字面匹配。
        case committer

        /// 版本表达式，只显示该版本上最近一次修改此文件的提交。
        case revision
    }

    /// 搜索框的匹配范围。
    public var scope: Scope

    /// 搜索框的内容，首尾空白不参与匹配。
    public var text: String

    /// 去掉首尾空白后的搜索内容。
    public var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 交给 log 与 rev-list 的限定参数；版本范围改变的是起点，不在这里表达。
    var arguments: [String] {
        // 贡献者按字面子串匹配并忽略大小写，输入中的正则符号不会被解释
        guard !trimmedText.isEmpty, scope != .revision else {
            return []
        }

        return ["-i", "-F", (scope == .author ? "--author=" : "--committer=") + trimmedText]
    }

    /// 创建筛选条件，默认不过滤。
    public init(scope: Scope = .author, text: String = "") {
        self.scope = scope
        self.text = text
    }
}

// MARK: - FileContributor

/// 某个文件或整个仓库的一位作者及其提交数。
public struct FileContributor: Sendable, Equatable {
    /// 作者姓名，经过仓库的 `.mailmap` 合并。
    public let name: String

    /// 作者邮箱。
    public let email: String

    /// 这位作者的提交数。
    public let commitCount: Int

    /// 解析 `shortlog -s -e` 的输出：每行形如 “提交数\t姓名 <邮箱>”。
    static func parse(_ data: Data) throws -> [Self] {
        try String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .map { line in
                let fields = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)

                // 邮箱总在行尾的尖括号里，姓名本身可以含有尖括号以外的任意字符
                guard
                    fields.count == 2,
                    let count = Int(fields[0].trimmingCharacters(in: .whitespaces)),
                    fields[1].hasSuffix(">"),
                    let open = fields[1].range(of: " <", options: .backwards)
                else { throw RepositoryReadError.malformedOutput("shortlog") }

                return Self(
                    name: String(fields[1][..<open.lowerBound]),
                    email: String(fields[1][open.upperBound...].dropLast()),
                    commitCount: count
                )
            }
    }
}

// MARK: - RepositoryFileViews

/// 文件历史、Blame 与原文的只读查询，都在仓库所在的机器上执行 Git。
///
/// 路径按树中存储的 Unicode 形式传给 Git；只由对象哈希决定的结果按哈希复用。
public struct RepositoryFileViews: Sendable {
    /// 路径按字面匹配，并关闭 macOS 上把命令行参数转成 NFC 的处理：树中以 NFD 存储的路径只能按原样命中。
    ///
    /// 这些查询只读取对象库，不受工作区文件名的 Unicode 形式影响。
    static let storedPathOptions = ["--literal-pathspecs", "-c", "core.precomposeunicode=false"]

    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 创建只读查询服务，不立即访问仓库。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 文件历史里一个文件在某个提交中的改动；不跨重命名追踪，原路径为空。
    public static func change(of path: String) -> CommitFileChange {
        CommitFileChange(
            path: path,
            originalPath: nil,
            status: "M",
            additions: nil,
            deletions: nil
        )
    }

    /// 读取修改过该文件的一页提交，从指定提交开始向前；不跨越重命名追踪。
    ///
    /// - Parameters:
    ///   - path: 树中存储的相对路径。
    ///   - revision: 起点提交的完整哈希，固定起点使翻页结果不随新提交变化。
    ///   - filter: 贡献者条件；版本范围由调用方解析成起点。
    public func page(
        of path: String,
        from revision: String,
        filter: FileHistoryFilter = FileHistoryFilter(),
        offset: Int = 0,
        limit: Int = 100
    ) async throws -> HistoryPage {
        guard offset >= 0, (1 ... 1000).contains(limit), GitObjectID.isValid(revision), !path.isEmpty else {
            throw RepositoryReadError.invalidQuery
        }

        // 多取一条判断是否还有下一页；起点与条件都是固定值，结果可以按参数复用
        let output = try await runner.immutableRun(
            Self.storedPathOptions + RepositoryHistory.logOptions + [
                "log", "--no-color", "--no-decorate", "--no-patch", "-z", HistoryCommit.format,
                "--max-count=\(limit + 1)", "--skip=\(offset)",
            ]
                + filter.arguments
                + [revision, "--", path]
        )
        let commits = try HistoryCommit.parse(output)

        return HistoryPage(commits: Array(commits.prefix(limit)), hasMore: commits.count > limit)
    }

    /// 符合条件的提交总数，用于时间线头部的计数。
    public func count(
        of path: String,
        from revision: String,
        filter: FileHistoryFilter = FileHistoryFilter()
    ) async throws -> Int {
        guard GitObjectID.isValid(revision), !path.isEmpty else {
            throw RepositoryReadError.invalidQuery
        }

        let output = try await runner.immutableRun(
            Self.storedPathOptions + ["rev-list", "--count"] + filter.arguments + [revision, "--", path]
        )

        let text = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard let count = Int(text) else {
            throw RepositoryReadError.malformedOutput("rev-list")
        }

        return count
    }

    /// 指定版本中该路径的条目；版本中没有这个文件时为 nil。
    public func entry(at path: String, in revision: String) async throws -> TreeEntry? {
        guard GitObjectID.isValid(revision), !path.isEmpty else {
            throw RepositoryReadError.invalidQuery
        }

        // 带完整路径的 ls-tree 只返回这一项，不必列出整棵树
        let output = try await runner.immutableRun(
            Self.storedPathOptions + ["ls-tree", "-z", "--full-tree", revision, "--", path]
        )

        return try TreeEntry.parse(output).first { Array($0.path.utf8) == Array(path.utf8) }
    }

    /// 指定版本中的全部文件与子模块，供文件选择器使用。
    public func files(in revision: String) async throws -> [TreeEntry] {
        guard GitObjectID.isValid(revision) else {
            throw RepositoryReadError.invalidQuery
        }

        let output = try await runner.immutableRun(["ls-tree", "-r", "-z", "--full-tree", revision])

        return try TreeEntry.parse(output)
    }

    /// 按 Unicode 等价查找版本中的条目：工作区与树中同一文件名可能分别是 NFC 与 NFD。
    ///
    /// 先按原样查找；找不到时列出整棵树，取规范等价的路径，返回的条目带有树中存储的形式。
    public func storedEntry(for path: String, in revision: String) async throws -> TreeEntry? {
        if let entry = try await entry(at: path, in: revision) {
            return entry
        }

        // Swift 的字符串比较按规范等价进行，NFC 与 NFD 的同名路径视为相等
        return try await files(in: revision).first { $0.path == path }
    }

    /// 文件条目的原始内容；子模块没有文件内容。
    public func contents(of entry: TreeEntry) async throws -> Data {
        guard !entry.isSubmodule else {
            throw RepositoryReadError.invalidQuery
        }

        return try await runner.immutableRun(["cat-file", "blob", entry.objectID])
    }

    /// 指定版本中逐行追溯到引入它的提交。
    ///
    /// 忽略用户配置的跳过版本列表；作者姓名随工作区的 `.mailmap` 合并，结果不按哈希复用。
    public func blame(_ path: String, at revision: String) async throws -> FileBlame {
        guard GitObjectID.isValid(revision), !path.isEmpty else {
            throw RepositoryReadError.invalidQuery
        }

        let output = try await runner.run(
            Self.storedPathOptions + [
                "-c", "blame.ignoreRevsFile=", "blame", "--porcelain", revision, "--", path,
            ]
        )

        return try FileBlame.parse(output)
    }

    /// 指定提交之前修改过该文件的作者，按提交数从多到少排列。
    ///
    /// - Parameters:
    ///   - path: 树中存储的路径；nil 表示整个仓库的作者，供文件历史的搜索框补全。
    ///   - revision: 起点提交的完整哈希。
    public func contributors(of path: String?, at revision: String) async throws -> [FileContributor] {
        guard GitObjectID.isValid(revision), path.map({ !$0.isEmpty }) ?? true else {
            throw RepositoryReadError.invalidQuery
        }

        // shortlog 没有起点时会改读标准输入，起点必须显式给出；作者随 `.mailmap` 合并，结果不按哈希复用
        let output = try await runner.run(
            Self.storedPathOptions + RepositoryHistory.logOptions
                + ["shortlog", "-n", "-s", "-e", revision]
                + (path.map { ["--", $0] } ?? [])
        )

        return try FileContributor.parse(output)
    }

    /// 该文件在指定提交中的补丁，与第一父提交比较。
    ///
    /// - Parameters:
    ///   - path: 树中存储的路径。
    ///   - commit: 提交哈希。
    ///   - options: 上下文行数、显示整个文件与忽略空白。
    ///   - warningKilobytes: 大 Diff 警告阈值，超过时不解析。
    ///   - showLarge: 是否放行超过阈值的补丁。
    public func diff(
        of path: String,
        in commit: String,
        options: DiffOptions = DiffOptions(),
        warningKilobytes: Int = WorkingCopyOperations.defaultWarningKilobytes,
        showLarge: Bool = false
    ) async throws -> CommitDiff {
        try await RepositoryHistory(runner: runner).diff(
            in: commit,
            file: Self.change(of: path),
            options: options,
            warningKilobytes: warningKilobytes,
            showLarge: showLarge
        )
    }
}
