import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 提交的进度与结束：转圈只属于提交，成功后先收起正文、交出焦点，过一段时间才重置信息。
extension RepositorySessionTests {
    /// 暂存与丢弃不进入提交中状态，按钮旁的转圈不会因为它们出现。
    @Test("其它写操作不进入提交中")
    func otherWritesDoNotShowCommitProgress() async throws {
        let (session, _, directory) = try await commitSession()
        defer {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        var committing: [Bool] = []
        session.onWriteFinished = { [weak session] _ in
            committing.append(session?.isCommitting ?? true)
        }

        session.onConfirm = { $0.action() }
        session.commitProgressDelay = .zero

        // 暂存一次，再丢弃暂存后又改动的内容
        try await stageChange(in: session, directory: directory, content: "staged")
        try Data("discarded".utf8).write(to: directory.appending(path: "file.txt"))
        session.refresh(full: true)
        await session.waitForRefresh()

        session.discard(session.status?.entries.filter(\.hasUnstagedChanges) ?? [])
        await session.writeTask?.value

        #expect(committing == [false, false])
        #expect(!session.showsCommitProgress)
    }

    /// 钩子拖住的提交过了延迟才转圈；成功后立即停止转圈、收起正文并请求文件列表获得焦点，信息要等重置时才变。
    @Test("提交成功先收起再重置")
    func commitProgressAndSuccess() async throws {
        let (session, _, directory) = try await commitSession()
        let gate = directory.appending(path: ".git/hook-gate")
        defer {
            try? Data("0".utf8).write(to: gate)
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        try installGatedHook(in: directory, gate: gate)
        session.commitProgressDelay = .zero
        session.commitResetDelay = .seconds(3600)

        try await stageChange(in: session, directory: directory, content: "slow")
        session.commitSubject = "慢提交"
        session.commitBody = "正文"
        let focusRequest = session.fileListFocusRequest

        session.commit()
        #expect(session.isCommitting)

        try await waitUntil { session.showsCommitProgress }
        #expect(session.isWriting)

        // 放行钩子：提交成功时转圈停止、正文收起、焦点请求发出，信息仍是刚提交的内容
        try Data("0".utf8).write(to: gate)
        await session.writeTask?.value

        #expect(!session.isCommitting)
        #expect(!session.showsCommitProgress)
        #expect(session.collapsesCommitBody)
        #expect(session.fileListFocusRequest == focusRequest + 1)
        #expect(session.commitSubject == "慢提交")
        #expect(session.commitResetTask != nil)
    }

    /// 提交失败或被取消都结束提交中状态，不收起正文、不请求焦点、不重置，信息原样保留。
    @Test("提交失败与取消结束转圈并保留信息")
    func commitProgressFailureAndCancel() async throws {
        let (session, _, directory) = try await commitSession()
        let gate = directory.appending(path: ".git/hook-gate")
        defer {
            try? Data("0".utf8).write(to: gate)
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        try installGatedHook(in: directory, gate: gate)
        try await stageChange(in: session, directory: directory, content: "failing")
        session.commitSubject = "失败的提交"
        session.commitBody = "正文"
        let focusRequest = session.fileListFocusRequest

        // 失败：提前结束的提交不闪现转圈
        session.commitProgressDelay = .seconds(3600)
        session.commit()
        #expect(session.isCommitting)

        try Data("1".utf8).write(to: gate)
        await session.writeTask?.value
        try await waitUntil { !session.isCommitting }

        #expect(!session.showsCommitProgress)
        #expect(!session.collapsesCommitBody)
        #expect(session.fileListFocusRequest == focusRequest)
        #expect(session.commitResetTask == nil)
        #expect(session.commitSubject == "失败的提交")
        #expect(session.commitBody == "正文")

        // 取消：钩子还在等待时取消写操作，随后放行钩子，让它退出
        try FileManager.default.removeItem(at: gate)
        session.commitProgressDelay = .zero
        session.commit()
        try await waitUntil { session.showsCommitProgress }

        session.writeTask?.cancel()
        try Data("0".utf8).write(to: gate)
        await session.writeTask?.value
        try await waitUntil { !session.isCommitting }

        #expect(!session.showsCommitProgress)
        #expect(!session.collapsesCommitBody)
        #expect(session.commitSubject == "失败的提交")
    }
}

// MARK: - Helpers

extension RepositorySessionTests {
    /// 安装等待闸门文件的 pre-commit 钩子：文件出现后以其中的数字退出，最多等 300 s，测试异常结束时也不会一直挂着。
    private func installGatedHook(in directory: URL, gate: URL) throws {
        let hook = directory.appending(path: ".git/hooks/pre-commit")
        let script = """
            #!/bin/sh
            i=0
            while [ ! -e '\(gate.path)' ] && [ $i -lt 3000 ]; do
                sleep 0.1
                i=$((i + 1))
            done
            exit "$(cat '\(gate.path)' 2>/dev/null || echo 1)"

            """

        try FileManager.default.createDirectory(at: hook.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(script.utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
    }
}
