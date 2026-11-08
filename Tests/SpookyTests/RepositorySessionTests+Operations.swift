import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 以真实的进行中操作验证横幅标题与进度、提交区显隐、主按钮与 Skip 的条件。
extension RepositorySessionTests {
    /// 单个摘取按合并的方式收尾，没有进度与 Skip；序列标题写剩余提交数，空的一步才提供 Skip，未跟踪文件也算改动；
    /// 序列用信息框里编辑后的信息继续，停在下一步时预填换成下一个提交的信息。
    @Test("摘取：单个与序列的标题、进度、提交区、Skip 与编辑后的信息")
    func cherryPickSequence() async throws {
        let (session, directory, runner) = try await openOperationRepository { directory, runner in
            try await commitFiles(["x": "base"], message: "base", in: directory, runner: runner)
            _ = try await runner.run(["checkout", "-q", "-b", "side"])
            try await commitFiles(["a": "a"], message: "one", in: directory, runner: runner)
            try await commitFiles(["x": "two"], message: "two", in: directory, runner: runner)
            try await commitFiles(["x": "three"], message: "three", in: directory, runner: runner)
            _ = try await runner.run(["checkout", "-q", "main"])
            try await commitFiles(["x": "main"], message: "main", in: directory, runner: runner)
        }

        defer { closeOperationRepository(session, directory) }

        try await singleCherryPick(session, runner: runner)
        try await cherryPickSteps(session, directory: directory, runner: runner)
    }

    /// 交互式变基还没处理任何提交时只显示横幅；停在 edit 上时标题写正在修改的提交与原分支，用 Commit 提交当前修订，
    /// 工作区没有任何改动也不算空提交；无关的未跟踪文件不妨碍结束编辑。
    @Test("交互式变基：尚未开始与 edit 停顿")
    func interactiveRebaseStops() async throws {
        let (session, directory, runner) = try await openOperationRepository { directory, runner in
            try await commitFiles(["x": "one"], message: "one", in: directory, runner: runner)
            try await commitFiles(["y": "two"], message: "two", in: directory, runner: runner)
            try await commitFiles(["z": "three"], message: "three", in: directory, runner: runner)

            // 第一条就是 break，Git 停下时还没处理任何提交
            let three = String(decoding: try await runner.run(["rev-parse", "HEAD"]), as: UTF8.self)
            let todo = directory.appending(path: ".git/spooky-todo")
            try Data("break\npick \(three)".utf8).write(to: todo)

            _ = try await runner.run(["-c", "sequence.editor=cp " + todo.path, "rebase", "-i", "HEAD~1"])
        }

        defer { closeOperationRepository(session, directory) }

        #expect(session.context?.progress?.isPendingInteractive ?? false)
        #expect(session.isWorkingCopyClean)
        #expect(!session.showsCommitArea && !session.offersSkip)

        _ = try await runner.run(["rebase", "--abort"])
        try await stopAtEdit(session, directory: directory, runner: runner)
    }

    /// 没有进行中操作的冲突照常显示提交区，但带着未解决冲突不能提交。
    @Test("储藏恢复冲突显示提交区但不能提交")
    func stashConflictCommitArea() async throws {
        let (session, directory, _) = try await openOperationRepository { directory, runner in
            try await commitFiles(["x": "base"], message: "base", in: directory, runner: runner)
            try Data("stashed".utf8).write(to: directory.appending(path: "x"))
            _ = try await runner.run(["stash", "-q"])
            try await commitFiles(["x": "main"], message: "main", in: directory, runner: runner)
            _ = try await runner.execute(["stash", "pop", "-q"], acceptedExitCodes: [1])

            // 另有一个已暂存的改动，提交被拒绝只因为冲突
            try Data("staged".utf8).write(to: directory.appending(path: "y"))
            _ = try await runner.run(["add", "y"])
        }

        defer { closeOperationRepository(session, directory) }

        session.commitSubject = "message"

        #expect(session.conflictCount == 1)
        #expect(session.context?.progress == nil)
        #expect(session.showsCommitArea && !session.canCommit)
    }
}

// MARK: - Steps

extension RepositorySessionTests {
    /// 单个摘取：没有进度，冲突时隐藏提交区；采用我方后没有任何改动，仍用 Commit 收尾，不提供 Skip。
    private func singleCherryPick(_ session: RepositorySession, runner: GitRunner) async throws {
        _ = try await runner.execute(["cherry-pick", "side~1"], acceptedExitCodes: [1])
        await reload(session) { session.context?.operation == .cherryPick }

        #expect(session.conflictCount == 1)
        #expect(session.operationBannerTitle == AppLocalization.text("conflict.title.cherryPick.one", "main"))
        #expect(session.operationStepText == nil)
        #expect(!session.showsCommitArea && !session.continuesSequence)

        await resolveAll(session, theirs: false)

        #expect(session.isWorkingCopyClean && session.showsCommitArea)
        #expect(!session.continuesSequence && !session.offersSkip)

        _ = try await runner.run(["cherry-pick", "--abort"])
    }

