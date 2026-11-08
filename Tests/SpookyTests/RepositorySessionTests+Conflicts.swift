import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 以真实的合并冲突验证切到工作区、横幅的文字、已解决计数、恢复冲突版本、只看冲突与修补的可用性。
extension RepositorySessionTests {
    /// 合并停在冲突上时不报告失败，切到工作区；两侧用引用名说明，合并进行中不能修补；
    /// 解决一个冲突后计数要能追溯；恢复冲突版本只改工作区，不经确认直接执行；
    /// 只看冲突在全部解决后仍保留已解决的文件，操作结束后不再过滤。
    @Test("合并冲突的横幅、已解决计数、恢复冲突、只看冲突与修补")
    func conflictSession() async throws {
        let (session, directory, runner) = try await openOperationRepository { directory, runner in
            try await commitFiles(["x": "base", "y": "base"], message: "base", in: directory, runner: runner)
            _ = try await runner.run(["checkout", "-q", "-b", "side"])
            try await commitFiles(["x": "side", "y": "side"], message: "side", in: directory, runner: runner)
            _ = try await runner.run(["checkout", "-q", "main"])
            try await commitFiles(["x": "main", "y": "main"], message: "main", in: directory, runner: runner)
        }

        defer { closeOperationRepository(session, directory) }

        // 冲突向导的操作都不需要确认，弹出确认就是错误
        session.onConfirm = { Issue.record("不应弹出确认：\($0.title)") }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }
        session.activeView = .history

        // 快速合并与合并对话框共用这个写操作
        let started = session.performGit(
            session.mergeAction("refs/heads/side", options: MergeOptions()),
            title: AppLocalization.text("sync.quickMerge"),
            undo: .reversible
        )

        #expect(started)
        await session.writeTask?.value
        try #require(failures.isEmpty)

        // 合并开始前不能有任何改动，未跟踪的文件也不行：它在合并停下后才写入，用来核对只看冲突时滤掉其它改动
        try Data("note".utf8).write(to: directory.appending(path: "note.txt"))
        await reload(session) { session.context?.operation == .merge }

        #expect(session.activeView == .workingCopy)
        #expect(session.operationBannerTitle == AppLocalization.text("conflict.title.merge", "side", "main"))
        #expect(session.conflictCount == 2)
        #expect(!session.canAmend)

        try await resolveAndRestore(session)
        try await filterConflicts(session, runner: runner)
    }
}

// MARK: - Steps

extension RepositorySessionTests {
    /// 采用对方解决 x 后横幅数出已解决的冲突；已解决的文件可以重新生成冲突，但没有我方版本可恢复。
    private func resolveAndRestore(_ session: RepositorySession) async throws {
        let conflicted = try #require(session.status?.entries.first { $0.path == "x" })
        session.resolve([conflicted], theirs: true)
        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(session.conflictCount == 1)

        // 已解决的文件来自上下文，上下文的读取没有暴露，等它读到 x
        await until { session.context?.progress?.resolvedPaths.contains("x") ?? false }
        #expect(session.resolvedConflictCount == 1)

        let resolved = try #require(session.status?.entries.first { $0.path == "x" })
        #expect(session.canRestoreConflicts([resolved], to: .unmerged))
        #expect(!session.canRestoreConflicts([resolved], to: .ours))

        session.restoreConflicts([resolved], to: .unmerged, title: "restore")
        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(session.conflictCount == 2)
    }

    /// 只看冲突时只列出冲突文件；x 采用对方、y 采用我方后两者仍在列表里，合并中仍不能修补；提交合并后列表恢复成普通的改动。
    private func filterConflicts(_ session: RepositorySession, runner: GitRunner) async throws {
        #expect(conflictListing(session).map(\.path) == ["x", "y"])

        // x 采用对方后仍有改动，y 采用我方后与 HEAD 相同、不在状态里
        let entries = session.status?.entries ?? []
        session.resolve(entries.filter { $0.path == "x" }, theirs: true)
        await session.writeTask?.value
        session.resolve(entries.filter { $0.path == "y" }, theirs: false)
        await session.writeTask?.value
        await reload(session) { session.resolvedConflictCount == 2 }

        #expect(session.conflictCount == 0)
        #expect(session.conflictPaths == ["x", "y"])
        #expect(conflictListing(session).map(\.path) == ["x", "y"])
        #expect(conflictListing(session).map(\.kind) == [.tracked, .unchanged])

        // 冲突都解决了，合并仍在进行，打开修补不起作用
        session.setAmend(true)
        #expect(!session.canAmend && !session.amend)

        // 提交合并后操作结束，列表恢复成普通的改动
        _ = try await runner.run(["commit", "-q", "--no-edit"])
        await reload(session) { session.context != nil && session.context?.progress == nil }

        #expect(session.conflictPaths == nil)
        #expect(conflictListing(session).map(\.path) == ["note.txt"])
    }

    /// 打开只看冲突时会话列出的条目。
    ///
    /// 这个开关是全局偏好，会话只从 `UserDefaults.standard` 读取：只在这段同步读取期间打开，读完还原，不影响并行的测试。
    private func conflictListing(_ session: RepositorySession) -> [StatusEntry] {
        let key = WorkingCopyPreferences.showOnlyConflicts
        let saved = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(true, forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }

        return session.listing.entries(
            status: session.status?.entries ?? [],
            files: session.workingTreeFiles
        )
    }
}
