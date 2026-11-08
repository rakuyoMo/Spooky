import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 提交体验在会话层的行为：注释行询问、提交后的重置、跳过钩子、提交人与身份档案、补全候选。
extension RepositorySessionTests {
    /// 注释行先询问再提交：选择删除时去掉注释，删除后为空时只能保留注释；取消询问不提交、不清空草稿；
    /// `core.commentChar=auto` 时 Git 不会把任何一行当注释，提交不询问，行首的 # 原样保留。
    @Test("注释行按询问结果提交，auto 注释字符不询问")
    func commentPrompt() async throws {
        let (session, runner, directory) = try await commitSession()

        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        var prompts: [Bool] = []
        var decision: CommentHandling? = nil

        session.commitResetDelay = .zero
        session.onCommentPrompt = { empty, decide in
            prompts.append(empty)

            if let decision {
                decide(decision)
            }
        }

        // 取消询问：没有提交，草稿保留
        try await stageChange(in: session, directory: directory, content: "one")
        session.commitSubject = "标题"
        session.commitBody = "# 注释\n正文"
        session.commit()

        #expect(prompts == [false])
        #expect(session.writeTask == nil)
        #expect(session.commitBody == "# 注释\n正文")

        decision = .remove
        await commitAndReset(session)
        #expect(try await lastMessage(runner) == "标题\n\n正文")

        // 去掉注释后为空时询问的是保留注释提交
        decision = .keep
        try await stageChange(in: session, directory: directory, content: "two")
        session.commitSubject = "# 只有注释"
        await commitAndReset(session)

        #expect(prompts == [false, false, true])
        #expect(try await lastMessage(runner) == "# 只有注释")

        // auto 注释字符：读到新配置后提交不再询问
        _ = try await runner.run(["config", "--local", "core.commentChar", "auto"])
        try await stageChange(in: session, directory: directory, content: "auto")
        await reloadConfiguration(session)

        #expect(session.commitConfiguration?.commentPrefix == nil)

        session.commitSubject = "#42 修复"
        await commitAndReset(session)

        #expect(prompts.count == 3)
        #expect(try await lastMessage(runner) == "#42 修复")
    }