    /// 摘取序列停在第二个提交：空的一步提供 Skip，未跟踪文件让它不再算空；编辑信息后继续，第三个提交同样冲突。
    private func cherryPickSteps(
        _ session: RepositorySession,
        directory: URL,
        runner: GitRunner
    ) async throws {
        _ = try await runner.execute(["cherry-pick", "side~2", "side~1", "side"], acceptedExitCodes: [1])

        // 第一个提交已经摘过来，等状态与操作读到同一个 HEAD
        await reload(session) {
            (session.context?.progress?.isSequence ?? false)
                && session.context?.progress?.ours == session.status?.branch.oid
        }

        #expect(session.conflictCount == 1)
        #expect(session.operationBannerTitle == AppLocalization.text("conflict.title.cherryPick", 2, "main"))
        #expect(session.operationStepText == AppLocalization.text("conflict.step.applying", 1, 2, "two"))
        #expect(session.commitSubject == "two")
        #expect(!session.showsCommitArea)

        await resolveAll(session, theirs: false)
        #expect(session.offersSkip && session.continuesSequence && session.showsCommitArea)

        // 未跟踪的文件也是改动，这一步不再算空
        try Data("note".utf8).write(to: directory.appending(path: "note.txt"))
        await reload(session) { !session.isWorkingCopyClean }

        #expect(!session.offersSkip)

        // 手工解决成两侧都没有的内容，下一步接在它上面同样冲突
        try Data("resolved\n".utf8).write(to: directory.appending(path: "x"))
        _ = try await runner.run(["add", "x"])

        let three = String(decoding: try await runner.run(["rev-parse", "side"]), as: UTF8.self)
            .trimmingCharacters(in: .newlines)

        session.setMessage("编辑后的 “two”\n\n正文")
        session.continueSequence()
        await session.writeTask?.value
        await reload(session) { session.context?.progress?.theirs == three }

        let message = String(decoding: try await runner.run(["log", "-1", "--format=%B", "HEAD"]), as: UTF8.self)

        #expect(session.conflictCount == 1)
        #expect(message.trimmingCharacters(in: .newlines) == "编辑后的 “two”\n\n正文")
        #expect(session.commitSubject == "three")
    }

    /// 经提交改写停在 two 的 edit 上：横幅、提交区与空提交的判断，最后带着未跟踪文件结束编辑。
    private func stopAtEdit(
        _ session: RepositorySession,
        directory: URL,
        runner: GitRunner
    ) async throws {
        let rewrite = RepositoryRewrite(runner: runner)
        let two = try await rewrite.resolve("HEAD~1")
        try await rewrite.perform(try await rewrite.plan(.edit(two)))
        await reload(session) { session.context?.progress?.stopsForEdit ?? false }

        let progress = try #require(session.context?.progress)
        let step = try #require(progress.step)
        let count = try #require(progress.stepCount)
        let title = AppLocalization.text("conflict.title.edit", String(two.prefix(8)), "main")

        #expect(session.operationBannerTitle == title)
        #expect(session.operationStepText == AppLocalization.text("conflict.step.editing", step, count, "two"))

        // 停在 edit 上用 Commit 提交当前修订，结束编辑在横幅里
        #expect(session.showsCommitArea && !session.continuesSequence && !session.offersSkip)

        // 停下时重新打开了 two 的改动，删掉它新增的文件后工作区没有任何改动，这时也不算空提交
        try FileManager.default.removeItem(at: directory.appending(path: "y"))
        await reload(session) { session.isWorkingCopyClean }

        #expect(!session.commitsEmpty)

        let note = directory.appending(path: "note.txt")
        try Data("note".utf8).write(to: note)
        await reload(session) { !session.isWorkingCopyClean }

        #expect(session.canWrite)

        session.finishOperation("continue")
        await session.writeTask?.value
        await reload(session) { session.context != nil && session.context?.operation == nil }

        #expect(FileManager.default.fileExists(atPath: note.path))
    }
}

// MARK: - Helpers

extension RepositorySessionTests {
    /// 在临时目录新建仓库，按 `prepare` 写好内容后打开会话，等首次刷新与上下文读取结束。
    ///
    /// - Parameter prepare: 打开会话之前对仓库目录与执行器做的准备。
    /// - Returns: 会话、仓库目录与操作仓库的执行器。
    func openOperationRepository(
        prepare: (URL, GitRunner) async throws -> Void = { _, _ in }
    ) async throws -> (RepositorySession, URL, GitRunner) {
        let directory = try FileViewsTests.temporaryDirectory()
        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)

        try await prepare(directory, runner)

        let session = RepositorySession(makeRunner: { _ in runner })
        session.display(location)
        await reload(session) { session.context != nil }

        return (session, directory, runner)
    }

    /// 关闭会话并删除临时仓库。
    func closeOperationRepository(_ session: RepositorySession, _ directory: URL) {
        session.close()
        try? FileManager.default.removeItem(at: directory)
    }

    /// 写入文件后提交全部改动；内容末尾补一个换行。
    func commitFiles(
        _ files: [String: String],
        message: String,
        in directory: URL,
        runner: GitRunner
    ) async throws {
        for (path, content) in files {
            try Data((content + "\n").utf8).write(to: directory.appending(path: path))
        }

        _ = try await runner.run(["add", "-A"])
        _ = try await runner.run(["commit", "-q", "-m", message])
    }

    /// 在外部改动仓库后完整刷新会话，等刷新结束、上下文满足条件。
    ///
    /// 上下文在状态之后另行读取，读取任务没有暴露：条件要选只有这次读到新结果才成立的值。
    func reload(
        _ session: RepositorySession,
        until context: @escaping @MainActor () -> Bool = { true }
    ) async {
        session.refresh(full: true)
        await session.waitForRefresh()
        await until(context)
    }

    /// 经会话把全部冲突采用同一侧解决，等写入与随后的刷新结束。
    func resolveAll(_ session: RepositorySession, theirs: Bool) async {
        session.resolve(
            session.status?.entries.filter { $0.kind == .conflicted } ?? [],
            theirs: theirs
        )
        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(session.conflictCount == 0)
    }
}
