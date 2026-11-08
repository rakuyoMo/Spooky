import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Amend

/// 修补旧提交不经确认：干净工作区直接停到目标，停下后可在提交区修补，Edit 撤下提交后不能修补；有本地改动时先询问储藏，三个按钮各自的结果。
extension RewriteSessionTests {
    /// 干净工作区直接停到目标本身，不弹确认或储藏询问；停下后在提交区打开修补，信息换成目标的信息；
    /// 改了内容与信息再修补，修补结果还能再次修补；结束编辑后目标带上两次修补，后面的提交照原样重放。
    @Test("修补旧提交：干净工作区直接停到目标，在提交区修补后结束编辑")
    func amendInCommitArea() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        var requests: [RewriteRequest] = []
        var stashRequests: [StashRequest] = []
        session.onRewriteRequest = { requests.append($0) }
        session.onStashRequest = { stashRequests.append($0) }

        try await stopForAmend(commits[1], in: session)

        // 停在目标本身，不撤回到父提交，也没有弹确认或储藏询问
        #expect(session.status?.branch.oid == commits[1])
        #expect(session.isWorkingCopyClean)
        #expect(requests.isEmpty && stashRequests.isEmpty)

        // edit 停顿时提交区可以修补，载入的是停下时 HEAD 的信息
        #expect(session.canAmend)

        session.setAmend(true)
        #expect(session.amend && session.commitSubject == "第二个")

        try Data("补充\n".utf8).write(to: directory.appending(path: "二.txt"))
        await reload(session)
        session.stageAll(staged: true)
        await settle(session)

        try await commit("第二个（修补）", body: "修补的正文", in: session)

        // 修补改写了停下时的 HEAD，仍停在 edit 步，修补随这次提交结束
        await until { session.context?.lastMessage == "第二个（修补）\n\n修补的正文" }

        #expect(session.context?.progress?.stopsForEdit ?? false)
        #expect(session.status?.branch.oid != commits[1])
        #expect(!session.amend)

        // 修补结果仍可再次修补，载入的是第一次修补后的信息
        #expect(session.canAmend)

        session.setAmend(true)
        #expect(session.amend && session.commitSubject == "第二个（修补）")

        try await commit("第二个（再次修补）", in: session)
        await continueOperation(in: session)

        let runner = try #require(session.runner)
        let message = try await runner.run(["log", "-1", "--format=%B", "HEAD~1"])
        let amended = try await runner.run(["show", "HEAD~1:二.txt"])

        #expect(try await subjects(session) == ["第三个", "第二个（再次修补）", "第一个"])
        #expect(String(decoding: amended, as: UTF8.self) == "补充\n")

