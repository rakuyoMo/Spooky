import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - WorkspaceProgress

extension RepositorySessionTests {
    /// 检出、合并、拉取、变基与重置执行期间，会话发布写明操作与参数的整页进度，Git 的最后一行输出写进进度文字与比例；
    /// 停止后进度清空、状态按真实仓库刷新；暂存这类文件级写操作不发布整页进度。
    @Test("工作区类写操作的整页进度")
    func workspaceProgress() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        await fixture.session.shutdown()

        // topic 比当前分支多一个提交；当前分支跟踪本地的 topic，拉取不连网络
        let runner = fixture.runner
        let output = try await runner.run(["symbolic-ref", "--short", "HEAD"])
        let main = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        _ = try await runner.run(["switch", "-q", "-c", "topic"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "topic"])
        _ = try await runner.run(["switch", "-q", main])
        _ = try await runner.run(["config", "branch.\(main).remote", "."])
        _ = try await runner.run(["config", "branch.\(main).merge", "refs/heads/topic"])

        let root = fixture.directory.appending(path: ".git")
        let gate = try ProcessGate(in: root)
        defer { gate.release() }

        let gated = try fixture.gatedRunner(
            intercepting: "merge",
            gate: gate,
            claimed: #"printf 'Updating files:  50%% (1/2)\n' >&2"#
        )

        let session = RepositorySession(makeRunner: { _ in gated }, activities: RepositoryActivities())
        defer { session.close() }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        session.display(fixture.location)
        session.refresh(full: true)
        await settle(session)

        let references = try #require(session.history.snapshot?.references)
        let topic = try #require(references.first { $0.id == "refs/heads/topic" })
        let current = try #require(references.first { $0.id == "refs/heads/" + main })
        let base = try await fixture.head()

        // 合并停在闸门上：标题写明合并，Git 的进度行写进进度文字，比例取其中的百分比
        try Data().write(to: root.appending(path: "arm"))
        session.quickMerge(topic)
        await gate.arrival()
        await until { session.workspaceProgress?.detail == "Updating files:  50% (1/2)" }

        #expect(session.workspaceProgress?.title == AppLocalization.text("workspaceProgress.merge"))
        #expect(session.workspaceProgress?.fraction == 0.5)

        // 停止：Git 没有执行，进度清空，刷新后 HEAD 仍在原处
        session.writeTask?.cancel()
        await settle(session)

        #expect(session.workspaceProgress == nil && !session.isWriting)
        #expect(session.status?.branch.oid == base)

        // 五类调用各带自己的标题，结束后清空
        await expectProgress(AppLocalization.text("workspaceProgress.checkoutRevision", "topic"), in: session) {
            session.checkout(revision: "topic")
        }

        await expectProgress(AppLocalization.text("workspaceProgress.checkoutBranch", current.name), in: session) {
            session.checkoutBranch(current)
        }

        await expectProgress(AppLocalization.text("workspaceProgress.reset"), in: session) {
            session.reset(to: "HEAD", mode: .mixed)
        }

        await expectProgress(AppLocalization.text("workspaceProgress.merge"), in: session) {
            session.quickMerge(topic)
        }

        await expectProgress(AppLocalization.text("workspaceProgress.rebase"), in: session) {
            session.quickRebase(onto: topic)
        }

        await expectProgress(AppLocalization.text("sync.step.pull"), in: session) {
            session.quickPull()
        }

        #expect(session.status?.branch.head == main)
        #expect(try await fixture.head() == RepositoryReferences(runner: runner).resolve("topic"))

        // 文件级写操作不发布整页进度
        try fixture.write("changed\n")
        session.refresh(full: true)
        await settle(session)

        await expectProgress(nil, in: session) {
            session.stageAll(staged: true)
        }

        #expect(failures.isEmpty)
    }
}

// MARK: - Helpers

extension RepositorySessionTests {
    /// 发起写操作，核对开始时的整页进度标题；等写操作与随后的读取都结束后，核对进度已清空。
    private func expectProgress(
        _ title: String?,
        in session: RepositorySession,
        start: () -> Void
    ) async {
        start()

        #expect(session.isWriting)
        #expect(session.workspaceProgress?.title == title)

        await settle(session)

        #expect(session.workspaceProgress == nil)
    }

    /// 等写操作、随后的完整刷新与引用、储藏的读取都结束。
    private func settle(_ session: RepositorySession) async {
        await session.writeTask?.value
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks + session.stashes.activeTasks }
    }
}
