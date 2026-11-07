import Foundation

// MARK: - OperationStepKind

/// 序列中当前一步的动作，决定进度说明用 “应用” “编辑” 还是 “反转”。
public enum OperationStepKind: String, Sendable {
    /// 重放一个提交：变基的 pick、摘取。
    case applying

    /// 变基停在 edit 指令上。
    case editing

    /// 反转一个提交。
    case reverting
}

// MARK: - OperationProgress

/// 进行中操作的两侧、序列进度与已解决的冲突，全部取自 Git 的状态文件与索引。
public struct OperationProgress: Sendable, Equatable {
    /// 判断与横幅字段需要的状态文件，路径相对仓库的 Git 目录。
    static let stateFiles = [
        "MERGE_HEAD", "SQUASH_MSG", "CHERRY_PICK_HEAD", "REVERT_HEAD", "MERGE_MSG",
        "rebase-merge/head-name", "rebase-merge/onto", "rebase-merge/orig-head",
        "rebase-merge/msgnum", "rebase-merge/end", "rebase-merge/done", "rebase-merge/amend",
        "rebase-merge/stopped-sha", "rebase-merge/message", "rebase-merge/message-squash", "rebase-merge/message-fixup",
        "rebase-apply/head-name", "rebase-apply/onto", "rebase-apply/orig-head",
        "rebase-apply/next", "rebase-apply/last", "rebase-apply/final-commit",
        "sequencer/todo", "sequencer/head",
    ]

    /// 进行中的操作。
    public let state: RepositoryOperationState

    /// 我方提交：合并、摘取与反转是当前 HEAD，变基是被变基到的 onto。
    public let ours: String?

    /// 对方提交：合并是 MERGE_HEAD，摘取与反转是正在处理的提交，变基是原分支的 orig-head；压缩合并没有对方。
    public let theirs: String?

    /// 正在变基的分支的完整引用名；在分离 HEAD 上变基时为 nil。
    public let branch: String?

    /// 当前一步的序号，从 1 开始：变基取 Git 记录的步号；摘取与反转的序列不记录已完成的步数，正在处理的总是剩余中的第 1 个；单个提交的操作为 nil。
    public let step: Int?

    /// 总步数：变基是全部步数；摘取与反转的序列是 todo 里尚未完成的提交数，含正在处理的这一个；单个提交的操作为 nil。
    public let stepCount: Int?

    /// 当前一步的动作。
    public let stepKind: OperationStepKind?

    /// 当前一步处理的提交标题。
    public let stepSubject: String?

    /// 操作是序列，收尾时继续处理后面的步骤：变基总是序列；摘取与反转以 Git 是否建了 sequencer 为准，只剩一项的 sequencer 仍是序列。
    ///
    /// 只摘取或反转一个提交时 Git 不建 sequencer，按合并的方式提交收尾。
    public let isSequence: Bool

    /// 这次操作中已经标记解决的冲突文件，来自索引的 resolve-undo 记录。
    public internal(set) var resolvedPaths: Set<String> = []

    /// 交互式变基按 edit 指令停下时正在修改的提交；冲突、squash 与 fixup 造成的停顿为 nil。
    public internal(set) var editedCommit: String?

    /// 交互式变基尚未开始：merge 后端的变基既没有停在 edit 上，也没有停在某个提交上。
    ///
    /// 这时没有可以提交的一步，只能中止。
    public internal(set) var isPendingInteractive = false

    /// 交互式变基按 edit 指令停在这一步，等待修改后继续。
    public var stopsForEdit: Bool { editedCommit != nil }
}

