import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - ReferenceSessionTests

/// 引用管理经会话执行：未合并分支删除失败后询问强制删除、快进的可用条件、远端视图与网页地址的失败说明。
@MainActor
struct ReferenceSessionTests {
    /// 远端视图记下所选远端，本机路径的远端换算不出网页地址时报告原因与地址；只有落后于上游、没有自己提交的非当前分支可以快进；
    /// 普通删除因未合并失败时不弹错误，而是询问强制删除，按原选项重试后本地与跟踪的远端分支都被删除。
    @Test("远端视图、快进的可用条件与未合并分支的强制删除")
    func referenceManagement() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "spooky-references-" + UUID().uuidString)

        let directory = root.appending(path: "仓 库")
        let bare = root.appending(path: "remote.git").path
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // main 已推送到裸仓库远端
        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)

        _ = try await runner.run(["init", "-q", "--bare", bare])
        _ = try await runner.run(["remote", "add", "origin", bare])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "main"])

        // behind 落后于上游一个提交
        _ = try await runner.run(["branch", "behind"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "behind"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "ahead"])
        _ = try await runner.run(["push", "-q", "origin", "HEAD:refs/heads/behind"])

        // topic 已推送的提交算作合并到上游，再加一个只在本地的提交，普通删除才会失败
        _ = try await runner.run(["switch", "-q", "-c", "topic"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "topic"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "topic"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "local only"])
        _ = try await runner.run(["switch", "-q", "main"])

        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        defer { session.close() }

        session.display(location)
        session.refresh()
        await settle(session)

        try await checkRemoteView(of: session, bare: bare)
        try await checkFastForward(in: session, runner: runner)
        try await checkForceDeletion(in: session, runner: runner, bare: bare)
    }
}

// MARK: - Helpers

extension ReferenceSessionTests {
    /// 远端视图记下所选远端；本机路径的远端换算不出网页地址，报告原因与地址。
    private func checkRemoteView(of session: RepositorySession, bare: String) async throws {
        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        session.showRemote("origin")

        #expect(session.activeView == .remote)
        #expect(session.selectedRemote == "origin")
        #expect(!session.activeView.supportsSearch)

        // 读远端配置在后台任务里完成，失败在主线程报告
        session.openRemoteInBrowser("origin")
        await until { !failures.isEmpty }

        #expect(failures.first?.title == AppLocalization.text("remote.error.browser.title"))
        #expect(failures.first?.details == bare)
        #expect(failures.first?.kind == .repository)
    }

    /// 只有落后于上游、没有自己提交的非当前分支可以快进；快进后与上游相同。
    private func checkFastForward(in session: RepositorySession, runner: GitRunner) async throws {
        let behind = try #require(session.history.branches.first { $0.id == "refs/heads/behind" })
        let main = try #require(session.history.branches.first { $0.id == "refs/heads/main" })

        #expect(session.canFastForward(behind))
        #expect(!session.canFastForward(main))

        session.fastForward(behind)
        await settle(session)

        let references = RepositoryReferences(runner: runner)
        let upstream = try await references.resolve("refs/remotes/origin/behind")

        #expect(try await references.resolve("refs/heads/behind") == upstream)
    }

    /// 普通删除因未合并失败时不弹错误，而是询问强制删除；按原选项重试后本地与跟踪的远端分支都被删除。
    private func checkForceDeletion(
        in session: RepositorySession,
        runner: GitRunner,
        bare: String
    ) async throws {
        var requests: [ReferenceRequest] = []
        var failures: [AppFailure] = []
        session.onReferenceRequest = { requests.append($0) }
        session.onFailure = { failures.append($0) }

        #expect(session.deleteBranches(["refs/heads/topic"], force: false, deletingUpstream: true))
        await settle(session)

        guard case .forceDelete(let offer, let failure) = try #require(requests.last) else {
            Issue.record("未合并分支的删除应询问强制删除")
            return
        }

        #expect(offer.branches == ["refs/heads/topic"])
        #expect(offer.deletingUpstream)
        #expect(failures.isEmpty)
        #expect(failure.details.lowercased().contains("not fully merged"))
        #expect(failure.title == AppLocalization.text("branch.error.delete"))
        #expect(failure.message.hasPrefix(AppLocalization.text("branch.error.unmerged")))

        // 按原选项强制删除
        session.deleteBranches(
            offer.branches,
            force: true,
            deletingUpstream: offer.deletingUpstream
        )
        await settle(session)

        let local = try await runner.run(["for-each-ref", "--format=%(refname)"])
        let remote = try await runner.run(["-C", bare, "for-each-ref"])

        #expect(!String(decoding: local, as: UTF8.self).contains("topic"))
        #expect(!String(decoding: remote, as: UTF8.self).contains("refs/heads/topic"))
    }

    /// 等写操作、随后的完整刷新与引用读取都结束；分叉数与整理状态随引用一起读入。
    private func settle(_ session: RepositorySession) async {
        await session.writeTask?.value
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }
    }
}
