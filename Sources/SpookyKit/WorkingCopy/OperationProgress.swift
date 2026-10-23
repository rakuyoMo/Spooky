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
        "rebase-merge/msgnum", "rebase-merge/end", "rebase-merge/done",
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

    /// 序列中当前一步的序号，从 1 开始；单个提交的操作为 nil。
    public internal(set) var step: Int?

    /// 序列的总步数；单个提交的操作为 nil。
    public internal(set) var stepCount: Int?

    /// 当前一步的动作。
    public let stepKind: OperationStepKind?

    /// 当前一步处理的提交标题。
    public let stepSubject: String?

    /// 这次操作中已经标记解决的冲突文件，来自索引的 resolve-undo 记录。
    public internal(set) var resolvedPaths: Set<String> = []
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
            stepSubject: nil
        )
    }

    /// 读取进行中操作的完整进度；摘取与反转序列的步数、已解决的冲突需要额外的 Git 查询。
    ///
    /// - Parameters:
    ///   - files: 相对 Git 目录的状态文件内容。
    ///   - head: 当前 HEAD 提交。
    ///   - runner: 读取索引与提交计数的执行器。
    static func read(files: [String: String], head: String?, runner: GitRunner) async throws -> Self? {
        guard var progress = Self(files: files, head: head) else {
            return nil
        }

        // 摘取与反转的序列不记录已完成的步数：从序列开始时的 HEAD 数到当前 HEAD
        if
            let todo = files["sequencer/todo"],
            let start = files["sequencer/head"]?.trimmingCharacters(in: .whitespacesAndNewlines),
            let head,
            GitObjectID.isValid(start),
            [.cherryPick, .revert].contains(progress.state)
        {
            let output = try await runner.immutableRun(["rev-list", "--count", start + ".." + head])
            let remaining = Self.instructions(todo).count

            if let done = Int(String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)) {
                progress.step = done + 1
                progress.stepCount = done + remaining
            }
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

    /// 序列的这一步没有可提交的改动时，提交一个保留原信息的空提交再接着处理后面的步骤；须在写事务中执行。
    ///
    /// - Returns: 是否已经处理；这一步有改动时返回 false，交给 Git 自己的继续命令。
    func commitEmptyStep(of operation: RepositoryOperationState) async throws -> Bool {
        guard [.rebase, .cherryPick, .revert].contains(operation) else {
            return false
        }

        // 暂存区与 HEAD 相同，这一步就没有可提交的改动
        let changes = try await runner.execute(["diff", "--cached", "--quiet", "HEAD", "--"], acceptedExitCodes: [0, 1])

        guard changes.exitCode == 0 else {
            return false
        }

        let files = try await stateFiles(["rebase-merge/stopped-sha", "rebase-apply/original-commit", "sequencer/todo"])
        let commit = [
            "-c", "i18n.commitencoding=UTF-8", "-c", "commit.verbose=false",
            "commit", "--allow-empty", "--no-verify", "-q",
        ]
        let editor = ["-c", "core.editor=:", "-c", "core.trustctime=false"]

        if operation == .rebase {
            // 停下的提交提供原作者与信息；apply 后端提交后要跳过这一步，merge 后端直接继续
            let applying = files["rebase-apply/original-commit"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let stopped = files["rebase-merge/stopped-sha"]?.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let current = stopped ?? applying, GitObjectID.isValid(current) else {
                return false
            }

            _ = try await runner.run(commit + ["-C", current])
            _ = try await runner.run(editor + ["rebase", applying == nil ? "--continue" : "--skip"])
            return true
        }

        // 摘取与反转沿用 Git 准备的 MERGE_MSG 并去掉注释行，摘取保留原作者；单个提交的操作到此结束
        _ = try await runner.run(commit + ["--no-edit", "--cleanup=strip"])

        if files["sequencer/todo"] != nil {
            _ = try await runner.run(editor + [operation == .revert ? "revert" : "cherry-pick", "--continue"])
        }

        return true
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

        return Self(
            state: .rebase,
            ours: value(backend + "onto"),
            theirs: value(backend + "orig-head"),
            branch: head.flatMap { $0.hasPrefix("refs/") ? $0 : nil },
            step: value(backend + (apply ? "next" : "msgnum")).flatMap { Int($0) },
            stepCount: value(backend + (apply ? "last" : "end")).flatMap { Int($0) },
            stepKind: ["edit", "e"].contains(current?.command ?? "") ? .editing : .applying,
            stepSubject: subject
        )
    }

    /// 摘取与反转：序列看 sequencer/todo 的第一条指令，单个提交看 CHERRY_PICK_HEAD、REVERT_HEAD。
    private static func sequence(_ value: (String) -> String?, head: String?) -> Self? {
        let first = value("sequencer/todo").flatMap { instructions($0).first }
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
            step: nil,
            stepCount: nil,
            stepKind: reverting ? .reverting : .applying,
            stepSubject: first?.subject
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
