import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 以真实本机 Git 仓库验证文件监听、动作可用性、写入回滚与 History 跨视图刷新。
extension RepositorySessionTests {
    /// 新文件由文件监听进入列表；菜单、工具栏、右键菜单与拖放共用的可用性规则随仓库状态与写入状态变化；
    /// 暂存失败回滚勾选框，成功后选区跟到暂存后的条目；写入后 History 与引用跟随更新，关闭仓库后清空 History。
    @Test("本机仓库的文件监听、动作可用性、写入回滚与 History 刷新")
    func localRepository() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["remote", "add", "origin", directory.appending(path: "missing.git").path])

        let session = RepositorySession(makeRunner: { _ in runner })

        defer {
            session.close()
            RepositoryActivities.shared.items.removeAll { $0.repository == location }
        }

        session.display(location)
        session.refresh()
        await session.waitForRefresh()

        // 不调用手动刷新，新增文件必须由文件监听进入列表；监听引起的刷新没有别的完成信号
        try Data("new\n".utf8).write(to: directory.appending(path: "file"))
        await until { !(session.status?.entries.isEmpty ?? true) }

        // 可用性规则要用到引用与上下文：等刷新带起的读取都结束；上下文的读取没有暴露，只能等它读到结果
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }
        await until { session.context != nil }

        try await checkAvailability(session)
        try await stageWithRollback(session, directory: directory)
        try await followHistory(session)
    }
}

// MARK: - Steps

extension RepositorySessionTests {
    /// 有远端、没有上游、只有一个未跟踪文件时的可用性；写入进行中所有写入口一起禁用，结束后恢复。
    private func checkAvailability(_ session: RepositorySession) async throws {
        let entries = session.status?.entries ?? []

        #expect(session.canFetch && session.canPush && session.canPublish && session.canCreateBranch)
        #expect(!session.canPull && !session.canMerge)
        #expect(session.canStage(entries) && !session.canUnstage(entries) && session.canDiscard(entries))
        #expect(!session.canStage([]) && !session.canResolve(entries))

        let (gate, release) = AsyncStream<Void>.makeStream()
        defer { release.finish() }

        session.performGit({ _, _ in for await _ in gate { } }, title: "Fetch")

        #expect(
            !session.canFetch
                && !session.canPush
                && !session.canCreateBranch
                && !session.canStage(entries)
        )

        release.finish()
        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(session.canFetch)
    }

    /// 索引被锁时暂存失败，勾选框回滚；解锁后暂存成功，选区从未跟踪的条目跟到已暂存的同一路径。
    private func stageWithRollback(_ session: RepositorySession, directory: URL) async throws {
        let entry = try #require(session.status?.entries.first)
        let row = StatusRowID(path: entry.path, kind: entry.kind)
        session.selectedID = row
        session.selectedIDs = [row]

        let lock = directory.appending(path: ".git/index.lock")
        try Data().write(to: lock)

        session.stage([entry], staged: true)
        #expect(session.stagingOverrides[row] ?? false)
        #expect(session.isWriting)

        await session.writeTask?.value
        await session.waitForRefresh()
        #expect(session.stagingOverrides.isEmpty)
        #expect(session.status?.entries.first?.kind == .untracked)

        try FileManager.default.removeItem(at: lock)
        session.stage([entry], staged: true)
        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(session.status?.entries.first?.hasStagedChanges ?? false)
        #expect(session.selectedID?.path == entry.path)
        #expect(session.selectedID?.kind == .tracked)
    }

    /// 建分支并切换后 History 显示新引用且保留选择；本地与上游各多一个提交时两侧归属正确；关闭仓库后被取消的读取不写回。
    private func followHistory(_ session: RepositorySession) async throws {
        let commit = try #require(session.history.commits.first)
        session.history.selectedIDs = [commit.id]
        session.activeView = .history

        await performAndRead(session) { runner, _ in
            try await RepositoryReferences(runner: runner)
                .create(name: "topic", startingAt: commit.id, track: false, checkout: true)
        }

        #expect(session.status?.branch.head == "topic")
        #expect(session.history.snapshot?.references.contains { $0.id == "refs/heads/topic" } ?? false)
        #expect(session.history.selectedIDs == [commit.id])

        // 本地与上游各增加一个提交，History 必须同时显示两侧并正确标记归属
        await performAndRead(session) { runner, _ in
            let references = RepositoryReferences(runner: runner)
            _ = try await runner.run(["commit", "--allow-empty", "-m", "local"])
            try await references.checkout("refs/heads/main")
            _ = try await runner.run(["commit", "--allow-empty", "-m", "upstream"])
            try await references.checkout("refs/heads/topic")
            _ = try await runner.run(["branch", "--set-upstream-to=main", "topic"])
        }

        session.history.selectedReference = "refs/heads/topic"
        await untilFinished { session.history.activeTasks }

        let local = try #require(session.history.commits.first { $0.subject == "local" })
        let upstream = try #require(session.history.commits.first { $0.subject == "upstream" })
        #expect(session.history.unpushed == [local.id])
        #expect(session.history.unpulled == [upstream.id])

        // 关闭仓库时进行中的读取被取消，等它们结束后 History 仍是空的
        session.history.loadNextPage()
        let reads = session.history.activeTasks
        session.close()

        for read in reads {
            await read.value
        }

        #expect(session.history.snapshot == nil)
        #expect(session.history.commits.isEmpty)
        #expect(!session.history.isLoading)
    }

    /// 经会话执行写操作，等写入、随后的完整刷新与它带起的 History 读取都结束。
    private func performAndRead(
        _ session: RepositorySession,
        _ action: @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void
    ) async {
        #expect(session.performGit(action, title: "Write"))

        await session.writeTask?.value
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }
    }
}
