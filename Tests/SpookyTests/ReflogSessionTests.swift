import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - ReflogSessionTests

/// Reflog 视图的会话层：HEAD 与分支的切换、按说明搜索、分页、读取后的选中、详情与恢复分支。
@MainActor
struct ReflogSessionTests {
    /// 默认看 HEAD 的记录，搜索只看记录的说明；换到分支后只剩这个分支自己的移动，选中记录时右栏显示它的提交；
    /// 看分支的记录时可以把分支移回某条记录，看 HEAD 或当前分支时没有这一项；关闭仓库后回到 HEAD。
    @Test("HEAD 与分支切换、按说明搜索与把分支恢复到记录")
    func browseAndRestore() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        let reflog = session.reflog

        try await prepareBranches(in: fixture)
        try await load(reflog, in: fixture)

        // 默认看 HEAD；HEAD 的记录用重置 HEAD 恢复
        #expect(reflog.reference == "HEAD")
        #expect(reflog.entries.map(\.command) == ["checkout", "commit", "checkout", "commit"])
        #expect(session.reflogRestorableBranch == nil)

        try await searchByMessage(reflog)

        // 当前分支的记录同样用重置 HEAD 恢复
        reflog.show(reference: "refs/heads/main")
        await settle(reflog)
        #expect(session.reflogRestorableBranch == nil)

        // 换到分支后只剩这个分支自己的移动；右栏复用提交详情，显示选中记录的提交
        reflog.show(reference: "refs/heads/功能/分支")
        await settle(reflog)
        #expect(reflog.entries.map(\.message) == ["commit: 功能 [x] *", "branch: Created from HEAD"])

        reflog.selectedID = reflog.entries.first?.id
        #expect(reflog.detail.selectedCommit?.subject == "功能 [x] *")

        // 详情的引用取窗口历史的引用快照，头部收起时同样有 Refs 行
        let commit = try #require(reflog.detail.selectedCommit)
        #expect(reflog.detail.decorations(of: commit.id).map(\.id) == ["refs/heads/功能/分支"])

        try await restoreBranch(in: fixture)

        // 关闭仓库后回到 HEAD
        session.close()
        #expect(reflog.reference == "HEAD" && reflog.entries.isEmpty)
    }

    /// 每页 30 条，与历史每页的条数设置无关；打开时选中第一条并显示它的提交；
    /// 同一引用与搜索条件下的重读至少读回已加载的条数，换引用或搜索时从第一页开始；
    /// 重读后原来那条还在就仍选它，不在了选原来行号上的记录，即原来的下一条，行号超出列表时选最后一条。
    @Test("分页与读取后的选中")
    func pagingAndSelection() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        let reflog = fixture.session.reflog
        let messages = try await writeReflog(count: 35, in: fixture)

        try await load(reflog, in: fixture)

        // 第一页 30 条，打开即选中第一条并显示它的提交
        #expect(reflog.entries.map(\.message) == Array(messages.prefix(30)))
        #expect(reflog.hasMore)
        #expect(reflog.selectedID == reflog.entries.first?.id)
        #expect(reflog.detail.selectedCommit?.id == reflog.entries.first?.commit.id)

        // 续读剩下的 5 条
        reflog.loadNextPage()
        await settle(reflog)

        #expect(reflog.entries.count == 35 && !reflog.hasMore)

        // 选中第二页的记录后重读：读回已加载的 35 条，选中保留
        reflog.selectedID = 32
        reflog.reload()
        await settle(reflog)

        #expect(reflog.entries.count == 35)
        #expect(reflog.selectedID == 32)
        #expect(reflog.selectedEntry?.message == messages[32])

        // 原来那条还在：删掉最新的一条后它上移一行，仍然选中
        reflog.selectedID = 2
        try await delete("HEAD@{0}", from: reflog, in: fixture)

        #expect(reflog.selectedID == 1)
        #expect(reflog.selectedEntry?.message == messages[2])

        // 原来那条不在了：选原来行号上的记录，即原来的下一条
        try await delete("HEAD@{1}", from: reflog, in: fixture)

        #expect(reflog.selectedID == 1)
        #expect(reflog.selectedEntry?.message == messages[3])

        // 行号超出搜索结果：选最后一条
        reflog.selectedID = 25
        reflog.search("第 2")
        await settle(reflog)

        #expect(reflog.entries.count == 11)
        #expect(reflog.selectedEntry == reflog.entries.last)
        #expect(reflog.selectedEntry?.message == "reset: 第 2 条")
    }
}

