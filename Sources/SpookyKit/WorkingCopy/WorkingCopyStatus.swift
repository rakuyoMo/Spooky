import Foundation

// MARK: - WorkingCopyStatus

/// 工作区状态：当前分支的信息，加上所有有变化的文件
public struct WorkingCopyStatus: Sendable, Equatable {
    /// 当前分支
    public var branch: BranchStatus

    /// 有变化的文件，顺序与 git 的输出一致
    public var entries: [StatusEntry]
}

// MARK: - BranchStatus

/// `git status --branch` 给出的分支信息
public struct BranchStatus: Sendable, Equatable {
    /// 当前分支名；分离 HEAD 时为 nil
    public var head: String?

    /// HEAD 指向的提交；仓库还没有任何提交时为 nil
    public var oid: String?

    /// 上游分支，如 `origin/main`；没有设置上游时为 nil
    public var upstream: String?

    /// 领先上游的提交数
    public var ahead = 0

    /// 落后上游的提交数
    public var behind = 0
}

// MARK: - FileChange

/// 文件的一种变化：暂存区相对 HEAD，或工作区相对暂存区
public enum FileChange: Character, Sendable {
    case modified = "M"
    case typeChanged = "T"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case unmerged = "U"
}

// MARK: - StatusEntry

/// 一个有变化的文件
public struct StatusEntry: Sendable, Equatable {
    /// 条目的类别
    public enum Kind: Sendable, Hashable {
        /// 已跟踪的文件，包括重命名与复制
        case tracked

        /// 处于合并冲突中的文件
        case conflicted

        /// 未跟踪的文件
        case untracked

        /// 被忽略的文件
        case ignored
    }

    /// 条目的类别
    public var kind: Kind

    /// 文件路径，相对仓库根目录
    public var path: String

    /// 重命名或复制之前的路径
    public var originalPath: String?

    /// 暂存区里的变化；没有变化时为 nil
    public var staged: FileChange?

    /// 工作区里尚未暂存的变化；没有变化时为 nil
    public var unstaged: FileChange?

    /// 冲突文件在索引中的三方版本；不是冲突时为 nil
    public var conflict: ConflictStages? = nil
}

// MARK: - StatusParseError

/// git status 的输出不符合 porcelain v2 格式
public struct StatusParseError: Error, Sendable, Equatable {
    /// 无法解析的那条记录
    public let record: String
}

extension GitRunner {
    /// 读取工作区状态，未跟踪的文件逐个列出，不折叠成目录
    public func status() async throws -> WorkingCopyStatus {
        let output = try await run([
            "status",
            "--porcelain=v2",
            "-z",
            "--branch",
            "--untracked-files=all",
        ])

        return try WorkingCopyStatus(porcelainV2: output)
    }
}

extension WorkingCopyStatus {
    /// 解析 `git status --porcelain=v2 -z --branch` 的输出
    ///
    /// 格式见 git-status(1) 的 “Porcelain Format Version 2” 一节。
    public init(porcelainV2 output: Data) throws {
        var branch = BranchStatus()
        var entries: [StatusEntry] = []

        // 截断的记录不能作为有效快照展示，否则刷新失败会被误认为文件已消失。
        guard output.isEmpty || output.last == 0 else {
            throw StatusParseError(record: String(decoding: output, as: UTF8.self))
        }

        // -z 模式下每条记录以 NUL 结尾；重命名、复制记录的后面紧跟一条 “原路径” 记录
        let terminatedRecords = output.isEmpty
            ? []
            : output
                .dropLast()
                .split(separator: 0, omittingEmptySubsequences: false)
                .map { String(decoding: $0, as: UTF8.self) }
        var records = terminatedRecords.makeIterator()

        while let record = records.next() {
            switch record.first {
            case "#":
                try branch.apply(header: record)

            case "1":
                entries.append(try StatusEntry(ordinary: record))

            case "2":
                guard let originalPath = records.next(), !originalPath.isEmpty else {
                    throw StatusParseError(record: record)
                }

                entries.append(try StatusEntry(renamedOrCopied: record, originalPath: originalPath))

            case "u":
                entries.append(try StatusEntry(unmerged: record))

            case "?":
                entries.append(try StatusEntry(kind: .untracked, record: record))

            case "!":
                entries.append(try StatusEntry(kind: .ignored, record: record))

            default:
                throw StatusParseError(record: record)
            }
        }

        self.init(branch: branch, entries: entries)
    }
}

