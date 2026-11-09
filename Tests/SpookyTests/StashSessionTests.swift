import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - StashSessionTests

/// 会话层的储藏行为：被本地改动挡住时转为询问储藏、拖入工作区文件的载荷、储藏失败的说明与原文。
@MainActor
struct StashSessionTests {
    /// 合并被本地改动挡住时不弹出失败，而是询问；选择储藏后合并完成，改动恢复，储藏列表随完整刷新更新。
    @Test("被本地改动挡住的合并转为 Auto Stash")
    func autoStashMerge() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-stash-" + UUID().uuidString)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await makeRepository(at: location)
        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        defer { session.close() }

        var requests: [StashRequest] = []
        var failures: [AppFailure] = []
        session.onStashRequest = { requests.append($0) }
        session.onFailure = { failures.append($0) }

        session.display(location)
        session.refresh()
        await session.waitForRefresh()

        // 已跟踪的文件有本地改动时合并
        try Data("local\n".utf8).write(to: directory.appending(path: "tracked.txt"))

        let merge: @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void = {
            try await RepositorySync(runner: $0).merge("refs/heads/feature", onOutput: $1)
        }

        session.performGit(merge, title: "Merge", offersAutoStash: true)
        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(failures.isEmpty)

        guard case .autoStash(let pending) = try #require(requests.first) else {
            Issue.record("应转为询问是否储藏")
            return
        }

        // 不储藏时照常报告原操作被挡住的失败
        session.declineAutoStash(pending)
        #expect(failures.first?.title == AppLocalization.text("error.merge"))

        // 选择储藏：合并完成，改动恢复，储藏随恢复删掉
        session.performAutoStash(pending, message: "auto", reapply: true)
        await session.writeTask?.value
        await session.waitForRefresh()
        await untilFinished { session.stashes.activeTasks }

        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "feature.txt").path))
        #expect(try Data(contentsOf: directory.appending(path: "tracked.txt")) == Data("local\n".utf8))
        #expect(session.stashes.isLoaded && session.stashes.entries.isEmpty)
    }

    /// 只有 Spooky 的干净工作区检查与 Git 拒绝覆盖本地改动算作被本地改动挡住；
    /// 储藏失败的说明本地化，Git 原文来自自身结果或被包装的原始错误。
    @Test("识别被本地改动挡住的失败，储藏失败的说明与原文")
    func failureHandling() {
        let result = GitCommandResult(
            arguments: ["switch", "--", "main"],
            standardOutput: Data(),
            standardError: Data("error: Your local changes would be overwritten by checkout".utf8),
            terminationStatus: .exited(1),
            isCancelled: false
        )

        let localChanges = GitError(result: result, category: .localChanges, diagnostic: nil)
        let commandFailed = GitError(result: result, category: .commandFailed, diagnostic: nil)

        #expect(RepositorySession.isBlockedByLocalChanges(RepositorySyncError.dirtyWorkingCopy(rebase: true)))
        #expect(RepositorySession.isBlockedByLocalChanges(localChanges))
        #expect(!RepositorySession.isBlockedByLocalChanges(RepositorySyncError.requiresBranch))
        #expect(!RepositorySession.isBlockedByLocalChanges(commandFailed))

        // 没有可储藏的改动：原文来自储藏命令自身的输出
        let saved = GitCommandResult(
            arguments: ["stash", "push"],
            standardOutput: Data("No local changes to save\n".utf8),
            standardError: Data(),
            terminationStatus: .exited(0),
            isCancelled: false
        )

        let empty = failure(StashError.noLocalChanges(saved))

        #expect(empty.title == AppLocalization.text("stash.error.noChanges"))
        #expect(empty.message == AppLocalization.text("stash.error.noChanges.help"))
        #expect(empty.details.contains("No local changes to save"))

        // 储藏后的原操作失败：原文来自被包装的 Git 错误
        let merged = GitCommandResult(
            arguments: ["merge"],
            standardOutput: Data("CONFLICT (content): Merge conflict in a.txt\n".utf8),
            standardError: Data("Automatic merge failed".utf8),
            terminationStatus: .exited(1),
            isCancelled: false
        )

        let underlying = GitError(result: merged, category: .commandFailed, diagnostic: nil)
        let failed = failure(StashError.operationFailed(stash: "auto", underlying: underlying))

        #expect(failed.title == AppLocalization.text("stash.error.operation"))
        #expect(failed.details.contains("Merge conflict in a.txt"))
        #expect(failed.details.contains("Automatic merge failed"))

        // 停在冲突上的原操作没有 Git 错误，说明只写储藏的去向
        let conflicts = failure(StashError.operationConflicts(stash: "auto"))

        #expect(conflicts.title == AppLocalization.text("stash.error.operationConflicts"))
        #expect(conflicts.message == AppLocalization.text("stash.error.operationConflicts.help"))
    }

    /// 工作区文件列表写入的载荷按约定的 JSON 解码；其它仓库与格式不符的项被忽略。
    @Test("Stashes 落点解码工作区文件载荷")
    func droppedFiles() throws {
        let location = RepositoryLocation.local(path: "/tmp/仓 库")
        let other = RepositoryLocation.remote(host: "spooky-test", path: "/tmp/仓 库")

        let items = try [
            item(repository: location, path: "目录/文件 *.txt"),
            item(repository: other, path: "other.txt"),
            item(raw: Data("not json".utf8)),
            item(repository: location, path: "新 文件.txt"),
        ]

        let paths = StashesDropTarget.paths(from: items, in: location)
        #expect(paths == ["目录/文件 *.txt", "新 文件.txt"])
    }
}

// MARK: - Helpers

extension StashSessionTests {
    /// 带 main 与 feature 两个分支的隔离仓库：feature 多一个新文件，工作区干净。
    private func makeRepository(at location: RepositoryLocation) async throws -> GitRunner {
        let runner = try await FileViewsTests.initializeRepository(at: location)
        let root = URL(fileURLWithPath: location.path)

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

    /// 写操作里储藏失败时呈现给用户的失败。
    private func failure(_ error: StashError) -> AppFailure {
        AppFailure(error: error, opening: false, location: nil, writing: true)
    }

    /// 按约定格式构造的拖动项：`{"repository": <RepositoryLocation>, "path": <相对路径>}`。
    private func item(repository: RepositoryLocation, path: String) throws -> NSPasteboardItem {
        let location = try JSONSerialization.jsonObject(with: JSONEncoder().encode(repository))
        let data = try JSONSerialization.data(withJSONObject: ["repository": location, "path": path])

        return item(raw: data)
    }

    /// 以应用内类型写入任意数据的拖动项。
    private func item(raw data: Data) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        item.setData(data, forType: NSPasteboard.PasteboardType(StashesDropTarget.Payload.type))

        return item
    }
}
