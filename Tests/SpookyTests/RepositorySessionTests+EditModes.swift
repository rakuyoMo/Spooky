import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 提交区的编辑模式共用一份草稿：修补结束后回到普通草稿，合并换上合并说明且成功后为空，失败保留正在编辑的信息。
extension RepositorySessionTests {
    /// 取消修补与修补成功都回到进入修补前的普通草稿，修补不弹确认、直接改写最近一次提交；修补失败时信息与修补状态原样保留；
    /// ⌥ 快速修补在提交开始后就松开时草稿立即回来，提交中与等待重置期间不能再进入修补。
    @Test("修补取消、失败、成功与快速修补")
    func amendRestoresDraft() async throws {
        let (session, runner, directory) = try await commitSession()

        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        session.onConfirm = { Issue.record("不应弹出确认：\($0.title)") }
        session.commitResetDelay = .zero
        try await commitFirst(in: session, directory: directory)

        // 取消修补：信息先换成最近一次提交的信息，再恢复普通草稿
        session.commitSubject = "草稿"
        session.commitBody = "草稿正文"
        session.setAmend(true)

        #expect(session.commitSubject == "第一次")

        session.setAmend(false)
        #expect(session.commitSubject == "草稿" && session.commitBody == "草稿正文")

        try await failAndRetryAmend(session, runner: runner, directory: directory)
        try await quickAmend(session, directory: directory)
    }

    /// 进入合并时合并说明替换非空草稿并退出修补，合并成功后信息为空；切回仓库时恢复的合并信息不被覆盖。
    @Test("合并替换草稿，成功后为空")
    func mergeReplacesDraft() async throws {
        let (session, runner, directory) = try await commitSession()

        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        session.commitResetDelay = .zero
        try await commitFirst(in: session, directory: directory)

        // 在 side 上提交另一个文件，回到 main 后不提交地合并它
        _ = try await runner.run(["checkout", "-q", "-b", "side"])
        try Data("side\n".utf8).write(to: directory.appending(path: "side.txt"))
        _ = try await runner.run(["add", "-A"])
        _ = try await runner.run(["commit", "-q", "-m", "side"])
        _ = try await runner.run(["checkout", "-q", "main"])

        session.refresh(full: true)
        await session.waitForRefresh()

        session.commitSubject = "草稿"
        session.setAmend(true)
        _ = try await runner.run(["merge", "-q", "--no-ff", "--no-commit", "side"])
        await reload(session) { session.context?.operation == .merge }

        #expect(session.commitSubject == "Merge branch 'side'")
        #expect(!session.amend)
        #expect(session.originalDraft == nil)

        // 改过的合并信息随视图状态存下，切回仓库后不被合并说明覆盖
        session.commitSubject = "改过的合并说明"
        let location = try #require(session.repository)
        session.close()
        session.display(location)
        await reload(session) { session.context?.operation == .merge }

        #expect(session.commitSubject == "改过的合并说明")

        // 合并成功后信息为空，合并前的草稿不再回来
        session.commit()
        await session.writeTask?.value
        await session.commitResetTask?.value

        #expect(try await lastMessage(runner) == "改过的合并说明")
        #expect(session.commitSubject.isEmpty && session.commitBody.isEmpty)
    }
}

// MARK: - Steps

extension RepositorySessionTests {
    /// 钩子拒绝时修补失败，正在编辑的修补信息与保存的草稿都保留；去掉钩子后修补成功，提交数不变，重置时回到普通草稿并退出修补。
    private func failAndRetryAmend(
        _ session: RepositorySession,
        runner: GitRunner,
        directory: URL
    ) async throws {
        let hook = directory.appending(path: ".git/hooks/pre-commit")
        try FileManager.default.createDirectory(
            at: hook.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\nexit 1\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)

        try await stageChange(in: session, directory: directory, content: "amend")
        session.setAmend(true)
        session.commitSubject = "修补后的信息"
        session.commit()
        await session.writeTask?.value

        // 提交中状态由写操作结束后的另一个任务收起
        await until { !session.isCommitting }

        #expect(session.amend)
        #expect(session.commitSubject == "修补后的信息")
        #expect(session.originalDraft?.subject == "草稿")

        try FileManager.default.removeItem(at: hook)
        session.commit()
        await session.writeTask?.value
        await session.commitResetTask?.value

        #expect(try await lastMessage(runner) == "修补后的信息")
        #expect(try await runner.run(["rev-list", "--count", "HEAD"]) == Data("1\n".utf8))
        #expect(!session.amend)
        #expect(session.originalDraft == nil)
        #expect(session.commitSubject == "草稿" && session.commitBody == "草稿正文")
    }

    /// 与窗口里按 ⌥ 回车相同：先进入修补并提交，随即松开 ⌥；关闭仓库时立即重置，回到的是草稿。
    private func quickAmend(_ session: RepositorySession, directory: URL) async throws {
        try await stageChange(in: session, directory: directory, content: "quick")
        session.commitResetDelay = .seconds(3600)

        session.setAmend(true)
        session.commit()
        session.setAmend(false)

        #expect(session.isCommitting)
        #expect(session.commitSubject == "草稿")

        // 提交中再按 ⌥ 不会进入修补
        session.setAmend(true)
        #expect(!session.amend)

        await session.writeTask?.value

        // 等待重置期间同样不能进入修补
        session.setAmend(true)
        #expect(!session.amend)

        let location = try #require(session.repository)
        session.close()
        session.display(location)

        #expect(session.commitSubject == "草稿")
    }

    /// 提交第一个提交 “第一次”，等到重置结束、上下文读到它的信息，让之后可以修补。
    private func commitFirst(in session: RepositorySession, directory: URL) async throws {
        try await stageChange(in: session, directory: directory, content: "first")
        session.commitSubject = "第一次"
        session.commit()
        await session.writeTask?.value
        await session.commitResetTask?.value

        // 上下文的读取没有暴露，等它读到这次提交
        await until { session.context?.lastMessage == "第一次" }
    }
}
