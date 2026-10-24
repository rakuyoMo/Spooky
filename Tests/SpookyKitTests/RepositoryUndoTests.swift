import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositoryUndoTests

/// 撤销与重做的状态记录和恢复：每种写操作做完后先恢复成操作前、再恢复成操作后，两次都与记录完全一致。
struct RepositoryUndoTests {
    /// 有代表性的写操作；`clean` 的操作要求工作区与索引没有改动，其余在带本地改动的仓库上执行。
    enum Operation: String, CaseIterable, Sendable {
        case commit, createBranch, deleteBranch, checkout, merge, rebase, reset
        case stashSave, stashSaveUntracked, stashApply, stashPop
        case createTag, deleteTag, cherryPick, revert, stage, stageUntracked, unstage, discard
        case createTrackingBranch, renameBranch, setUpstream, pinBranch, createAndCheckout, renameCurrentBranch

        /// Git 要求干净工作区的操作。
        var clean: Bool {
            [.merge, .rebase, .cherryPick, .revert].contains(self)
        }
    }

    /// 撤销回到操作前的引用、HEAD、储藏、索引与工作区，重做再回到操作后，两次都与记录相同。
    @Test("撤销与重做恢复记录的状态", arguments: Operation.allCases)
    func roundTrip(_ operation: Operation) async throws {
        let repository = try await makeRepository(dirty: !operation.clean)
        defer { repository.remove() }
        let undo = RepositoryUndo(runner: repository.runner)

        // 应用储藏要先有一个储藏
        if [.stashApply, .stashPop].contains(operation) {
            _ = try await repository.runner.run(["stash", "push", "-q"])
        }

        let before = try await undo.capture()
        try await perform(operation, in: repository)
        let after = try await undo.capture()
        #expect(before != after)

        try await undo.restore(before, expecting: after, message: "undo")
        #expect(try await undo.capture() == before)

        try await undo.restore(after, expecting: before, message: "redo")
        #expect(try await undo.capture() == after)
    }

    /// 撤销硬重置找回被丢掉的暂存与未暂存改动，文件内容逐字节回到原样。
    @Test("撤销硬重置找回本地改动")
    func undoHardReset() async throws {
        let repository = try await makeRepository(dirty: true)
        defer { repository.remove() }
        let undo = RepositoryUndo(runner: repository.runner)

        let before = try await undo.capture()
        _ = try await repository.runner.run(["reset", "-q", "--hard", "HEAD~1"])
        let after = try await undo.capture()
        try await undo.restore(before, expecting: after, message: "undo")

        #expect(try read("tracked *.txt", in: repository) == "staged\n")
        #expect(try read("dir/文件.txt", in: repository) == "unstaged\n")
        #expect(try read("new [1].txt", in: repository) == "untracked\n")
    }