        #expect(
            String(decoding: message, as: UTF8.self).trimmingCharacters(in: .newlines)
                == "第二个（再次修补）\n\n修补的正文"
        )
    }

    /// Edit 撤下提交后 HEAD 回到它的父提交，那不是用户选中的提交，不能修补；停顿中新建的提交可以修补，结束编辑后新历史用修补后的信息。
    @Test("编辑提交：停下时不能修补，停顿中新建的提交可以修补")
    func amendDuringEditStop() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        let plan = try await requestPlan(.edit(commits[1]), in: session)
        #expect(session.perform(plan))
        await settle(session)

        // 停顿与停下的位置由会话在刷新后另行读取
        await until { session.context?.progress?.stopsForEdit ?? false }

        #expect(session.status?.branch.oid == commits[0])
        #expect(!session.canAmend)

        session.setAmend(true)
        #expect(!session.amend)

        // 停顿中新建一个提交，它可以修补，修补载入它的信息
        session.stageAll(staged: true)
        await settle(session)

        try await commit("第二个（拆开）", in: session)

        await until {
            session.canAmend && session.context?.lastMessage == "第二个（拆开）"
        }

        session.setAmend(true)
        #expect(session.amend && session.commitSubject == "第二个（拆开）")

        try await commit("第二个（拆开后修补）", in: session)
        await continueOperation(in: session)

        #expect(try await subjects(session) == ["第三个", "第二个（拆开后修补）", "第一个"])
    }

    /// edit 停顿里打开的修补只针对停顿中的提交：中止后退出修补，信息回到进入修补前的草稿；
    /// 修补打开后 HEAD 被重置到停下的提交的父提交：修补退出、草稿恢复，之后的提交是新提交，父提交不被改写。
    @Test("修补旧提交：中止或 HEAD 回到父提交后退出修补")
    func amendEndsWithEditStop() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        let runner = try #require(session.runner)

        // 中止：退出修补，草稿回来，HEAD 回到原来的分支顶端
        try await openAmend(commits[1], over: "草稿", in: session)

        session.finishOperation("abort")
        await settle(session)
        await until { session.context?.operation == nil }

        #expect(!session.amend)
        #expect(session.commitSubject == "草稿")
        #expect(session.status?.branch.oid == commits[2])

        // 在会话之外撤下停下的提交，HEAD 回到它的父提交，等会话读到父提交的状态与信息
        try await openAmend(commits[1], over: "草稿", in: session)

        _ = try await runner.run(["reset", "-q", "HEAD^", "--"])
        await reload(session)

        await until {
            session.status?.branch.oid == commits[0]
                && session.context?.lastMessage == "第一个"
        }

        #expect(!session.amend && !session.canAmend)
        #expect(session.commitSubject == "草稿")

        // 用恢复的草稿提交撤下的改动，得到新提交，父提交保持原样
        session.stageAll(staged: true)
        await settle(session)

        try await commit(nil, in: session)
        await continueOperation(in: session)

        #expect(try await subjects(session) == ["第三个", "草稿", "第一个"])
        #expect(try await RepositoryRewrite(runner: runner).resolve("HEAD~2") == commits[0])
    }

    /// 有本地改动时先询问储藏，对话框不提供完成后恢复；Abort 只关闭对话框，什么都不改；
    /// Do Not Stash 不储藏地开始，Git 因本地改动拒绝时只报告这一次、不再询问；
    /// Stash Changes 先储藏再停到目标，停下时与结束编辑后储藏都保留，改动不自动回到工作区。
    @Test("修补旧提交：有本地改动时的 Abort、Do Not Stash 与 Stash Changes")
    func amendWithLocalChanges() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        let file = directory.appending(path: "二.txt")
        let declined = try await requestAmend(commits[0], in: session, directory: directory)

        // Abort：询问时还没有开始写，HEAD、工作区与储藏列表都不变
        #expect(declined.asksBeforeStart)
        #expect(!session.isWriting)
        #expect(session.status?.branch.oid == commits[2])
        #expect(try Data(contentsOf: file) == Data("本地\n".utf8))
        #expect(try await stashCount(session) == 0)

        // Do Not Stash：Git 拒绝，只报告一次，仓库保持原样
        var failures: [AppFailure] = []
        var stashRequests: [StashRequest] = []
        session.onFailure = { failures.append($0) }
        session.onStashRequest = { stashRequests.append($0) }

        session.declineAutoStash(declined)
        await settle(session)

        #expect(failures.count == 1)
        #expect(stashRequests.isEmpty)
        #expect(session.context?.operation == nil)
        #expect(session.status?.branch.oid == commits[2])
        #expect(try Data(contentsOf: file) == Data("本地\n".utf8))

        // Stash Changes：储藏后停到目标，结束编辑后储藏仍在
        let pending = try await requestAmend(commits[0], in: session, directory: directory)

        #expect(session.performAutoStash(pending, message: "修补前", reapply: false))
        await settle(session)
        await until { session.context?.progress?.stopsForEdit ?? false }

        #expect(session.status?.branch.oid == commits[0])
        #expect(session.isWorkingCopyClean)
        #expect(try await stashCount(session) == 1)

        await continueOperation(in: session)

        #expect(try await subjects(session) == ["第三个", "第二个", "第一个"])
        #expect(try Data(contentsOf: file) == Data("第二个\n".utf8))
        #expect(try await stashCount(session) == 1)
    }
}

// MARK: - Helpers

extension RewriteSessionTests {
    /// 工作区干净时请求修补旧提交，等到停在目标的 edit 步。
    private func stopForAmend(_ commit: String, in session: RepositorySession) async throws {
        session.requestRewrite(.amend(commit))

        // 计划在后台任务里完成，停顿由会话在刷新后另行读取
        await until { session.context?.progress?.stopsForEdit ?? false }
        await settle(session)
    }

    /// 停到目标后先写一份草稿，再在提交区打开修补，信息换成目标的信息。
    private func openAmend(
        _ commit: String,
        over draft: String,
        in session: RepositorySession
    ) async throws {
        try await stopForAmend(commit, in: session)

        session.commitSubject = draft
        session.setAmend(true)

        #expect(session.amend && session.commitSubject == "第二个")
    }

    /// 在提交区提交；`subject` 为 nil 时用提交区现有的信息。
    private func commit(
        _ subject: String?,
        body: String? = nil,
        in session: RepositorySession
    ) async throws {
        if let subject {
            session.commitSubject = subject
        }

        if let body {
            session.commitBody = body
        }

        session.commit()

        await settle(session)
        await session.commitResetTask?.value
    }

    /// 继续进行中的改写，等它结束。
    private func continueOperation(in session: RepositorySession) async {
        session.finishOperation("continue")

        await settle(session)
        await until { session.context?.operation == nil }
    }

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

        // 计划在后台任务里完成，完成后在主线程询问储藏
        session.requestRewrite(.amend(commit))
        await until { !stashRequests.isEmpty }

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
        let runner = try #require(session.runner)
        let output = try await runner.run(["stash", "list", "-z"])

        return String(decoding: output, as: UTF8.self).split(separator: "\0").count
    }
}
