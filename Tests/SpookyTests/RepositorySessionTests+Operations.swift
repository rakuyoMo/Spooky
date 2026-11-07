import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 以真实的进行中操作验证横幅标题与进度、提交区显隐、主按钮与 Skip 的条件。
extension RepositorySessionTests {
    /// 单个摘取按合并的方式收尾，没有进度与 Skip；序列标题写剩余提交数，空的一步才提供 Skip，未跟踪文件也算改动。
    @Test("单个摘取与摘取序列：标题、进度、提交区与 Skip")
    func cherryPickKinds() async throws {
        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await commitFiles(["x": "base"], message: "base", in: directory, runner: runner)
        _ = try await runner.run(["checkout", "-q", "-b", "side"])
        try await commitFiles(["a": "a"], message: "one", in: directory, runner: runner)
        try await commitFiles(["x": "two"], message: "two", in: directory, runner: runner)
        try await commitFiles(["c": "c"], message: "three", in: directory, runner: runner)
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commitFiles(["x": "main"], message: "main", in: directory, runner: runner)

        _ = try await runner.execute(["cherry-pick", "side~1"], acceptedExitCodes: [1])
        try await reload(session) { session.context?.operation == .cherryPick && session.conflictCount == 1 }

        #expect(session.operationBannerTitle == AppLocalization.text("conflict.title.cherryPick.one", "main"))
        #expect(session.operationStepText == nil)
        #expect(!session.showsCommitArea && !session.continuesSequence)

        // 采用我方后没有任何改动，单个摘取仍用 Commit 收尾，不提供 Skip
        try await resolveAll(session, theirs: false)

        #expect(session.isWorkingCopyClean && session.showsCommitArea)
        #expect(!session.continuesSequence && !session.offersSkip)

        _ = try await runner.run(["cherry-pick", "--abort"])
        _ = try await runner.execute(["cherry-pick", "side~2", "side~1", "side"], acceptedExitCodes: [1])

        // 第一个提交已经摘过来，等状态与操作读到同一个 HEAD
        try await reload(session) {
            session.context?.progress?.isSequence ?? false
                && session.context?.progress?.ours == session.status?.branch.oid
                && session.conflictCount == 1
        }

        #expect(session.operationBannerTitle == AppLocalization.text("conflict.title.cherryPick", 2, "main"))
        #expect(session.operationStepText == AppLocalization.text("conflict.step.applying", 1, 2, "two"))
        #expect(!session.showsCommitArea)

        try await resolveAll(session, theirs: false)
        #expect(session.offersSkip && session.continuesSequence && session.showsCommitArea)

        // 未跟踪的文件也是改动，这一步不再算空
        try Data("note".utf8).write(to: directory.appending(path: "note.txt"))
        try await reload(session) { !session.isWorkingCopyClean }
        #expect(!session.offersSkip)
    }

    /// 反转序列的进度写作步骤与反转；单个反转没有进度。
    @Test("反转序列的标题与进度")
    func revertSequence() async throws {
        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await commitFiles(["x": "base"], message: "base", in: directory, runner: runner)
        try await commitFiles(["a": "a"], message: "one", in: directory, runner: runner)
        try await commitFiles(["x": "two"], message: "two", in: directory, runner: runner)
        try await commitFiles(["c": "c"], message: "three", in: directory, runner: runner)
        try await commitFiles(["x": "again"], message: "again", in: directory, runner: runner)

        _ = try await runner.execute(["revert", "--no-edit", "HEAD~3", "HEAD~2", "HEAD~1"], acceptedExitCodes: [1])
        try await reload(session) { session.context?.operation == .revert && session.conflictCount == 1 }

        #expect(session.operationBannerTitle == AppLocalization.text("conflict.title.revert", 2, "main"))
        #expect(session.operationStepText == AppLocalization.text("conflict.step.reverting", 1, 2, "two"))
    }

