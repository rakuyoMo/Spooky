import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Branches

/// 分支的新建、删除与停在冲突上的操作怎样进撤销记录：新建并检出记成两步，多选删除只删掉一部分时按实际删掉的记，
/// 连同远端分支删除的撤销先在远端重建，停在冲突上的合并与反转撤销时放弃它。
extension UndoSessionTests {
    /// 新建并检出分支记成两步：先撤销检出，分支还在；再撤销新建，分支被删掉。重做按相反的顺序回来。
    @Test("新建并检出分支的两步撤销")
    func createAndCheckoutRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        let create = AppLocalization.text("branch.create")
        let checkout = AppLocalization.text("rewrite.checkout")

        try await fixture.perform { Self.createAndCheckOut("功能/新", in: session) }

        #expect(session.status?.branch.head == "功能/新")
        #expect(try await Self.settledState(of: session, redo: false) == .available(checkout))

        // 第一步撤销检出：回到 main，新分支还在
        try await fixture.perform { session.undoLastOperation() }

        #expect(session.status?.branch.head == "main")
        #expect(Self.hasBranch("功能/新", in: session))
        #expect(try await Self.settledState(of: session, redo: false) == .available(create))
        #expect(try await Self.settledState(of: session, redo: true) == .available(checkout))

        // 第二步撤销新建：分支被删掉
        try await fixture.perform { session.undoLastOperation() }

        #expect(!Self.hasBranch("功能/新", in: session))
        #expect(try await Self.settledState(of: session, redo: true) == .available(create))

        // 重做两次回到新分支上
        try await fixture.perform { session.redoLastOperation() }
        try await fixture.perform { session.redoLastOperation() }