extension BranchStatus {
    /// 吸收一条 `# branch.*` 头信息；不认识的头（如 `# stash`）直接忽略
    fileprivate mutating func apply(header record: String) throws {
        let parts = record.split(separator: " ", maxSplits: 2)

        guard parts.count >= 2 else {
            throw StatusParseError(record: record)
        }

        // porcelain 允许增加新的头字段；只严格验证当前使用的分支字段。
        guard ["branch.oid", "branch.head", "branch.upstream", "branch.ab"].contains(parts[1]) else {
            return
        }

        guard parts.count == 3 else {
            throw StatusParseError(record: record)
        }

        let value = String(parts[2])

        switch parts[1] {
        case "branch.oid":
            guard value == "(initial)" || value.allSatisfy(\.isHexDigit) else {
                throw StatusParseError(record: record)
            }

            oid = value == "(initial)" ? nil : value

        case "branch.head":
            head = value == "(detached)" ? nil : value

        case "branch.upstream":
            upstream = value

        case "branch.ab":

            // 形如 `+3 -1`：领先 3 个、落后 1 个
            let counts = value.split(separator: " ")

            guard
                counts.count == 2,
                counts[0].first == "+",
                counts[1].first == "-",
                let ahead = Int(counts[0].dropFirst()),
                let behind = Int(counts[1].dropFirst()),
                ahead >= 0,
                behind >= 0
            else {
                throw StatusParseError(record: record)
            }

            self.ahead = ahead
            self.behind = behind

        default:
            break
        }
    }
}

extension StatusEntry {
    /// 只有类别与路径的条目：未跟踪或被忽略的文件
    fileprivate init(kind: Kind, record: String) throws {
        guard record.count > 2, record.dropFirst().first == " " else {
            throw StatusParseError(record: record)
        }

        self.init(
            kind: kind,
            path: String(record.dropFirst(2)),
            originalPath: nil,
            staged: nil,
            unstaged: nil
        )
    }

    /// 普通变化：`1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>`
    fileprivate init(ordinary record: String) throws {
        let fields = try Self.fields(of: record, count: 9)
        let changes = try Self.changes(fields[1], in: record)

        self.init(
            kind: .tracked,
            path: fields[8],
            originalPath: nil,
            staged: changes.staged,
            unstaged: changes.unstaged
        )
    }

    /// 重命名或复制：`2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X><score> <path>`，原路径在下一条记录里
    fileprivate init(renamedOrCopied record: String, originalPath: String) throws {
        let fields = try Self.fields(of: record, count: 10)
        let changes = try Self.changes(fields[1], in: record)

        self.init(
            kind: .tracked,
            path: fields[9],
            originalPath: originalPath,
            staged: changes.staged,
            unstaged: changes.unstaged
        )
    }

    /// 合并冲突：`u <XY> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>`
    fileprivate init(unmerged record: String) throws {
        let fields = try Self.fields(of: record, count: 11)
        let changes = try Self.changes(fields[1], in: record)

        self.init(
            kind: .conflicted,
            path: fields[10],
            originalPath: nil,
            staged: changes.staged,
            unstaged: changes.unstaged,
            conflict: try ConflictStages(unmerged: fields, record: record)
        )
    }

    /// 按空格切出固定个数的字段；路径在最后一个字段，里面的空格原样保留
    private static func fields(of record: String, count: Int) throws -> [String] {
        let fields = record
            .split(separator: " ", maxSplits: count - 1, omittingEmptySubsequences: false)
            .map(String.init)

        guard fields.count == count, fields.allSatisfy({ !$0.isEmpty }) else {
            throw StatusParseError(record: record)
        }

        return fields
    }

    /// 解析 XY 两个字符：X 是暂存区的变化，Y 是工作区的变化，`.` 表示没有变化
    private static func changes(
        _ xy: String,
        in record: String
    ) throws -> (staged: FileChange?, unstaged: FileChange?) {
        guard
            xy.count == 2,
            let x = xy.first,
            let y = xy.last
        else {
            throw StatusParseError(record: record)
        }

        // 不是 `.`、又不在已知字母里的，说明格式不对
        func change(_ code: Character) throws -> FileChange? {
            if code == "." {
                return nil
            }

            guard let change = FileChange(rawValue: code) else {
                throw StatusParseError(record: record)
            }

            return change
        }

        return (try change(x), try change(y))
    }
}