// MARK: - Helpers

extension ReflogSessionTests {
    /// 搜索只看记录的说明；清空搜索后回到全部记录，选中的记录仍然选中。
    private func searchByMessage(_ reflog: RepositoryReflogState) async throws {
        reflog.selectedID = reflog.entries.first?.id
        let selected = try #require(reflog.selectedEntry)

        reflog.search("Moving From")
        await settle(reflog)

        #expect(reflog.entries.count == 2)
        #expect(reflog.entries.allSatisfy { $0.command == "checkout" })

        reflog.search("")
        await settle(reflog)

        #expect(reflog.entries.count == 4)
        #expect(reflog.selectedEntry?.message == selected.message)
    }

    /// 把正在看的分支移回它最早的记录：确认的标题是 Restore Branch、主按钮是 Restore，经写队列移动，可以撤销。
    private func restoreBranch(in fixture: UndoSessionTests.Fixture) async throws {
        let session = fixture.session
        let reflog = session.reflog
        let references = RepositoryReferences(runner: fixture.runner)
        let title = AppLocalization.text("reflog.restore.title")

        let tip = try #require(reflog.entries.first)
        let start = try #require(reflog.entries.last)

        #expect(session.canRestoreReflogBranch(to: start))
        #expect(!session.canRestoreReflogBranch(to: tip))

        // 确认对话框
        var confirmed: ConfirmationRequest? = nil
        session.onConfirm = { confirmed = $0 }
        session.requestRestore(start)

        let restore = try #require(confirmed)

        #expect(restore.title == title)
        #expect(restore.submitTitle == AppLocalization.text("reflog.restore.submit"))

        // 确认后分支移到那条记录，撤销后回到原处
        try await fixture.perform { restore.action() }

        #expect(try await references.resolve("refs/heads/功能/分支") == start.commit.id)
        #expect(try await UndoSessionTests.settledState(of: session, redo: false) == .available(title))

        try await fixture.perform { session.undoLastOperation() }
        #expect(try await references.resolve("refs/heads/功能/分支") == tip.commit.id)
    }

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
    private func load(
        _ reflog: RepositoryReflogState,
        in fixture: UndoSessionTests.Fixture
    ) async throws {
        await fixture.refresh()

        let runner = try #require(fixture.session.runner)
        reflog.load(runner: runner, location: fixture.location)
        await settle(reflog)
    }

    /// 把 HEAD 的引用日志换成 `count` 条指向当前提交的记录，说明依次是 “reset: 第 1 条” 到 “reset: 第 `count` 条”，
    /// 每条相隔一分钟；返回从新到旧的说明。
    private func writeReflog(count: Int, in fixture: UndoSessionTests.Fixture) async throws -> [String] {
        let output = try await fixture.runner.run(["rev-parse", "HEAD"])
        let head = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        let messages = (1 ... count).map { "reset: 第 \($0) 条" }

        let lines = messages.enumerated().map { index, message in
            "\(head) \(head) Spooky Test <spooky@example.invalid> \(1_767_323_220 + index * 60) +0000\t\(message)\n"
        }

        try Data(lines.joined().utf8).write(to: fixture.directory.appending(path: ".git/logs/HEAD"))

        return messages.reversed()
    }

    /// 用 Git 删掉一条记录，再重读并等读取与详情结束。
    private func delete(
        _ selector: String,
        from reflog: RepositoryReflogState,
        in fixture: UndoSessionTests.Fixture
    ) async throws {
        _ = try await fixture.runner.run(["reflog", "delete", selector])

        reflog.reload()
        await settle(reflog)
    }

    /// 等读取与详情的任务结束；读取在发起时同步登记任务，读完后另起的详情任务也一起等完。
    private func settle(_ reflog: RepositoryReflogState) async {
        await untilFinished { reflog.activeTasks }
    }
}