    /// 仓库启用提交钩子时才提供跳过，勾选后失败的钩子不再拦截；提交成功后信息先保留 `commitResetDelay`、期间不能再提交，
    /// 随后与跳过钩子一起清空；关闭仓库时不等待，已提交的信息不存进视图状态，跳过钩子与提交配置一起清除。
    @Test("跳过钩子与提交成功后延迟清空信息")
    func delayedMessageReset() async throws {
        let (session, runner, directory) = try await commitSession()

        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        #expect(!(session.commitConfiguration?.hasCommitHooks ?? true))

        let hook = directory.appending(path: ".git/hooks/commit-msg")
        try FileManager.default.createDirectory(
            at: hook.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\nexit 1\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
        try await stageChange(in: session, directory: directory, content: "hooked")
        await reloadConfiguration(session)

        #expect(session.commitConfiguration?.hasCommitHooks ?? false)

        // 保留时长到了以后，信息与跳过钩子一起清空，提交区解除锁定
        session.commitSubject = "跳过钩子"
        session.skipHooks = true
        session.commit()
        await session.writeTask?.value
        await session.commitResetTask?.value

        #expect(try await lastMessage(runner) == "跳过钩子")
        #expect(session.commitResetTask == nil)
        #expect(session.commitSubject.isEmpty)
        #expect(!session.skipHooks)

        try await closeWhileWaiting(session, directory: directory)
    }

    /// 提交区的提交人取仓库所在机器上生效的 user.name 与 user.email，没有配置时留空；
    /// 选用档案前说明改写的配置与仓库，确认后刷新的身份与签名配置来自写入的值。
    @Test("提交人来自身份配置，选用身份档案改写本仓库的提交人")
    func committerIdentity() async throws {
        let (session, runner, directory) = try await commitSession()

        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        #expect(session.committer == ("Spooky Test", "spooky@example.invalid"))

        var messages: [String] = []
        session.onConfirm = { request in
            messages.append(request.message)
            request.action()
        }

        session.applyProfile(
            UserProfile(title: "工作", name: "工作 名字", email: "work@example.invalid", signingKey: "~/.ssh/work.pub")
        )
        await session.writeTask?.value
        await session.waitForRefresh()
        await reloadConfiguration(session)

        #expect(messages.count == 1)
        #expect(messages.first?.contains("user.signingkey") ?? false)
        #expect(messages.first?.contains(directory.lastPathComponent) ?? false)
        #expect(session.committer == ("工作 名字", "work@example.invalid"))
        #expect(session.commitConfiguration?.signingFormat == .ssh)

        _ = try await runner.run(["config", "--local", "--unset", "user.name"])
        _ = try await runner.run(["config", "--local", "--unset", "user.email"])
        await reloadConfiguration(session)

        #expect(session.committer == ("", ""))
    }

    /// 补全的提交来自最近历史，fixup 插入提交标题，文件补全来自改动列表。
    @Test("补全候选来自最近提交与改动文件")
    func completionSources() async throws {
        let (session, _, directory) = try await commitSession()

        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        try await stageChange(in: session, directory: directory, content: "base")
        session.commitSubject = "修复 登录"
        session.commit()
        await session.writeTask?.value
        await session.waitForRefresh()

        try Data("changed".utf8).write(to: directory.appending(path: "改动 [*].txt"))
        session.refresh(full: true)
        await session.waitForRefresh()

        let empty = NSRange(location: 0, length: 0)
        let commits = await session.completions(for: .commit(query: "", range: empty))
        let fixups = await session.completions(for: .fixup(query: "登录", range: empty))
        let files = await session.completions(for: .file(query: "改动", range: empty))

        #expect(commits.count == 1)
        #expect(commits.first?.insertion.count == 8)
        #expect(fixups.map(\.insertion) == ["修复 登录"])
        #expect(files.map(\.insertion) == ["改动 [*].txt"])
    }
}

// MARK: - Steps

extension RepositorySessionTests {
    /// 保留时长改长，写操作收尾时一定还在等待：提交已经成功，信息仍在，提交区处于锁定；
    /// 等待期间关闭仓库立即清空，切回时不会恢复已提交的信息。
    private func closeWhileWaiting(_ session: RepositorySession, directory: URL) async throws {
        session.commitResetDelay = .seconds(3600)

        var atFinish: (subject: String, canCommit: Bool, waiting: Bool)? = nil
        session.onWriteFinished = { [weak session] _ in
            guard let session else { return }

            atFinish = (session.commitSubject, session.canCommit, session.commitResetTask != nil)
        }

        try await stageChange(in: session, directory: directory, content: "close")
        session.commitSubject = "关闭前提交"
        session.skipHooks = true
        session.commit()
        await session.writeTask?.value

        let finished = try #require(atFinish)

        #expect(finished.subject == "关闭前提交")
        #expect(!finished.canCommit)
        #expect(finished.waiting)

        let location = try #require(session.repository)
        session.close()

        #expect(session.commitResetTask == nil)
        #expect(!session.skipHooks)
        #expect(session.commitConfiguration == nil)

        session.display(location)
        #expect(session.commitSubject.isEmpty)
    }
}

// MARK: - Helpers

extension RepositorySessionTests {
    /// 打开临时仓库，等第一次完整刷新与提交配置的读取结束。
    func commitSession() async throws -> (RepositorySession, GitRunner, URL) {
        let directory = try FileViewsTests.temporaryDirectory()
        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)

        let session = RepositorySession(makeRunner: { _ in runner })
        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()
        await session.configurationTask?.value

        return (session, runner, directory)
    }

    /// 写入文件并经会话暂存全部改动。
    func stageChange(in session: RepositorySession, directory: URL, content: String) async throws {
        try Data(content.utf8).write(to: directory.appending(path: "file.txt"))
        session.refresh(full: true)
        await session.waitForRefresh()

        session.stageAll(staged: true)
        await session.writeTask?.value
        await session.waitForRefresh()
    }

    /// 提交当前信息，等写入、随后的刷新与信息重置都结束。
    private func commitAndReset(_ session: RepositorySession) async {
        session.commit()
        await session.writeTask?.value
        await session.waitForRefresh()
        await session.commitResetTask?.value
    }

    /// 重新读取提交配置并等它读完。
    ///
    /// 读取进行中时新的请求会被丢掉：先等正在进行的读取结束，再发起一次从现在开始的读取。
    private func reloadConfiguration(_ session: RepositorySession) async {
        await session.configurationTask?.value
        session.loadCommitConfiguration()
        await session.configurationTask?.value
    }

    /// 最近一次提交的完整信息。
    func lastMessage(_ runner: GitRunner) async throws -> String {
        String(decoding: try await runner.run(["log", "-1", "--format=%B"]), as: UTF8.self)
            .trimmingCharacters(in: .newlines)
    }
}
