import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - RewriteSessionTests

/// 会话层的改写操作：计划后请求确认、edit 停顿时的提交与继续、改信息的注释行处理，以及被本地改动挡住时转为询问储藏。
@MainActor
struct RewriteSessionTests {
    /// edit 停下后提交区可以提交撤回的改动，横幅的继续把变基做完。
    @Test("编辑提交：停顿、提交与继续")
    func editStop() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        let plan = try await requestPlan(.edit(commits[1]), in: session)
        #expect(session.perform(plan))
        await settle(session)
        try await FileViewsTests.wait { session.context?.progress?.stopsForEdit ?? false }

        #expect(session.status?.branch.oid == commits[0])

        session.stageAll(staged: true)
        await settle(session)
        session.commitSubject = "第二个（拆开）"
        session.commit()
        await settle(session)
        try await FileViewsTests.wait { session.status?.branch.oid != commits[0] && session.context?.operation == .rebase }

        session.finishOperation("continue")
        await settle(session)
        try await FileViewsTests.wait { session.context?.operation == nil }

        #expect(try await subjects(session) == ["第三个", "第二个（拆开）", "第一个"])
    }

    /// 改信息时注释行按提交区的规则询问；选择删除后提交里不再有注释行。
    @Test("改写提交信息时处理注释行")
    func rewordComments() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        var prompts = 0
        session.onCommentPrompt = { _, decide in
            prompts += 1
            decide(.remove)
        }

        session.requestReword(commits[0])
        let plan = try await waitForRequest(in: session)
        guard case .reword(let reword) = plan else {
            Issue.record("改信息应呈现编辑 sheet")
            return
        }

        session.reword(reword, subject: "新的第一个", body: "# 注释\n正文")
        await settle(session)

        let first = try await RepositoryRewrite(runner: try #require(session.runner)).resolve("HEAD~2")
        let message = try await RepositoryRewrite(runner: try #require(session.runner)).commits([first]).first?.message
        #expect(prompts == 1)
        #expect(message?.trimmingCharacters(in: .newlines) == "新的第一个\n\n正文")
    }

    /// 已跟踪的文件有未暂存的改动时，删除提交被挡住，转为询问是否先储藏；选择储藏后完成并恢复改动。
    @Test("被本地改动挡住的改写转为 Auto Stash")
    func autoStashRewrite() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        var stashRequests: [StashRequest] = []
        var failures: [AppFailure] = []
        session.onStashRequest = { stashRequests.append($0) }
        session.onFailure = { failures.append($0) }

        try Data("本地\n".utf8).write(to: directory.appending(path: "一 *.txt"))
        let plan = try await requestPlan(.drop([commits[1]]), in: session)
        session.perform(plan)
        await settle(session)

        #expect(failures.isEmpty)
        guard case .autoStash(let pending) = try #require(stashRequests.first) else {
            Issue.record("应转为询问是否储藏")
            return
        }

        session.performAutoStash(pending, message: "auto", reapply: true)
        await settle(session)

        #expect(try await subjects(session) == ["第三个", "第一个"])
        #expect(try Data(contentsOf: directory.appending(path: "一 *.txt")) == Data("本地\n".utf8))
    }

    /// 反转与摘取按历史列表的顺序排列：反转从新到旧，摘取从旧到新。
    @Test("反转多个提交")
    func revertMany() async throws {
        let (session, directory, commits) = try await makeSession()
        defer { cleanUp(session, directory) }

        try await FileViewsTests.wait { session.history.commits.count == 3 }
        #expect(session.revert([commits[1], commits[2]], options: PickOptions()))
        await settle(session)

        #expect(try await subjects(session).prefix(2) == ["Revert \"第二个\"", "Revert \"第三个\""])
    }
}

// MARK: - Helpers

extension RewriteSessionTests {
    /// 带三个提交的隔离仓库与已完成首次刷新的会话；返回从旧到新的提交。
    private func makeSession() async throws -> (RepositorySession, URL, [String]) {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-rewrite-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)

        let location = RepositoryLocation.local(path: directory.path)
        let runner = GitRunner(
            location: location,
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )

        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        _ = try await runner.run(["config", "--local", "commit.gpgSign", "false"])

        var commits: [String] = []

        for (file, subject) in [("一 *.txt", "第一个"), ("二.txt", "第二个"), ("三.txt", "第三个")] {
            try Data("\(subject)\n".utf8).write(to: directory.appending(path: file))
            _ = try await runner.run(["add", "--all"])
            _ = try await runner.run(["commit", "-q", "-m", subject])
            commits.append(try await RepositoryRewrite(runner: runner).resolve("HEAD"))
        }

        let session = RepositorySession(makeRunner: { _ in runner })
        session.display(location)
        session.refresh()
        await session.waitForRefresh()
        return (session, directory, commits)
    }

    /// 计划一个动作并取回确认请求里的计划。
    private func requestPlan(_ action: RewriteAction, in session: RepositorySession) async throws -> RewritePlan {
        session.requestRewrite(action)

        guard case .confirm(let plan) = try await waitForRequest(in: session) else {
            throw RewriteError.invalidSelection
        }

        return plan
    }

    /// 等待会话发出下一个改写请求。
    private func waitForRequest(in session: RepositorySession) async throws -> RewriteRequest {
        var received: RewriteRequest?
        session.onRewriteRequest = { received = $0 }

        try await FileViewsTests.wait { received != nil }
        return try #require(received)
    }

    /// 等待写操作与随后的完整刷新结束。
    private func settle(_ session: RepositorySession) async {
        await session.writeTask?.value
        await session.waitForRefresh()
    }

    /// 当前分支从新到旧的提交标题。
    private func subjects(_ session: RepositorySession) async throws -> [String] {
        let runner = try #require(session.runner)
        let output = try await runner.run(["log", "-z", "--format=%s"])
        return String(decoding: output, as: UTF8.self).split(separator: "\0").map(String.init)
    }

    /// 关闭会话并删除临时仓库。
    private func cleanUp(_ session: RepositorySession, _ directory: URL) {
        session.close()
        try? FileManager.default.removeItem(at: directory)
    }
}