    /// edit 停下时标题写正在修改的提交与原分支；无关的未跟踪文件不妨碍结束编辑。
    @Test("edit 停顿：标题、进度与结束编辑")
    func editStopBanner() async throws {
        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await commitFiles(["x": "one"], message: "one", in: directory, runner: runner)
        try await commitFiles(["y": "two"], message: "two", in: directory, runner: runner)
        try await commitFiles(["z": "three"], message: "three", in: directory, runner: runner)

        let rewrite = RepositoryRewrite(runner: runner)
        let two = try await rewrite.resolve("HEAD~1")
        try await rewrite.perform(try await rewrite.plan(.edit(two)))

        try await reload(session) { session.context?.progress?.stopsForEdit ?? false }
        let progress = try #require(session.context?.progress)
        let step = try #require(progress.step)
        let count = try #require(progress.stepCount)

        let title = AppLocalization.text("conflict.title.edit", String(two.prefix(8)), "main")

        #expect(session.operationBannerTitle == title)
        #expect(session.operationStepText == AppLocalization.text("conflict.step.editing", step, count, "two"))

        // 停在 edit 上用 Commit 提交当前修订，结束编辑在横幅里
        #expect(session.showsCommitArea && !session.continuesSequence && !session.offersSkip)

        let note = directory.appending(path: "note.txt")
        try Data("note".utf8).write(to: note)
        try await reload(session) { !session.isWorkingCopyClean }
        #expect(session.canWrite)

        session.finishOperation("continue")
        await session.writeTask?.value
        try await waitUntil { session.context != nil && session.context?.operation == nil }

        #expect(FileManager.default.fileExists(atPath: note.path))
    }

    /// 没有进行中操作的冲突照常显示提交区，但带着未解决冲突不能提交。
    @Test("储藏恢复冲突显示提交区但不能提交")
    func stashConflictCommitArea() async throws {
        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await commitFiles(["x": "base"], message: "base", in: directory, runner: runner)
        try Data("stashed".utf8).write(to: directory.appending(path: "x"))
        _ = try await runner.run(["stash", "-q"])
        try await commitFiles(["x": "main"], message: "main", in: directory, runner: runner)
        _ = try await runner.execute(["stash", "pop", "-q"], acceptedExitCodes: [1])

        // 另有一个已暂存的改动，提交被拒绝只因为冲突
        try Data("staged".utf8).write(to: directory.appending(path: "y"))
        _ = try await runner.run(["add", "y"])

        try await reload(session) { session.context != nil && session.conflictCount == 1 }
        session.commitSubject = "message"

        #expect(session.context?.progress == nil)
        #expect(session.showsCommitArea && !session.canCommit)
    }

    /// 交互式变基还没处理任何提交时只显示横幅：提交区隐藏，也不提供 Skip。
    @Test("交互式变基尚未开始时隐藏提交区")
    func pendingInteractiveRebase() async throws {
        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await commitFiles(["x": "base"], message: "base", in: directory, runner: runner)
        try await commitFiles(["x": "one"], message: "one", in: directory, runner: runner)

        // 第一条就是 break，Git 停下时还没处理任何提交
        let one = String(decoding: try await runner.run(["rev-parse", "HEAD"]), as: UTF8.self)
        let todo = FileManager.default.temporaryDirectory
            .appending(path: "spooky-todo-" + UUID().uuidString)

        try Data("break\npick \(one)".utf8).write(to: todo)
        defer { try? FileManager.default.removeItem(at: todo) }

        _ = try await runner.run(["-c", "sequence.editor=cp " + todo.path, "rebase", "-i", "HEAD~1"])
        try await reload(session) { session.context?.progress?.isPendingInteractive ?? false }

        #expect(session.isWorkingCopyClean)
        #expect(!session.showsCommitArea && !session.offersSkip)
    }

    /// 只看冲突是全局偏好：另一个会话读到同一个开关；全部解决后仍然可用并保留已解决的文件，操作结束后偏好保留但不再过滤。
    @Test("只看冲突：全局偏好、解决后保留与操作结束")
    func onlyConflictsPreference() async throws {
        let key = WorkingCopyPreferences.showOnlyConflicts
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }

