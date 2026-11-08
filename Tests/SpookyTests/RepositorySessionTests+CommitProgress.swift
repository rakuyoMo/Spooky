import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 提交的进度与结束：转圈只属于提交，成功后先收起正文、交出焦点，过一段时间才重置信息。
extension RepositorySessionTests {
    /// 暂存与丢弃不进入提交中状态；钩子拖住的提交过了延迟才转圈，失败或被取消都结束提交中状态并保留信息，
    /// 成功后立即停止转圈、收起正文并请求文件列表获得焦点，信息要等重置时才变。
    @Test("提交中状态：其它写操作、失败、取消与成功")
    func commitProgress() async throws {
        let (session, _, directory) = try await commitSession()
        let gate = try ProcessGate(in: directory.appending(path: ".git"))

        defer {
            gate.release()
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        try await otherWritesWithoutProgress(session, directory: directory)

        // 前面的丢弃会连同暂存删掉新文件，提交前重新暂存一份
        let exitCode = try installGatedHook(in: directory, gate: gate)
        try await stageChange(in: session, directory: directory, content: "committed")

        session.commitSubject = "失败的提交"
        session.commitBody = "正文"

        try await failAndCancelCommit(session, gate: gate, exitCode: exitCode)

        // 成功：放行钩子时转圈停止、正文收起、焦点请求发出，信息仍是刚提交的内容
        let focusRequest = session.fileListFocusRequest
        session.commitResetDelay = .seconds(3600)
        try Data("0".utf8).write(to: exitCode)

        session.commit()
        await until { session.showsCommitProgress }
        #expect(session.isWriting)

        gate.release()
        await session.writeTask?.value

        #expect(!session.isCommitting)
        #expect(!session.showsCommitProgress)
        #expect(session.collapsesCommitBody)
        #expect(session.fileListFocusRequest == focusRequest + 1)
        #expect(session.commitSubject == "失败的提交")
        #expect(session.commitResetTask != nil)
    }
}

// MARK: - Steps

extension RepositorySessionTests {
    /// 暂存一次，再丢弃暂存后又改动的内容：两次写操作结束时都不在提交中，按钮旁的转圈不会因为它们出现。
    private func otherWritesWithoutProgress(_ session: RepositorySession, directory: URL) async throws {
        var committing: [Bool] = []
        session.onWriteFinished = { [weak session] _ in
            committing.append(session?.isCommitting ?? true)
        }

        session.onConfirm = { $0.action() }
        session.commitProgressDelay = .zero

        try await stageChange(in: session, directory: directory, content: "staged")
        try Data("discarded".utf8).write(to: directory.appending(path: "file.txt"))
        session.refresh(full: true)
        await session.waitForRefresh()

        session.discard(session.status?.entries.filter(\.hasUnstagedChanges) ?? [])
        await session.writeTask?.value

        #expect(committing == [false, false])
        #expect(!session.showsCommitProgress)

        session.onWriteFinished = nil
    }

    /// 失败：提前结束的提交不闪现转圈；取消：钩子停在闸门上时取消写操作。两种都不收起正文、不请求焦点、不重置。
    private func failAndCancelCommit(
        _ session: RepositorySession,
        gate: ProcessGate,
        exitCode: URL
    ) async throws {
        let focusRequest = session.fileListFocusRequest

        try Data("1".utf8).write(to: exitCode)
        session.commitProgressDelay = .seconds(3600)
        session.commit()

        #expect(session.isCommitting)

        await gate.arrival()
        gate.release()
        await session.writeTask?.value

        // 提交中状态由写操作结束后的另一个任务收起
        await until { !session.isCommitting }

        #expect(!session.showsCommitProgress)
        #expect(!session.collapsesCommitBody)
        #expect(session.fileListFocusRequest == focusRequest)
        #expect(session.commitResetTask == nil)
        #expect(session.commitSubject == "失败的提交")
        #expect(session.commitBody == "正文")

        // 钩子改以 0 退出：写操作若没有真正取消，提交会成功并重置信息；取消时钩子随进程组一起结束，不再放行
        try Data("0".utf8).write(to: exitCode)
        session.commitProgressDelay = .zero
        session.commit()

        await until { session.showsCommitProgress }
        await gate.arrival()

        session.writeTask?.cancel()
        await session.writeTask?.value
        await until { !session.isCommitting }

        #expect(!session.showsCommitProgress)
        #expect(!session.collapsesCommitBody)
        #expect(session.commitSubject == "失败的提交")
    }

    /// 安装停在闸门上的 pre-commit 钩子：放行后以退出码文件里的数字退出，文件不存在时以 1 退出。
    ///
    /// - Returns: 退出码文件的位置。
    private func installGatedHook(in directory: URL, gate: ProcessGate) throws -> URL {
        let hook = directory.appending(path: ".git/hooks/pre-commit")
        let exitCode = directory.appending(path: ".git/hook-exit")
        let script = """
            #!/bin/sh
            \(gate.command)
            exit "$(cat '\(exitCode.path)' 2>/dev/null || echo 1)"

            """

        try FileManager.default.createDirectory(
            at: hook.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(script.utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)

        return exitCode
    }
}
