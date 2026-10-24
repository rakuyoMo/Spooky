import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ReferenceSessionTests

/// 引用管理经会话执行：未合并分支删除失败后询问强制删除、快进的可用条件、远端视图与网页地址的失败说明。
@MainActor
struct ReferenceSessionTests {
    /// 普通删除因未合并失败时不弹错误，改为询问强制删除；按原选项重试后本地与跟踪的远端分支都被删除。
    @Test("未合并分支删除失败后按原选项强制删除")
    func forceDeletionOffer() async throws {
        let (root, directory, bare) = try await Self.repository()
        defer { try? FileManager.default.removeItem(at: root) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = Self.runner(at: location.path)
        _ = try await runner.run(["switch", "-q", "-c", "topic"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "topic"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "topic"])

        // 已推送的提交算作合并到上游，再加一个只在本地的提交，普通删除才会失败
        _ = try await runner.run(["commit", "--allow-empty", "-m", "local only"])
        _ = try await runner.run(["switch", "-q", "main"])

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        var requests: [ReferenceRequest] = []
        session.onReferenceRequest = { requests.append($0) }
        session.display(location)
        session.refresh()
        await session.refreshTask?.value

        #expect(session.deleteBranches(["refs/heads/topic"], force: false, deletingUpstream: true))
        await session.writeTask?.value
        await session.refreshTask?.value

        guard case .forceDelete(let offer, let failure) = try #require(requests.last) else {
            Issue.record("未合并分支的删除应改为询问强制删除")
            return
        }

        #expect(offer.branches == ["refs/heads/topic"])
        #expect(offer.deletingUpstream)
        #expect(failure.details.lowercased().contains("not fully merged"))
        #expect(session.failure == nil)

        session.deleteBranches(offer.branches, force: true, deletingUpstream: offer.deletingUpstream)
        await session.writeTask?.value
        await session.refreshTask?.value

        let local = String(decoding: try await runner.run(["for-each-ref", "--format=%(refname)"]), as: UTF8.self)
        let remote = String(decoding: try await Self.runner(at: bare).run(["for-each-ref"]), as: UTF8.self)
        #expect(!local.contains("topic"))
        #expect(!remote.contains("refs/heads/topic"))
        RepositoryActivities.shared.items.removeAll { $0.repository == location }
    }

    /// 只有落后于上游、没有自己提交的非当前分支可以快进；快进后与上游相同。
    @Test("快进的可用条件")
    func fastForwardAvailability() async throws {
        let (root, directory, _) = try await Self.repository()
        defer { try? FileManager.default.removeItem(at: root) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = Self.runner(at: location.path)
        _ = try await runner.run(["branch", "behind"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "behind"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "ahead"])
        _ = try await runner.run(["push", "-q", "origin", "HEAD:refs/heads/behind"])

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        session.display(location)
        session.refresh()
        await session.refreshTask?.value
        try await Self.wait { session.history.divergence["refs/heads/behind"] != nil }

        let behind = try #require(session.history.branches.first { $0.id == "refs/heads/behind" })
        let main = try #require(session.history.branches.first { $0.id == "refs/heads/main" })
        #expect(session.canFastForward(behind))
        #expect(!session.canFastForward(main))

        session.fastForward(behind)
        await session.writeTask?.value
        await session.refreshTask?.value

        let references = RepositoryReferences(runner: runner)
        #expect(try await references.resolve("refs/heads/behind") == references.resolve("refs/remotes/origin/behind"))
        RepositoryActivities.shared.items.removeAll { $0.repository == location }
    }

    /// 远端视图记下所选远端；本机路径的远端换算不出网页地址，报告原因与地址。
    @Test("远端视图与在浏览器中打开的失败说明")
    func remoteViewAndBrowser() async throws {
        let (root, directory, bare) = try await Self.repository()
        defer { try? FileManager.default.removeItem(at: root) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = Self.runner(at: location.path)
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }
        session.display(location)

        session.showRemote("origin")
        #expect(session.activeView == .remote)
        #expect(session.selectedRemote == "origin")
        #expect(!session.activeView.supportsSearch)

        session.openRemoteInBrowser("origin")
        try await Self.wait { !failures.isEmpty }

        #expect(failures.first?.title == AppLocalization.text("remote.error.browser"))
        #expect(failures.first?.details == bare)
        #expect(failures.first?.kind == .repository)
    }
}

// MARK: - Helpers

extension ReferenceSessionTests {
    /// 带一个已推送 main 的裸仓库远端的工作区；裸仓库与工作区放在同一个临时目录下，测试结束整体删除。
    static func repository() async throws -> (root: URL, directory: URL, bare: String) {
        let root = FileManager.default.temporaryDirectory.appending(path: "spooky-references-" + UUID().uuidString)
        let directory = root.appending(path: "仓 库")
        let bare = root.appending(path: "remote.git").path
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let runner = runner(at: directory.path)
        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        _ = try await runner.run(["config", "--local", "commit.gpgSign", "false"])
        _ = try await runner.run(["init", "-q", "--bare", bare])
        _ = try await runner.run(["remote", "add", "origin", bare])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "main"])
        return (root, directory, bare)
    }

    /// 忽略系统与用户全局配置的执行器。
    static func runner(at path: String) -> GitRunner {
        GitRunner(
            location: .local(path: path),
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )
    }

    /// 等到条件成立，最多 30 秒。
    static func wait(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))

        while !condition(), .now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