    /// 带未跟踪文件保存的储藏：撤销时从储藏里写回被删掉的未跟踪文件，并从列表里拿掉这个储藏。
    @Test("撤销带未跟踪文件的储藏")
    func undoStashWithUntracked() async throws {
        let repository = try await makeRepository(dirty: true)
        defer { repository.remove() }
        let undo = RepositoryUndo(runner: repository.runner)

        let before = try await undo.capture()
        _ = try await repository.runner.run(["stash", "push", "-q", "-u"])
        let after = try await undo.capture()
        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: "new [1].txt").path))
        #expect(after.stashes.first?.untracked != nil)

        try await undo.restore(before, expecting: after, message: "undo")
        #expect(try read("new [1].txt", in: repository) == "untracked\n")
        #expect(try await undo.capture().stashes.isEmpty)
    }

    /// 丢弃未跟踪文件后找不回它的内容，不能撤销；只丢弃已跟踪文件的改动可以撤销。
    @Test("删掉的未跟踪文件不能恢复")
    func untrackedDeletion() async throws {
        let repository = try await makeRepository(dirty: true)
        defer { repository.remove() }
        let undo = RepositoryUndo(runner: repository.runner)

        let before = try await undo.capture()
        try FileManager.default.removeItem(at: repository.directory.appending(path: "new [1].txt"))
        let after = try await undo.capture()

        #expect(try await !undo.canRestore(before, from: after))

        await #expect(throws: RepositoryUndoError.untrackedFiles) {
            try await undo.restore(before, expecting: after, message: "undo")
        }
    }

    /// 操作之后仓库又被改动：恢复前的核对不通过，仓库保持原样。
    @Test("仓库在操作后又被改动时拒绝恢复")
    func changedRepository() async throws {
        let repository = try await makeRepository(dirty: true)
        defer { repository.remove() }
        let undo = RepositoryUndo(runner: repository.runner)

        let before = try await undo.capture()
        _ = try await repository.runner.run(["commit", "-q", "-m", "next"])
        let after = try await undo.capture()

        // 已经修改过的文件再改一次，git status 看起来不变，内容核对能发现
        try write("unstaged again\n", to: "dir/文件.txt", in: repository)
        await #expect(throws: RepositoryUndoError.repositoryChanged) {
            try await undo.restore(before, expecting: after, message: "undo")
        }

        #expect(try await undo.capture().head == after.head)
        #expect(try read("dir/文件.txt", in: repository) == "unstaged again\n")
    }

    /// 合并停在冲突上时状态不能记录：既有进行中的合并，也有写不出树的冲突。
    @Test("进行中的操作不能记录")
    func operationInProgress() async throws {
        let repository = try await makeRepository(dirty: false)
        defer { repository.remove() }
        let runner = repository.runner

        try write("main side\n", to: "other.txt", in: repository)
        _ = try await runner.run(["commit", "-q", "-a", "-m", "main side"])
        _ = try await runner.execute(["merge", "-q", "feature"], acceptedExitCodes: [0, 1])

        await #expect(throws: RepositoryUndoError.operationInProgress) {
            try await RepositoryUndo(runner: runner).capture()
        }

        // 没有进行中的操作、只剩冲突时同样拒绝
        for name in ["MERGE_HEAD", "MERGE_MSG", "MERGE_MODE"] {
            try? FileManager.default.removeItem(at: repository.directory.appending(path: ".git/" + name))
        }

        await #expect(throws: RepositoryUndoError.unresolvedConflicts) {
            try await RepositoryUndo(runner: runner).capture()
        }
    }

    /// 撤销会把文件写回磁盘，那里的未跟踪文件已改成别的内容时拒绝，不覆盖用户的内容；改回原样后可以撤销。
    @Test("不覆盖内容不同的未跟踪文件")
    func untrackedOverwrite() async throws {
        let repository = try await makeRepository(dirty: false)
        defer { repository.remove() }
        let runner = repository.runner
        let undo = RepositoryUndo(runner: runner)

        // 最近一次提交新增的文件在混合重置后变成未跟踪文件，快照里没有它的内容
        try write("added\n", to: "added [x].txt", in: repository)
        _ = try await runner.run(["--literal-pathspecs", "add", "--", "added [x].txt"])
        _ = try await runner.run(["commit", "-q", "-m", "add"])

        let before = try await undo.capture()
        _ = try await runner.run(["reset", "-q", "HEAD~1"])
        let after = try await undo.capture()

        try write("edited while untracked\n", to: "added [x].txt", in: repository)
        await #expect(throws: RepositoryUndoError.untrackedFiles) {
            try await undo.restore(before, expecting: after, message: "undo")
        }

        #expect(try read("added [x].txt", in: repository) == "edited while untracked\n")

        try write("added\n", to: "added [x].txt", in: repository)
        try await undo.restore(before, expecting: after, message: "undo")
        #expect(try await undo.capture() == before)
    }

    /// 标为 assume-unchanged 的文件有快照看不到的改动时拒绝恢复，改动保留。
    @Test("assume-unchanged 文件的改动不会被覆盖")
    func hiddenChanges() async throws {
        let repository = try await makeRepository(dirty: false)
        defer { repository.remove() }
        let runner = repository.runner
        let undo = RepositoryUndo(runner: runner)

        _ = try await runner.run(["update-index", "--assume-unchanged", "--", "other.txt"])
        try write("hidden\n", to: "other.txt", in: repository)

        let before = try await undo.capture()
        _ = try await runner.run(["branch", "topic"])
        let after = try await undo.capture()

        await #expect(throws: RepositoryUndoError.hiddenChanges) {
            try await undo.restore(before, expecting: after, message: "undo")
        }

        #expect(try read("other.txt", in: repository) == "hidden\n")
    }

    /// SHA-256 仓库：哈希长度不同，提交与带未跟踪文件的储藏同样能撤销和重做。
    @Test("SHA-256 仓库的撤销与重做")
    func sha256() async throws {
        let repository = try await makeRepository(dirty: true, objectFormat: "sha256")
        defer { repository.remove() }
        let undo = RepositoryUndo(runner: repository.runner)

        for operation in [Operation.commit, .stashSaveUntracked] {
            let before = try await undo.capture()
            try await perform(operation, in: repository)
            let after = try await undo.capture()
            #expect(after.index.count == 64)

            try await undo.restore(before, expecting: after, message: "undo")
            #expect(try await undo.capture() == before)
        }
    }
}

