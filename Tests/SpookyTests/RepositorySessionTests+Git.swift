import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 以真实本机 Git 仓库验证文件监听、写入回滚、History 跨视图刷新与动作可用性。
extension RepositorySessionTests {
    /// 暂存失败回滚勾选框，提交失败保留草稿，重试成功才清空输入。
    @Test("写入失败回滚、提交草稿与本机文件监听")
    func writingAndDrafts() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "spooky-session-" + UUID().uuidString
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await initializeRepository(at: location)

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }
        session.display(location)
        session.refresh()
        await session.refreshTask?.value

        // 不调用手动刷新，新增文件必须由真实 FSEvents 进入列表。
        try Data("new\n".utf8).write(to: directory.appending(path: "file"))
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while session.status?.entries.isEmpty != false, .now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }

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
        await session.refreshTask?.value
        #expect(session.stagingOverrides.isEmpty)
        #expect(session.status?.entries.first?.kind == .untracked)

        try FileManager.default.removeItem(at: lock)
        session.stage([entry], staged: true)
        await session.writeTask?.value
        await session.refreshTask?.value
        #expect(session.status?.entries.first?.hasStagedChanges ?? false)
        #expect(session.selectedID?.path == entry.path)
        #expect(session.selectedID?.kind == .tracked)

        let hooks = directory.appending(path: ".git/hooks")
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: false)
        let hook = hooks.appending(path: "pre-commit")
        try Data("#!/bin/sh\nprintf 'hook rejected\\n' >&2\nexit 1\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
        session.commitSubject = "标题"
        session.commitBody = "正文"
        session.commit()
        await session.writeTask?.value
        await session.refreshTask?.value
        #expect(session.commitSubject == "标题")
        #expect(session.commitBody == "正文")
        #expect(try await runner.status().branch.oid == nil)

        try FileManager.default.removeItem(at: hook)
        session.commit()
        await session.writeTask?.value
        await session.refreshTask?.value
        await session.commitResetTask?.value
        #expect(session.commitSubject.isEmpty && session.commitBody.isEmpty)
        #expect(session.status?.entries.isEmpty ?? false)
        #expect(session.status?.branch.oid != nil)
    }

    /// 分支写入和提交后，History 与引用必须跟随真实 Git 更新。
    @Test("History 跨视图刷新、选择与关闭生命周期")
    func historyLifecycle() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "spooky-history-" + UUID().uuidString
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await initializeRepository(at: location)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }
        session.display(location)
        session.refresh()
        await session.refreshTask?.value
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while session.history.commits.isEmpty, .now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }

        let commit = try #require(session.history.commits.first)
        session.history.selectedIDs = [commit.id]
        session.activeView = .history
        session.performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner)
                    .create(
                        name: "topic",
                        startingAt: commit.id,
                        track: false,
                        checkout: true
                    )
            },
            title: "Create Branch"
        )
        await session.writeTask?.value
        await session.refreshTask?.value
        let referenceDeadline = ContinuousClock.now.advanced(by: .seconds(300))

        while
            session.history.snapshot?.references.contains(where: { $0.id == "refs/heads/topic" }) != true,
            .now < referenceDeadline
        {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(session.status?.branch.head == "topic")
        #expect(session.history.snapshot?.references.contains(where: { $0.id == "refs/heads/topic" }) ?? false)
        #expect(session.history.selectedIDs == [commit.id])

        // 本地与上游各增加一个提交，History 必须同时显示两侧并正确标记归属。
        session.performGit(
            { runner, _ in
                _ = try await runner.run(["commit", "--allow-empty", "-m", "local"])
                try await RepositoryReferences(runner: runner).checkout("refs/heads/main")
                _ = try await runner.run(["commit", "--allow-empty", "-m", "upstream"])
                try await RepositoryReferences(runner: runner).checkout("refs/heads/topic")
                _ = try await runner.run(["branch", "--set-upstream-to=main", "topic"])
            },
            title: "Commit"
        )
        await session.writeTask?.value
        await session.refreshTask?.value
        session.history.selectedReference = "refs/heads/topic"
        let trackingDeadline = ContinuousClock.now.advanced(by: .seconds(300))

        while session.history.unpushed.isEmpty, .now < trackingDeadline {
            try await Task.sleep(for: .milliseconds(20))
        }

        let local = try #require(session.history.commits.first { $0.subject == "local" })
        let upstream = try #require(session.history.commits.first { $0.subject == "upstream" })
        #expect(session.history.unpushed == [local.id])
        #expect(session.history.unpulled == [upstream.id])
        #expect(
            !session.history.unpushed.contains(commit.id) && !session.history.unpulled.contains(commit.id)
        )

        session.history.loadNextPage()
        session.close()
        try await Task.sleep(for: .milliseconds(50))
        #expect(session.history.snapshot == nil)
        #expect(session.history.commits.isEmpty)
        #expect(!session.history.isLoading)
        RepositoryActivities.shared.items.removeAll { $0.repository == location }
    }

    /// 菜单、工具栏、右键菜单与拖放共用的可用性规则随真实仓库状态与写入状态变化。
    ///
    /// 本机仓库的 Git 命令在测试进程里共用一组主机槽，整套测试并行时读取要排队，上限与等待按整套测试的耗时留足。
    @Test("统一的动作可用性规则", .timeLimit(.minutes(10)))
    func actionAvailability() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "spooky-rules-" + UUID().uuidString
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await initializeRepository(at: location)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["remote", "add", "origin", directory.appending(path: "missing.git").path])
        try Data("new\n".utf8).write(to: directory.appending(path: "file"))

        let session = RepositorySession(makeRunner: { _ in runner })
        defer {
            session.close()
            RepositoryActivities.shared.items.removeAll { $0.repository == location }
        }
        session.display(location)
        session.refresh()
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while session.history.snapshot == nil || session.context == nil, .now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }

        let entries = session.status?.entries ?? []
        #expect(session.canFetch && session.canPush && session.canPublish && session.canCreateBranch)
        #expect(!session.canPull && !session.canMerge)
        #expect(session.canStage(entries) && !session.canUnstage(entries) && session.canDiscard(entries))
        #expect(!session.canStage([]) && !session.canResolve(entries))

        // 写入进行中所有写入口一起禁用，结束后恢复。
        let (gate, release) = AsyncStream<Void>.makeStream()
        session.performGit({ _, _ in for await _ in gate { } }, title: "Fetch")
        #expect(!session.canFetch && !session.canPush && !session.canCreateBranch && !session.canStage(entries))
        release.finish()
        await session.writeTask?.value
        #expect(session.canFetch)
    }

    /// 在测试创建的临时目录中初始化仓库，返回隔离了本机 Git 配置的执行器。
    func initializeRepository(at location: RepositoryLocation) async throws -> GitRunner {
        // 忽略系统与用户的全局配置，测试只受仓库本地配置影响。
        let runner = GitRunner(
            location: location,
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )

        // 用空模板初始化固定分支名的仓库，提交身份与签名设置只写入仓库本地配置。
        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        _ = try await runner.run(["config", "--local", "commit.gpgSign", "false"])

        return runner
    }
}
