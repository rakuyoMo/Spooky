import Foundation
import Testing

@testable import SpookyKit

/// 本机核心闭环：状态 → Diff → 按行暂存 → 提交 → 历史 → 建分支 → 发布 → 获取 → 拉取 → 推送。
struct CoreWorkflowTests {
    /// 一次完整的日常流程只使用临时仓库与测试目录中的裸仓库，结束后删除。
    @Test("M1–M4 核心写操作闭环", arguments: ["sha1", "sha256"])
    func dailyLoop(format: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize(objectFormat: format)
        let runner = fixture.runner
        let working = WorkingCopyOperations(runner: runner)
        let references = RepositoryReferences(runner: runner)
        let sync = RepositorySync(runner: runner)
        let bare = fixture.directory.appending(path: "remote.git").path
        let otherPath = fixture.directory.appending(path: "other").path

        // 裸仓库与第二个工作区放在测试目录内，并从主工作区的状态中排除。
        try FileManager.default.createDirectory(
            at: fixture.directory.appending(path: ".git/info"),
            withIntermediateDirectories: true
        )
        try Data("remote.git/\nother/\n".utf8).write(to: fixture.directory.appending(path: ".git/info/exclude"))
        _ = try await runner.run(["init", "--bare", "--object-format=" + format, bare])
        _ = try await runner.run(["remote", "add", "origin", bare])

        // 状态与 Diff：新文件只暂存第一、三行，第二行留在工作区。
        let file = fixture.directory.appending(path: "你好 [draft].txt")
        try Data("first\nsecond\nthird\n".utf8).write(to: file)
        let untracked = try #require(try await runner.status().entries.first)
        #expect(untracked.kind == .untracked)
        let snapshot = try await working.diff(for: untracked, side: .unstaged)
        try await working.apply(snapshot, file: 0, hunk: 0, lines: [0, 2])
        #expect(try await runner.run(["show", ":你好 [draft].txt"]) == Data("first\nthird\n".utf8))

        // 提交后历史第一页只有这一个提交，身份与信息来自仓库本地配置。
        try await working.commit(subject: "按行提交", body: "正文")
        let head = try #require(try await runner.status().branch.oid)
        let history = RepositoryHistory(runner: runner)
        let page = try await history.page(roots: [head])
        #expect(page.commits.map(\.subject) == ["按行提交"])
        #expect(page.commits.first?.id.count == (format == "sha1" ? 40 : 64))
        #expect(try await history.changes(in: head).map(\.path) == ["你好 [draft].txt"])
        #expect(try await working.context(head: head).lastMessage == "按行提交\n\n正文")

        // 剩余改动暂存提交后，从 HEAD 新建并检出分支。
        try await working.stageAll(staged: true)
        try await working.commit(subject: "剩余改动", body: "")
        #expect(try await runner.status().entries.isEmpty)
        try await references.create(name: "topic/m5", startingAt: "HEAD", track: false, checkout: true)
        #expect(try await runner.status().branch.head == "topic/m5")

        // 首次发布建立上游，第二个工作区随后推送一个新提交。
        let published = try await sync.push(
            branch: "topic/m5",
            remote: "origin",
            destination: "topic/m5",
            setUpstream: true
        )
        #expect(published.contains { $0.flag == "*" })
        _ = try await runner.run(["clone", "-b", "topic/m5", bare, otherPath])
        let other = fixture.runner(at: otherPath)
        _ = try await other.run(["config", "--local", "user.name", "Other"])
        _ = try await other.run(["config", "--local", "user.email", "other@example.invalid"])
        _ = try await other.run(["config", "--local", "commit.gpgSign", "false"])
        try Data("remote\n".utf8).write(to: URL(fileURLWithPath: otherPath).appending(path: "remote.txt"))
        _ = try await other.run(["add", "--all"])
        _ = try await other.run(["commit", "-m", "Other workspace update"])
        _ = try await other.run(["push", "origin", "topic/m5"])

        // 本地也提交一次，形成双向分叉，再获取并显式合并拉取。
        try Data("local\n".utf8).write(to: fixture.directory.appending(path: "local.txt"))
        try await working.stageAll(staged: true)
        try await working.commit(subject: "Local update", body: "")
        let fetched = try await sync.fetch(prune: true)
        #expect(fetched.contains { $0.reference == "refs/remotes/origin/topic/m5" })
        let snapshotAfterFetch = try await references.snapshot()
        let counts = try await references.divergences(in: snapshotAfterFetch)
        #expect(counts["refs/heads/topic/m5"] == ReferenceDivergence(ahead: 1, behind: 1))
        try await sync.pull(rebase: false)
        #expect(FileManager.default.fileExists(atPath: fixture.directory.appending(path: "remote.txt").path))

        // 推送合并结果后，本地与远端同一提交，领先落后都归零。
        _ = try await sync.push(branch: "topic/m5", remote: "origin", destination: "topic/m5", setUpstream: false)
        let remote = try await runner.run(["ls-remote", bare, "refs/heads/topic/m5"])
        let local = try await references.resolve("HEAD")
        #expect(String(decoding: remote, as: UTF8.self).hasPrefix(local))
        let status = try await runner.status()
        #expect(status.branch.ahead == 0 && status.branch.behind == 0)
    }

    /// 只计算哈希的 hash-object 属于读取，带 -w 的写入仍进入写队列。
    @Test("hash-object 的读写调度")
    func hashObjectScheduling() {
        #expect(RepositoryOperationQueue.isReadOnly(["hash-object", "--no-filters", "--", "file"]))
        #expect(!RepositoryOperationQueue.isReadOnly(["hash-object", "-w", "-t", "tree", "--stdin"]))
    }

    /// 内容哈希随工作区文件变化，文件不存在时为 nil；未出生分支没有最近信息。
    @Test("工作区内容哈希与未出生分支的上下文")
    func worktreeHash() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize()
        let working = WorkingCopyOperations(runner: fixture.runner)
        let file = fixture.directory.appending(path: "内容 [*].txt")
        try Data("one\n".utf8).write(to: file)
        let entry = try #require(try await fixture.runner.status().entries.first)
        let first = try await working.worktreeHash(of: entry)
        let expected = try await fixture.runner.run(["hash-object", "--", entry.path])
        #expect(first == String(decoding: expected, as: UTF8.self).trimmingCharacters(in: .newlines))

        try Data("two\n".utf8).write(to: file)
        #expect(try await working.worktreeHash(of: entry) != first)
        try FileManager.default.removeItem(at: file)
        #expect(try await working.worktreeHash(of: entry) == nil)

        let context = try await working.context(head: nil)
        #expect(context.lastMessage.isEmpty)
        await #expect(throws: RepositoryReadError.self) { try await working.context(head: "--all") }
    }
}