// MARK: - Helpers

extension RepositoryUndoTests {
    /// 主分支两个提交与一个附注标签，`feature` 分支改了另一个文件；脏仓库另有暂存、未暂存与未跟踪的改动。
    ///
    /// 路径带空格、通配符、方括号与中文。
    func makeRepository(dirty: Bool, objectFormat: String = "sha1") async throws -> TemporaryRepository {
        let repository = try TemporaryRepository()
        try await repository.initialize(objectFormat: objectFormat)
        let runner = repository.runner

        try FileManager.default.createDirectory(
            at: repository.directory.appending(path: "dir"),
            withIntermediateDirectories: true
        )
        try write("base\n", to: "tracked *.txt", in: repository)
        try write("base\n", to: "dir/文件.txt", in: repository)
        try write("base\n", to: "other.txt", in: repository)
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])
        _ = try await runner.run(["tag", "-a", "v0", "-m", "第一个标签"])

        try write("second\n", to: "tracked *.txt", in: repository)
        _ = try await runner.run(["commit", "-q", "-a", "-m", "second"])

        _ = try await runner.run(["checkout", "-q", "-b", "feature"])
        try write("feature\n", to: "other.txt", in: repository)
        _ = try await runner.run(["commit", "-q", "-a", "-m", "feature"])
        _ = try await runner.run(["checkout", "-q", "main"])

        // 分支段里的附加信息随删除、改名一起变化，撤销时同样恢复
        _ = try await runner.run(["config", "--local", "branch.feature.spooky-parent", "refs/heads/main"])

        if dirty {
            try write("staged\n", to: "tracked *.txt", in: repository)
            _ = try await runner.run(["--literal-pathspecs", "add", "--", "tracked *.txt"])
            try write("unstaged\n", to: "dir/文件.txt", in: repository)
            try write("untracked\n", to: "new [1].txt", in: repository)
        }

        return repository
    }

    /// 用 Git 命令完成一种写操作。
    func perform(_ operation: Operation, in repository: TemporaryRepository) async throws {
        let literal = ["--literal-pathspecs"]
        let commands: [Operation: [String]] = [
            .commit: ["commit", "-q", "-m", "提交 \"quoted\""],
            .createBranch: ["branch", "功能/新分支"],
            .deleteBranch: ["branch", "-q", "-D", "feature"],
            .checkout: ["checkout", "-q", "feature"],
            .merge: ["merge", "-q", "--no-ff", "-m", "merge", "feature"],
            .rebase: ["rebase", "-q", "feature"],
            .reset: ["reset", "-q", "--hard", "HEAD~1"],
            .stashSave: ["stash", "push", "-q", "-m", "说明 [x]"],
            .stashSaveUntracked: ["stash", "push", "-q", "-u"],
            .stashApply: ["stash", "apply", "-q", "--index"],
            .stashPop: ["stash", "pop", "-q", "--index"],
            .createTag: ["tag", "-a", "v1", "-m", "标签 *"],
            .deleteTag: ["tag", "-d", "v0"],
            .cherryPick: ["cherry-pick", "feature"],
            .revert: ["revert", "--no-edit", "HEAD"],
            .stage: literal + ["add", "--", "dir/文件.txt"],
            .stageUntracked: literal + ["add", "--", "new [1].txt"],
            .unstage: literal + ["reset", "-q", "--", "tracked *.txt"],
            .discard: literal + ["checkout", "-q", "--", "dir/文件.txt"],
            .createTrackingBranch: ["branch", "-q", "--track", "功能/跟踪", "feature"],
            .renameBranch: ["branch", "-m", "feature", "功能/改名"],
            .setUpstream: ["branch", "-q", "--set-upstream-to=feature", "main"],
            .pinBranch: ["config", "--local", "branch.feature.spooky-pinned", "true"],
            .createAndCheckout: ["checkout", "-q", "-b", "功能/新"],
            .renameCurrentBranch: ["branch", "-m", "main", "主干"],
        ]

        let arguments = try #require(commands[operation])
        _ = try await repository.runner.run(arguments)
    }

    /// 写入仓库内的文件。
    func write(_ content: String, to path: String, in repository: TemporaryRepository) throws {
        try Data(content.utf8).write(to: repository.directory.appending(path: path))
    }

    /// 读取仓库内的文件。
    func read(_ path: String, in repository: TemporaryRepository) throws -> String {
        String(decoding: try Data(contentsOf: repository.directory.appending(path: path)), as: UTF8.self)
    }
}
