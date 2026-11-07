import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Amend

/// 修补旧提交不经确认：干净工作区直接停到目标；有本地改动时先询问储藏，三个按钮各自的结果。
extension RewriteSessionTests {
    /// 干净工作区直接停到目标本身；暂存修补后结束编辑，目标带上修补，后面的提交照原样重放。
    @Test("修补旧提交：干净工作区直接开始")
    func amendCleanWorkingCopy() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        var requests: [RewriteRequest] = []
        var stashRequests: [StashRequest] = []
        session.onRewriteRequest = { requests.append($0) }
        session.onStashRequest = { stashRequests.append($0) }

        session.requestRewrite(.amend(commits[1]))
        try await FileViewsTests.wait { session.context?.progress?.stopsForEdit ?? false }
        await settle(session)

        // 停在目标本身，不撤回到父提交，也没有弹确认或储藏询问
        #expect(session.status?.branch.oid == commits[1])
        #expect(session.isWorkingCopyClean)
        #expect(requests.isEmpty && stashRequests.isEmpty)

        try Data("补充\n".utf8).write(to: directory.appending(path: "二.txt"))
        await reload(session)
        session.stageAll(staged: true)
        await settle(session)

        session.finishOperation("continue")
        await settle(session)
        try await FileViewsTests.wait { session.context?.operation == nil }

        let runner = try #require(session.runner)
        let amended = try await runner.run(["show", "HEAD~1:二.txt"])

        #expect(try await subjects(session) == ["第三个", "第二个", "第一个"])
        #expect(String(decoding: amended, as: UTF8.self) == "补充\n")
    }

    /// 有本地改动时先询问储藏，对话框不提供完成后恢复；Abort 只关闭对话框，HEAD、工作区与储藏列表都不变。
    @Test("修补旧提交：有本地改动时询问，Abort 不改任何东西")
    func amendAbort() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        let pending = try await requestAmend(commits[0], in: session, directory: directory)

        #expect(pending.asksBeforeStart)
        #expect(!session.isWriting)
        #expect(session.status?.branch.oid == commits[2])
        #expect(try Data(contentsOf: directory.appending(path: "二.txt")) == Data("本地\n".utf8))
        #expect(try await stashCount(session) == 0)
    }

    /// Do Not Stash 不储藏地开始：Git 因本地改动拒绝时只报告这一次，不再询问，仓库保持原样。
    @Test("修补旧提交：Do Not Stash 只报告一次 Git 的错误")
    func amendWithoutStash() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        var failures: [AppFailure] = []
        var stashRequests: [StashRequest] = []
        let pending = try await requestAmend(commits[0], in: session, directory: directory)
        session.onFailure = { failures.append($0) }
        session.onStashRequest = { stashRequests.append($0) }

        session.declineAutoStash(pending)
        await settle(session)

        #expect(failures.count == 1)
        #expect(stashRequests.isEmpty)
        #expect(session.context?.operation == nil)
        #expect(session.status?.branch.oid == commits[2])
        #expect(try Data(contentsOf: directory.appending(path: "二.txt")) == Data("本地\n".utf8))
    }

    /// Stash Changes 先储藏再停到目标；停下时与结束编辑后储藏都保留，改动不自动回到工作区。
    @Test("修补旧提交：Stash Changes 后停到目标，储藏一直保留")
    func amendAfterStash() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        let pending = try await requestAmend(commits[0], in: session, directory: directory)

        #expect(session.performAutoStash(pending, message: "修补前", reapply: false))
        await settle(session)
        try await FileViewsTests.wait { session.context?.progress?.stopsForEdit ?? false }

        #expect(session.status?.branch.oid == commits[0])
        #expect(session.isWorkingCopyClean)
        #expect(try await stashCount(session) == 1)

        session.finishOperation("continue")
        await settle(session)
        try await FileViewsTests.wait { session.context?.operation == nil }

        #expect(try await subjects(session) == ["第三个", "第二个", "第一个"])
        #expect(try Data(contentsOf: directory.appending(path: "二.txt")) == Data("第二个\n".utf8))
        #expect(try await stashCount(session) == 1)
    }
}

// MARK: - Helpers

extension RewriteSessionTests {
    /// 在已跟踪的文件里留下未暂存的改动，再请求修补旧提交，取回储藏询问。
    private func requestAmend(
        _ commit: String,
        in session: RepositorySession,
        directory: URL
    ) async throws -> AutoStashRequest {
        var stashRequests: [StashRequest] = []
        session.onStashRequest = { stashRequests.append($0) }

        try Data("本地\n".utf8).write(to: directory.appending(path: "二.txt"))
        await reload(session)

        session.requestRewrite(.amend(commit))
        try await FileViewsTests.wait { !stashRequests.isEmpty }

        guard case .autoStash(let pending) = try #require(stashRequests.first) else {
            throw RewriteError.invalidSelection
        }

        return pending
    }

    /// 手动刷新一次，让会话读到刚写入的文件。
    private func reload(_ session: RepositorySession) async {
        session.refresh(full: true)
        await session.waitForRefresh()
    }

    /// 仓库里的储藏数。
    private func stashCount(_ session: RepositorySession) async throws -> Int {
        let output = try await try #require(session.runner).run(["stash", "list", "-z"])
        return String(decoding: output, as: UTF8.self).split(separator: "\0").count
    }
}