extension OperationProgress {
    /// 由状态文件快照判断进行中的操作；判断顺序是变基、摘取或反转的序列、单个反转与摘取、合并、压缩合并。
    ///
    /// - Parameters:
    ///   - files: 相对 Git 目录的文件名与内容，不存在的文件不在其中。
    ///   - head: 当前 HEAD 提交；仓库还没有提交时为 nil。
    init?(files: [String: String], head: String?) {
        let value = { (name: String) -> String? in
            files[name].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        if let progress = Self.rebase(value) {
            self = progress
            return
        }

        if let progress = Self.sequence(value, head: head) {
            self = progress
            return
        }

        guard value("MERGE_HEAD") != nil || value("SQUASH_MSG") != nil else {
            return nil
        }

        // 章鱼合并的 MERGE_HEAD 有多行，横幅只显示第一个被合并的提交
        let merged = value("MERGE_HEAD").flatMap { $0.split(separator: "\n").first.map(String.init) }

        self.init(
            state: merged == nil ? .squash : .merge,
            ours: head,
            theirs: merged,
            branch: nil,
            step: nil,
            stepCount: nil,
            stepKind: nil,
            stepSubject: nil,
            isSequence: false
        )
    }

    /// 读取进行中操作的完整进度；已解决的冲突需要额外读取索引的 resolve-undo 记录。
    ///
    /// - Parameters:
    ///   - files: 相对 Git 目录的状态文件内容。
    ///   - head: 当前 HEAD 提交。
    ///   - runner: 读取索引的执行器。
    static func read(files: [String: String], head: String?, runner: GitRunner) async throws -> Self? {
        guard var progress = Self(files: files, head: head) else {
            return nil
        }

        progress.resolvedPaths = try parseResolveUndo(try await runner.run(["ls-files", "--resolve-undo", "-z"]))
        return progress
    }

    /// 解析 `ls-files --resolve-undo -z`：每条记录是 `<mode> <object> <stage>\t<path>`，同一路径按 stage 各一条。
    static func parseResolveUndo(_ output: Data) throws -> Set<String> {
        guard !output.isEmpty else {
            return []
        }

        guard output.last == 0 else {
            throw RepositoryReadError.malformedOutput("ls-files")
        }

        var paths: Set<String> = []

        for record in output.dropLast().split(separator: 0, omittingEmptySubsequences: false) {
            guard let tab = record.firstIndex(of: 9) else {
                throw RepositoryReadError.malformedOutput("ls-files")
            }

            let fields = String(decoding: record[..<tab], as: UTF8.self).split(separator: " ")
            let path = String(decoding: record[record.index(after: tab)...], as: UTF8.self)

            guard fields.count == 3, ["1", "2", "3"].contains(fields[2]), !path.isEmpty else {
                throw RepositoryReadError.malformedOutput("ls-files")
            }

            paths.insert(path)
        }

        return paths
    }
}

// MARK: - Prepared Message

extension OperationProgress {
    /// 提交区预填的信息：按 `SQUASH_MSG`、当前 fixup / squash 步的信息、`rebase-merge/message`、
    /// `rebase-apply/final-commit`、`MERGE_MSG` 的顺序取第一个存在的文件，注释行原样保留。
    ///
    /// - Parameter files: 同一次读取的状态文件快照。
    /// - Returns: 文件原文；都不存在时为 nil。
    static func preparedMessage(in files: [String: String]) -> String? {
        let current = files["rebase-merge/done"].flatMap { instructions($0).last?.command }

        // fixup 与 squash 各有自己的信息文件，按当前一步的指令选，不依次尝试两个文件
        let step: String? =
            switch current {
            case "fixup", "f": "rebase-merge/message-fixup"
            case "squash", "s": "rebase-merge/message-squash"
            default: nil
            }

        let names = [
            "SQUASH_MSG",
            step,
            "rebase-merge/message",
            "rebase-apply/final-commit",
            "MERGE_MSG",
        ]

        return names.lazy
            .compactMap { $0.flatMap { files[$0] } }
            .first
    }
}

// MARK: - State Files

extension WorkingCopyOperations {
    /// 读取 Git 目录中的状态文件：一次 rev-parse 定位，linked worktree 也正确，再批量读取，服务器上走 SFTP。
    ///
    /// - Parameter names: 相对 Git 目录的文件名。
    /// - Returns: 存在的文件名与按 UTF-8 解码的内容。
    func stateFiles(_ names: [String]) async throws -> [String: String] {
        let located = try await runner.run(["rev-parse", "--path-format=absolute"] + names.flatMap { ["--git-path", $0] })
        let paths = String(decoding: located, as: UTF8.self).split(separator: "\n").map(String.init)

        guard paths.count == names.count else {
            throw RepositoryFileError.unsupportedPath
        }

        let content = try await RepositoryFiles(runner: runner).read(paths)

        return Dictionary(uniqueKeysWithValues: zip(names, paths).compactMap { name, path in
            content[path].map { (name, String(decoding: $0, as: UTF8.self)) }
        })
    }
}

// MARK: - Private

extension OperationProgress {
    /// todo 或 done 里的一条指令。
    private struct Instruction {
        /// 指令的命令字，如 pick、revert、edit。
        let command: String