        #expect(session.status?.branch.head == "功能/新")
    }

    /// 多选普通删除时已合并的先删掉并记撤销，名称按删掉的个数写，再询问强制删除未合并的；
    /// 不强制删除时撤销让删掉的分支连同上游设置一起回来。
    @Test("多选删除只删掉一部分后的撤销")
    func partialDeletionRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        let runner = fixture.runner

        // merged 留在 main 上并跟踪 main；unmerged 多一个 main 上没有的提交
        _ = try await runner.run(["branch", "--track=direct", "merged", "main"])
        _ = try await runner.run(["switch", "-q", "-c", "unmerged"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "未合并"])
        _ = try await runner.run(["switch", "-q", "main"])
        await fixture.refresh()

        var requests: [ReferenceRequest] = []
        session.onReferenceRequest = { requests.append($0) }

        try await fixture.perform {
            session.deleteBranches(
                ["refs/heads/merged", "refs/heads/unmerged"],
                force: false,
                deletingUpstream: false
            )
        }

        // 写操作结束后才询问未合并的分支
        guard case .forceDelete(let offer) = try #require(requests.last) else {
            Issue.record("应询问是否强制删除未合并的分支")
            return
        }

        #expect(offer.branches == ["refs/heads/unmerged"])
        #expect(!Self.hasBranch("merged", in: session))
        #expect(Self.hasBranch("unmerged", in: session))
        #expect(
            try await Self.settledState(of: session, redo: false)
                == .available(AppLocalization.text("branch.delete"))
        )

        // 不强制删除，直接撤销
        try await fixture.perform { session.undoLastOperation() }

        let merge = try await runner.run(["config", "--local", "branch.merged.merge"])

        #expect(Self.hasBranch("merged", in: session))
        #expect(String(decoding: merge, as: UTF8.self) == "refs/heads/main\n")
    }

    /// 连同跟踪的远端分支一起删除可以撤销：撤销先在远端重建远端分支，再重建本地分支与上游；重做再次删除两者。
    /// 远端在此期间又有了同名分支时撤销失败，本地不动，记录留在撤销栈里。
    @Test("连同远端分支删除后的撤销")
    func deletionWithUpstreamRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        let runner = fixture.runner
        let bare = try await Self.makeRemote(for: fixture)
        defer { try? FileManager.default.removeItem(atPath: bare) }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        _ = try await runner.run(["remote", "add", "origin", bare])
        _ = try await runner.run(["branch", "topic"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "main", "topic"])
        await fixture.refresh()

        try await fixture.perform {
            session.deleteBranches(["refs/heads/topic"], force: false, deletingUpstream: true)
        }

        #expect(try await Self.references(in: bare, of: fixture) == ["refs/heads/main"])
        #expect(
            try await Self.settledState(of: session, redo: false)
                == .available(AppLocalization.text("branch.delete"))
        )

        // 撤销：远端分支、本地分支与上游都回来
        try await fixture.perform { session.undoLastOperation() }

        let remote = try await runner.run(["config", "--local", "branch.topic.remote"])

        #expect(try await Self.references(in: bare, of: fixture) == ["refs/heads/main", "refs/heads/topic"])
        #expect(Self.hasBranch("topic", in: session))
        #expect(String(decoding: remote, as: UTF8.self) == "origin\n")

        // 重做再次删除两者
        try await fixture.perform { session.redoLastOperation() }
        #expect(try await Self.references(in: bare, of: fixture) == ["refs/heads/main"])

        // 远端又有了同名分支：推送的租约拒绝，本地不动
        let head = try await fixture.head()
        _ = try await runner.run(["-C", bare, "update-ref", "refs/heads/topic", head])

        let count = session.undoHistory?.undoEntries.count
        try await fixture.perform { session.undoLastOperation() }

        #expect(failures.count == 1)
        #expect(!Self.hasBranch("topic", in: session))
        #expect(session.undoHistory?.undoEntries.count == count)
    }

    /// 合并停在冲突上时撤销可用，执行等于放弃合并，重做再次合并并停在冲突上；
    /// 反转停在冲突上时同样，撤销名是 Revert Revisions。
    @Test("停在冲突上的合并与反转的撤销")
    func stoppedOperationsRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        let runner = fixture.runner
        let merge = AppLocalization.text("sync.quickMerge")
        let revert = AppLocalization.text("rewrite.revert.title")

        // side 与 main 改了同一行；main 上另有一个提交再改这一行，反转 main 的第一个改动时冲突
        _ = try await runner.run(["switch", "-q", "-c", "side"])
        try fixture.write("side\n")
        _ = try await runner.run(["commit", "-q", "-am", "side"])
        _ = try await runner.run(["switch", "-q", "main"])

        try fixture.write("one\n")
        _ = try await runner.run(["commit", "-q", "-am", "one"])
        let one = try await fixture.head()

        try fixture.write("two\n")
        _ = try await runner.run(["commit", "-q", "-am", "two"])
        let head = try await fixture.head()
        await fixture.refresh()

        // 合并停在冲突上：撤销放弃合并，重做再次停在冲突上
        let side = try #require(session.history.branches.first { $0.id == "refs/heads/side" })
        try await fixture.perform { session.quickMerge(side) }

        await until { session.context?.operation == .merge }
        #expect(try await Self.settledState(of: session, redo: false) == .available(merge))

        try await fixture.perform { session.undoLastOperation() }

        await until { session.context?.operation == nil }
        #expect(try await fixture.head() == head)
        #expect(try fixture.read() == "two\n")

        try await fixture.perform { session.redoLastOperation() }

        await until { session.context?.operation == .merge }
        #expect(try await Self.settledState(of: session, redo: false) == .available(merge))

        try await fixture.perform { session.undoLastOperation() }

        // 反转停在冲突上：Git 以失败结束，撤销同样放弃它，重做再次停在冲突上
        try await fixture.perform { session.revert([one], options: PickOptions()) }

        await until { session.context?.operation == .revert }
        #expect(try await Self.settledState(of: session, redo: false) == .available(revert))

        try await fixture.perform { session.undoLastOperation() }

        await until { session.context?.operation == nil }
        #expect(try await fixture.head() == head)

        try await fixture.perform { session.redoLastOperation() }

        await until { session.context?.operation == .revert }
        #expect(try await Self.settledState(of: session, redo: false) == .available(revert))
    }
}

// MARK: - Helpers

extension UndoSessionTests {
    /// 像新建分支的对话框勾选检出时一样经写队列新建并检出分支：新建单独记一步，检出一步名为 Checkout Revision。
    static func createAndCheckOut(_ name: String, in session: RepositorySession) {
        session.performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).createThenCheckOut(
                    name: name,
                    startingAt: "HEAD",
                    track: false
                ) {
                    await UndoSteps.current?.mark(AppLocalization.text("branch.create"), runner: runner)
                }

                UndoSteps.current?.rename(AppLocalization.text("rewrite.checkout"))
            },
            title: AppLocalization.text("branch.create"),
            undo: .reversible
        )
    }
}
