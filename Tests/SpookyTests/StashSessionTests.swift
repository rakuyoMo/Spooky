import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - StashSessionTests

/// 会话层的储藏行为：被本地改动挡住时转为询问储藏、拖入工作区文件的载荷、储藏失败的说明与原文。
@MainActor
struct StashSessionTests {
    /// 合并被本地改动挡住时不弹出失败，改为询问；选择储藏后合并完成，改动恢复，储藏列表随完整刷新更新。
    @Test("被本地改动挡住的合并转为 Auto Stash")
    func autoStashMerge() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-stash-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await makeRepository(at: location)
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        var requests: [StashRequest] = []
        var failures: [AppFailure] = []
        session.onStashRequest = { requests.append($0) }
        session.onFailure = { failures.append($0) }

        session.display(location)
        session.refresh()
        await session.refreshTask?.value
        try Data("local\n".utf8).write(to: directory.appending(path: "tracked.txt"))

        let merge: @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void = {
            try await RepositorySync(runner: $0).merge("refs/heads/feature", onOutput: $1)
        }
        session.performGit(merge, title: "Merge", offersAutoStash: true)
        await session.writeTask?.value
        await session.refreshTask?.value

        #expect(failures.isEmpty)
        guard case .autoStash(let pending) = try #require(requests.first) else {
            Issue.record("应转为询问是否储藏")
            return
        }

        // 不储藏时照常报告原操作被挡住的失败
        session.declineAutoStash(pending)
        #expect(failures.first?.title == AppLocalization.text("sync.error.dirty"))

        session.performAutoStash(pending, message: "auto", reapply: true)
        await session.writeTask?.value
        await session.refreshTask?.value
        await allTasks(of: session.stashes)

        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "feature.txt").path))
        #expect(try Data(contentsOf: directory.appending(path: "tracked.txt")) == Data("local\n".utf8))
        #expect(session.stashes.isLoaded && session.stashes.entries.isEmpty)
    }

    /// 只有 Spooky 的干净工作区检查与 Git 拒绝覆盖本地改动算作被本地改动挡住。
    @Test("识别被本地改动挡住的失败")
    func blockedByLocalChanges() {
        let result = GitCommandResult(
            arguments: ["switch", "--", "main"],
            standardOutput: Data(),
            standardError: Data("error: Your local changes would be overwritten by checkout".utf8),
            terminationStatus: .exited(1),
            isCancelled: false
        )

        #expect(RepositorySession.isBlockedByLocalChanges(RepositorySyncError.dirtyWorkingCopy))
        #expect(RepositorySession.isBlockedByLocalChanges(GitError(result: result, category: .localChanges, diagnostic: nil)))
        #expect(!RepositorySession.isBlockedByLocalChanges(RepositorySyncError.requiresBranch))
        #expect(!RepositorySession.isBlockedByLocalChanges(GitError(result: result, category: .commandFailed, diagnostic: nil)))
    }

    /// 工作区文件列表写入的载荷按约定的 JSON 解码；其它仓库与格式不符的项被忽略。
    @Test("Stashes 落点解码工作区文件载荷")
    func droppedFiles() async throws {
        let location = RepositoryLocation.local(path: "/tmp/仓 库")
        let other = RepositoryLocation.remote(host: "spooky-test", path: "/tmp/仓 库")

        let providers = try [
            provider(repository: location, path: "目录/文件 *.txt"),
            provider(repository: other, path: "other.txt"),
            provider(raw: Data("not json".utf8)),
            provider(repository: location, path: "新 文件.txt"),
        ]

        let paths = await StashesDropTarget.paths(from: providers, in: location)
        #expect(paths == ["目录/文件 *.txt", "新 文件.txt"])
    }

    /// 储藏失败的说明本地化，Git 原文来自自身结果或被包装的原始错误。
    @Test("储藏失败的说明与原文")
    func failurePresentation() {
        let saved = GitCommandResult(
            arguments: ["stash", "push"],
            standardOutput: Data("No local changes to save\n".utf8),
            standardError: Data(),
            terminationStatus: .exited(0),
            isCancelled: false
        )
        let empty = AppFailure(error: StashError.noLocalChanges(saved), opening: false, location: nil, writing: true)
        #expect(empty.title == AppLocalization.text("stash.error.noChanges"))
        #expect(empty.message == AppLocalization.text("stash.error.noChanges.help"))
        #expect(empty.details.contains("No local changes to save"))

        let merged = GitCommandResult(
            arguments: ["merge"],
            standardOutput: Data("CONFLICT (content): Merge conflict in a.txt\n".utf8),
            standardError: Data("Automatic merge failed".utf8),
            terminationStatus: .exited(1),
            isCancelled: false
        )
        let underlying = GitError(result: merged, category: .commandFailed, diagnostic: nil)
        let failed = AppFailure(
            error: StashError.operationFailed(stash: "auto", underlying: underlying),
            opening: false,
            location: nil,
            writing: true
        )
        #expect(failed.title == AppLocalization.text("stash.error.operation"))
        #expect(failed.details.contains("Merge conflict in a.txt") && failed.details.contains("Automatic merge failed"))
    }
}

// MARK: - Helpers

extension StashSessionTests {
    /// 带 main 与 feature 两个分支的隔离仓库：feature 多一个新文件，工作区干净。
    private func makeRepository(at location: RepositoryLocation) async throws -> GitRunner {
        let runner = GitRunner(
            location: location,
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )
        let root = URL(fileURLWithPath: location.path)

        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        _ = try await runner.run(["config", "--local", "commit.gpgSign", "false"])

        try Data("base\n".utf8).write(to: root.appending(path: "tracked.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])

        _ = try await runner.run(["switch", "-q", "-c", "feature"])
        try Data("feature\n".utf8).write(to: root.appending(path: "feature.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "feature"])
        _ = try await runner.run(["switch", "-q", "main"])
        return runner
    }

    /// 等待储藏列表与详情的读取任务结束。
    private func allTasks(of stashes: RepositoryStashState) async {
        for task in stashes.activeTasks {
            await task.value
        }
    }

    /// 按约定格式构造的拖动项：`{"repository": <RepositoryLocation>, "path": <相对路径>}`。
    private func provider(repository: RepositoryLocation, path: String) throws -> NSItemProvider {
        let location = try JSONSerialization.jsonObject(with: JSONEncoder().encode(repository))
        return try provider(raw: JSONSerialization.data(withJSONObject: ["repository": location, "path": path]))
    }

    /// 以应用内类型登记任意数据的拖动项。
    private func provider(raw data: Data) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: StashesDropTarget.Payload.type,
            visibility: .ownProcess
        ) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }
}
