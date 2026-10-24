import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 提交体验在会话层的行为：注释行询问、身份档案、跳过钩子与补全候选。
extension RepositorySessionTests {
    /// 注释行先询问再提交：选择删除时去掉注释，删除后为空时只能保留注释；取消询问不提交、不清空草稿。
    @Test("注释行按询问结果提交")
    func commentPrompt() async throws {
        let (session, runner, directory) = try await commitSession()
        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        var prompts: [Bool] = []
        var decision: CommentHandling? = nil
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
        session.commit()
        await session.writeTask?.value
        await session.refreshTask?.value
        await session.commitResetTask?.value
        #expect(try await lastMessage(runner) == "标题\n\n正文")

        // 去掉注释后为空时询问的是保留注释提交
        decision = .keep
        try await stageChange(in: session, directory: directory, content: "two")
        session.commitSubject = "# 只有注释"
        session.commit()
        await session.writeTask?.value
        await session.refreshTask?.value
        #expect(prompts == [false, false, true])
        #expect(try await lastMessage(runner) == "# 只有注释")
    }

    /// 提交成功后信息先保留 0.3 秒、期间不能再提交，随后与修补和跳过钩子一起清空；关闭仓库时不等待，已提交的信息不存进视图状态。
    @Test("提交成功后延迟清空信息")
    func delayedMessageReset() async throws {
        let (session, _, directory) = try await commitSession()
        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        // 写操作收尾时提交已经成功，信息仍在，提交区处于锁定
        var atFinish: (subject: String, canCommit: Bool, waiting: Bool)? = nil
        session.onWriteFinished = { [weak session] _ in
            guard let session else { return }

            atFinish = (session.commitSubject, session.canCommit, session.commitResetTask != nil)
        }

        try await stageChange(in: session, directory: directory, content: "delay")
        session.commitSubject = "延迟清空"
        session.skipHooks = true
        session.commit()
        await session.writeTask?.value

        let finished = try #require(atFinish)
        #expect(finished.subject == "延迟清空")
        #expect(!finished.canCommit)
        #expect(finished.waiting)

        await session.commitResetTask?.value
        #expect(session.commitResetTask == nil)
        #expect(session.commitSubject.isEmpty)
        #expect(!session.skipHooks)

        // 等待期间关闭仓库：立即清空，切回时不会恢复已提交的信息
        let location = try #require(session.repository)
        try await stageChange(in: session, directory: directory, content: "close")
        session.commitSubject = "关闭前提交"
        session.commit()
        await session.writeTask?.value
        session.close()
        #expect(session.commitResetTask == nil)

        session.display(location)
        #expect(session.commitSubject.isEmpty)
    }

    /// `core.commentChar=auto` 时 Git 不会把任何一行当注释，提交不询问，行首的 # 原样保留。
    @Test("auto 注释字符不询问")
    func autoCommentCharacter() async throws {
        let (session, runner, directory) = try await commitSession()
        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        var prompts = 0
        session.onCommentPrompt = { _, _ in prompts += 1 }
        _ = try await runner.run(["config", "--local", "core.commentChar", "auto"])
        try await stageChange(in: session, directory: directory, content: "auto")
        try await waitForConfiguration(session) { $0.commentPrefix == nil }

        session.commitSubject = "#42 修复"
        session.commit()
        await session.writeTask?.value
        await session.refreshTask?.value
        #expect(prompts == 0)
        #expect(try await lastMessage(runner) == "#42 修复")
    }

    /// 选用档案前说明改写的配置与仓库，确认后刷新的身份与签名配置来自写入的值。
    @Test("选用身份档案改写本仓库的提交人")
    func applyProfile() async throws {
        let (session, _, directory) = try await commitSession()
        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        var messages: [String] = []
        session.onConfirm = { _, message, action, _ in
            messages.append(message)
            action()
        }

        session.applyProfile(
            UserProfile(title: "工作", name: "工作 名字", email: "work@example.invalid", signingKey: "~/.ssh/work.pub")
        )
        await session.writeTask?.value

        let deadline = ContinuousClock.now.advanced(by: .seconds(300))
        while session.commitConfiguration?.userEmail != "work@example.invalid", .now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(messages.count == 1)
        #expect(messages.first?.contains("user.signingkey") ?? false)
        #expect(messages.first?.contains(directory.lastPathComponent) ?? false)
        #expect(session.commitConfiguration?.userName == "工作 名字")
        #expect(session.commitConfiguration?.signingFormat == .ssh)
    }

    /// 仓库启用提交钩子时才提供跳过；勾选后失败的钩子不再拦截，切换仓库后选项清除。
    @Test("跳过钩子只在有钩子时可用")
    func skipHooks() async throws {
        let (session, runner, directory) = try await commitSession()
        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        #expect(!(session.commitConfiguration?.hasCommitHooks ?? true))

        let hook = directory.appending(path: ".git/hooks/commit-msg")
        try FileManager.default.createDirectory(at: hook.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 1\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
        try await stageChange(in: session, directory: directory, content: "hooked")
        try await waitForConfiguration(session) { $0.hasCommitHooks }

        session.commitSubject = "跳过钩子"
        session.skipHooks = true
        session.commit()
        await session.writeTask?.value
        await session.refreshTask?.value
        #expect(try await lastMessage(runner) == "跳过钩子")

        session.close()
        #expect(!session.skipHooks)
        #expect(session.commitConfiguration == nil)
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
        await session.refreshTask?.value
        try Data("changed".utf8).write(to: directory.appending(path: "改动 [*].txt"))
        session.refresh(full: true)
        await session.refreshTask?.value

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

// MARK: - Helpers

extension RepositorySessionTests {
    /// 打开临时仓库并完成第一次完整刷新。
    private func commitSession() async throws -> (RepositorySession, GitRunner, URL) {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-commit-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await initializeRepository(at: location)
        let session = RepositorySession(makeRunner: { _ in runner })
        session.display(location)
        session.refresh(full: true)
        await session.refreshTask?.value
        try await waitForConfiguration(session) { _ in true }
        return (session, runner, directory)
    }

    /// 写入文件并经会话暂存全部改动。
    private func stageChange(in session: RepositorySession, directory: URL, content: String) async throws {
        try Data(content.utf8).write(to: directory.appending(path: "file.txt"))
        session.refresh(full: true)
        await session.refreshTask?.value
        session.stageAll(staged: true)
        await session.writeTask?.value
        await session.refreshTask?.value
    }

    /// 等待提交配置读到满足条件的结果。
    private func waitForConfiguration(
        _ session: RepositorySession,
        until condition: (CommitConfiguration) -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while !(session.commitConfiguration.map(condition) ?? false), .now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// 最近一次提交的完整信息。
    private func lastMessage(_ runner: GitRunner) async throws -> String {
        String(decoding: try await runner.run(["log", "-1", "--format=%B"]), as: UTF8.self)
            .trimmingCharacters(in: .newlines)
    }
}
