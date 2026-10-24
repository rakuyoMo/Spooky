import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ReflogSessionTests

/// Reflog 视图的会话层：HEAD 与分支的切换、按说明搜索、详情、从记录找回提交与恢复分支。
@MainActor
struct ReflogSessionTests {
    /// 默认看 HEAD 的记录；换到分支后只剩这个分支自己的移动，选中记录时右栏显示它的提交。
    @Test("HEAD 与分支切换，选中记录显示提交详情")
    func switchReference() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        let reflog = fixture.session.reflog
        try await prepareBranches(in: fixture)

        try await load(reflog, in: fixture)
        #expect(reflog.reference == "HEAD")
        #expect(reflog.entries.map(\.command) == ["checkout", "commit", "checkout", "commit"])

        reflog.show(reference: "refs/heads/功能/分支")
        try await settle(reflog)
        #expect(reflog.entries.map(\.message) == ["commit: 功能 [x] *", "branch: Created from HEAD"])

        // 右栏复用提交详情，显示选中记录的提交
        reflog.selectedID = reflog.entries.first?.id
        #expect(reflog.detail.selectedCommit?.subject == "功能 [x] *")

        // 关闭仓库后回到 HEAD
        fixture.session.close()
        #expect(reflog.reference == "HEAD" && reflog.entries.isEmpty)
    }

    /// 搜索只看记录的说明；清空搜索后回到全部记录，选中的记录仍然选中。
    @Test("按说明搜索")
    func search() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        let reflog = fixture.session.reflog
        try await prepareBranches(in: fixture)
        try await load(reflog, in: fixture)

        reflog.selectedID = reflog.entries.first?.id
        let selected = try #require(reflog.selectedEntry)

        reflog.search("Moving From")
        try await settle(reflog)
        #expect(reflog.entries.count == 2)
        #expect(reflog.entries.allSatisfy { $0.command == "checkout" })

        reflog.search("")
        try await settle(reflog)
        #expect(reflog.entries.count == 4)
        #expect(reflog.selectedEntry?.message == selected.message)
    }

    /// 硬重置丢掉的提交只留在 Reflog 里：从这条记录新建分支就能找回它。
    @Test("从记录新建分支找回提交")
    func createBranchFromEntry() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        let runner = fixture.runner
        let reflog = fixture.session.reflog

        try fixture.write("lost\n")
        _ = try await runner.run(["commit", "-q", "-a", "-m", "lost commit"])
        _ = try await runner.run(["reset", "-q", "--hard", "HEAD~1"])
        try await load(reflog, in: fixture)

        let entry = try #require(reflog.entries.first { $0.commit.subject == "lost commit" })
        try await fixture.perform {
            fixture.session.performGit(
                { runner, _ in
                    try await RepositoryReferences(runner: runner)
                        .create(name: "rescued", startingAt: entry.commit.id, track: false, checkout: false)
                },
                title: "Create Branch",
                undo: .reversible
            )
        }

        #expect(try await RepositoryReferences(runner: runner).resolve("refs/heads/rescued") == entry.commit.id)
    }

    /// 看分支的记录时可以把分支移回某条记录：确认后经写队列移动，可以撤销；看 HEAD 或当前分支时没有这一项。
    @Test("把分支恢复到记录")
    func restoreBranch() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let reflog = session.reflog
        try await prepareBranches(in: fixture)
        try await load(reflog, in: fixture)

        // HEAD 与当前分支的记录用重置 HEAD 恢复
        #expect(session.reflogRestorableBranch == nil)
        reflog.show(reference: "refs/heads/main")
        try await settle(reflog)
        #expect(session.reflogRestorableBranch == nil)

        reflog.show(reference: "refs/heads/功能/分支")
        try await settle(reflog)
        let tip = try #require(reflog.entries.first?.commit.id)
        let start = try #require(reflog.entries.last)
        #expect(session.canRestoreReflogBranch(to: start))
        #expect(!session.canRestoreReflogBranch(to: try #require(reflog.entries.first)))

        var confirmed: (() -> Void)? = nil
        session.onConfirm = { _, _, action, _ in confirmed = action }
        session.requestRestore(start)
        let restore = try #require(confirmed)
        try await fixture.perform { restore() }

        let references = RepositoryReferences(runner: fixture.runner)
        #expect(try await references.resolve("refs/heads/功能/分支") == start.commit.id)
        #expect(
            try await UndoSessionTests.settledState(of: session, redo: false)
                == .available(AppLocalization.text("reflog.restore.title"))
        )

        try await fixture.perform { session.undoLastOperation() }
        #expect(try await references.resolve("refs/heads/功能/分支") == tip)
    }
}

// MARK: - Helpers

extension ReflogSessionTests {
    /// 从主分支新建中文分支并提交一次，再检出回主分支，然后刷新会话的引用。
    private func prepareBranches(in fixture: UndoSessionTests.Fixture) async throws {
        let runner = fixture.runner
        _ = try await runner.run(["checkout", "-q", "-b", "功能/分支"])
        try fixture.write("feature\n")
        _ = try await runner.run(["commit", "-q", "-a", "-m", "功能 [x] *"])
        _ = try await runner.run(["checkout", "-q", "main"])
        await fixture.refresh()
    }

    /// 打开会话仓库的 Reflog 并等第一页读完。
    private func load(_ reflog: RepositoryReflogState, in fixture: UndoSessionTests.Fixture) async throws {
        await fixture.refresh()

        let runner = try #require(fixture.session.runner)
        reflog.load(runner: runner, location: fixture.location)
        try await settle(reflog)
    }

    /// 等读取与详情的任务结束。
    private func settle(_ reflog: RepositoryReflogState) async throws {
        try await FileViewsTests.wait { reflog.isLoaded && !reflog.isLoading }

        for task in reflog.activeTasks {
            await task.value
        }
    }
}