        UserDefaults.standard.set(true, forKey: key)

        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await commitFiles(["x": "base", "y": "base"], message: "base", in: directory, runner: runner)
        _ = try await runner.run(["checkout", "-q", "-b", "side"])
        try await commitFiles(["x": "side", "y": "side"], message: "side", in: directory, runner: runner)
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commitFiles(["x": "main", "y": "main"], message: "main", in: directory, runner: runner)

        _ = try await runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])
        try Data("note".utf8).write(to: directory.appending(path: "note.txt"))
        try await reload(session) { session.conflictCount == 2 && session.context?.progress != nil }

        /// 会话当前列出的条目。
        func listed(_ session: RepositorySession) -> [StatusEntry] {
            session.listing.entries(
                status: session.status?.entries ?? [],
                files: session.workingTreeFiles
            )
        }

        #expect(session.conflictPaths == ["x", "y"])
        #expect(listed(session).map(\.path) == ["x", "y"])

        // x 采用对方后仍有改动，y 采用我方后与 HEAD 相同、不在状态里
        let entries = session.status?.entries ?? []
        session.resolve(entries.filter { $0.path == "x" }, theirs: true)
        await session.writeTask?.value
        session.resolve(entries.filter { $0.path == "y" }, theirs: false)
        await session.writeTask?.value
        try await reload(session) { session.conflictCount == 0 && session.resolvedConflictCount == 2 }

        #expect(session.conflictPaths == ["x", "y"])
        #expect(listed(session).map(\.path) == ["x", "y"])
        #expect(listed(session).map(\.kind) == [.tracked, .unchanged])

        // 另一个会话打开同一仓库，按同一个偏好过滤
        let location = RepositoryLocation.local(path: directory.path)
        let other = RepositorySession(makeRunner: { _ in runner })
        defer { other.close() }

        other.display(location)
        try await reload(other) { other.conflictPaths != nil }
        #expect(listed(other).map(\.path) == ["x", "y"])

        // 合并提交后操作结束，偏好保留，列表恢复成普通的改动
        _ = try await runner.run(["commit", "-q", "--no-edit"])
        try await reload(session) { session.context != nil && session.context?.progress == nil }

        #expect(UserDefaults.standard.bool(forKey: key))
        #expect(session.conflictPaths == nil)
        #expect(listed(session).map(\.path) == ["note.txt"])
    }
}

// MARK: - Helpers

extension RepositorySessionTests {
    /// 在临时目录新建仓库并打开会话。
    ///
    /// - Returns: 会话、仓库目录与操作仓库的执行器。
    private func openOperationRepository() async throws -> (RepositorySession, URL, GitRunner) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-operation-" + UUID().uuidString)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await initializeRepository(at: location)
        let session = RepositorySession(makeRunner: { _ in runner })
        session.display(location)
        return (session, directory, runner)
    }

    /// 关闭会话并删除临时仓库。
    private func closeOperationRepository(_ session: RepositorySession, _ directory: URL) {
        session.close()
        try? FileManager.default.removeItem(at: directory)
    }

    /// 写入文件后提交全部改动；内容末尾补一个换行。
    private func commitFiles(
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

    /// 在外部改动仓库后刷新会话，等到读到的状态满足条件。
    private func reload(_ session: RepositorySession, until condition: () -> Bool) async throws {
        session.refresh(full: true)
        await session.waitForRefresh()
        try await waitUntil(condition)
    }

    /// 经会话把全部冲突采用同一侧解决，等到冲突清空。
    private func resolveAll(_ session: RepositorySession, theirs: Bool) async throws {
        session.resolve(session.status?.entries.filter { $0.kind == .conflicted } ?? [], theirs: theirs)
        await session.writeTask?.value
        try await waitUntil { session.conflictCount == 0 && session.context?.progress != nil }
    }
}