        /// 指令处理的提交；exec、label 这类不带提交的指令为 nil。
        let commit: String?

        /// 提交标题。
        let subject: String?
    }

    /// 变基：merge 后端看 rebase-merge，apply 后端看 rebase-apply。
    private static func rebase(_ value: (String) -> String?) -> Self? {
        let backend: String

        if value("rebase-merge/head-name") != nil {
            backend = "rebase-merge/"
        } else if value("rebase-apply/head-name") != nil {
            backend = "rebase-apply/"
        } else {
            return nil
        }

        let apply = backend == "rebase-apply/"
        let head = value(backend + "head-name")

        // merge 后端从 done 的最后一条取当前一步；apply 后端只有提交信息文件
        let current = value("rebase-merge/done").flatMap { instructions($0).last }
        let subject = apply
            ? value("rebase-apply/final-commit").flatMap { $0.split(separator: "\n").first.map(String.init) }
            : current?.subject

        // squash、fixup 停下时 Git 同样写 amend，只有最后一条是 edit 指令时才是停下来修改提交
        let stopsForEdit = !apply && ["edit", "e"].contains(current?.command ?? "")
        let edited = stopsForEdit ? value("rebase-merge/amend") : nil

        var progress = Self(
            state: .rebase,
            ours: value(backend + "onto"),
            theirs: value(backend + "orig-head"),
            branch: head.flatMap { $0.hasPrefix("refs/") ? $0 : nil },
            step: value(backend + (apply ? "next" : "msgnum")).flatMap { Int($0) },
            stepCount: value(backend + (apply ? "last" : "end")).flatMap { Int($0) },
            stepKind: edited == nil ? .applying : .editing,
            stepSubject: subject,
            isSequence: true
        )

        progress.editedCommit = edited

        // Git 每次停在某个提交上都会写 stopped-sha；还没有它就是还没开始处理任何提交
        progress.isPendingInteractive = !apply
            && edited == nil
            && value("rebase-merge/stopped-sha") == nil

        return progress
    }

    /// 摘取与反转：序列看 sequencer/todo 的第一条指令，单个提交看 CHERRY_PICK_HEAD、REVERT_HEAD。
    ///
    /// 序列只记录尚未完成的指令，不记录已完成的步数，所以总数是剩余的提交数，当前一步总是其中的第 1 个。
    private static func sequence(_ value: (String) -> String?, head: String?) -> Self? {
        let todo = value("sequencer/todo").map(instructions) ?? []
        let first = todo.first
        let reverting = first?.command == "revert" || (first == nil && value("REVERT_HEAD") != nil)
        let picking = ["pick", "p"].contains(first?.command ?? "") || (first == nil && value("CHERRY_PICK_HEAD") != nil)

        guard reverting || picking else {
            return nil
        }

        let current = value(reverting ? "REVERT_HEAD" : "CHERRY_PICK_HEAD") ?? first?.commit

        return Self(
            state: reverting ? .revert : .cherryPick,
            ours: head,
            theirs: current,
            branch: nil,
            step: todo.isEmpty ? nil : 1,
            stepCount: todo.isEmpty ? nil : todo.count,
            stepKind: reverting ? .reverting : .applying,
            stepSubject: first?.subject,
            isSequence: value("sequencer/todo") != nil || value("sequencer/head") != nil
        )
    }

    /// 解析 todo 或 done：跳过空行与注释行；标题前的 “# ” 是较新的 Git 写入的分隔。
    private static func instructions(_ content: String) -> [Instruction] {
        content.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                return nil
            }

            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            let commit = parts.count > 1 && GitObjectID.isValid(String(parts[1])) ? String(parts[1]) : nil
            let title = parts.count > 2 ? String(parts[2]) : nil
            let subject = title.map { $0.hasPrefix("# ") ? String($0.dropFirst(2)) : $0 }

            return Instruction(command: String(parts[0]), commit: commit, subject: commit == nil ? nil : subject)
        }
    }
}
