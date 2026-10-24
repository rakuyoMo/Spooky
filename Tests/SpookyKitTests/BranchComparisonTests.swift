import Foundation
import Testing

@testable import SpookyKit

// MARK: - BranchComparisonTests

/// 分支整理与基准分支比较的判定只看结构化结果：双向计数、`merge-tree` 的合并状态与 `merge-base` 的退出码。
struct BranchComparisonTests {
    /// 已并入、能快进、能干净合并、有冲突与没有共同历史的分支各得到对应的结论；SHA-1 与 SHA-256 结果一致。
    @Test("与基准分支比较的五种结论", arguments: ["sha1", "sha256"])
    func compare(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        let conflictPath = "dir with space/中文 \"引号\" *?.txt"

        try write("base\n", to: conflictPath, in: fixture)
        _ = try await runner.run(["add", "-A"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])

        // 已并入：顶端是 main 的祖先
        _ = try await runner.run(["branch", "merged"])

        // 有冲突：两侧都改同一个文件
        _ = try await runner.run(["switch", "-q", "-c", "feature/冲突'x'"])
        try write("branch\n", to: conflictPath, in: fixture)
        _ = try await runner.run(["commit", "-q", "-am", "branch edit"])

        // 能干净合并：两侧改不同的文件
        _ = try await runner.run(["switch", "-q", "-c", "clean", "main"])
        try write("other\n", to: "other.txt", in: fixture)
        _ = try await runner.run(["add", "-A"])
        _ = try await runner.run(["commit", "-q", "-m", "clean edit"])

        _ = try await runner.run(["switch", "-q", "main"])
        try write("main\n", to: conflictPath, in: fixture)
        _ = try await runner.run(["commit", "-q", "-am", "main edit"])

        // 能快进：只在 main 之上多了提交
        _ = try await runner.run(["switch", "-q", "-c", "ahead"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "ahead"])

        // 没有共同历史
        _ = try await runner.run(["switch", "-q", "--orphan", "lone"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "lone"])
        _ = try await runner.run(["switch", "-q", "main"])

        let snapshot = try await refs.snapshot()
        let tips = Dictionary(
            uniqueKeysWithValues: snapshot.references.filter(\.isLocal).map { ($0.id, $0.objectID) }
        )
        let base = try #require(tips["refs/heads/main"])
        let branches = tips.filter { $0.key != "refs/heads/main" }
        let result = try await refs.compare(branches, toBase: base)

        #expect(Set(result.keys) == Set(branches.keys))

        let merged = try #require(result["refs/heads/merged"])
        #expect(merged.isMerged)
        #expect(merged.divergence == ReferenceDivergence(ahead: 0, behind: 1))

        #expect(result["refs/heads/ahead"]?.merge == .clean)
        #expect(result["refs/heads/ahead"]?.divergence == ReferenceDivergence(ahead: 1, behind: 0))
        #expect(result["refs/heads/clean"]?.merge == .clean)
        #expect(result["refs/heads/feature/冲突'x'"]?.merge == .conflicts([conflictPath]))

        // 批量预览因没有共同历史失败后逐个预览，只有这一个无法检查
        guard case .unavailable = result["refs/heads/lone"]?.merge else {
            Issue.record("没有共同历史的分支应当无法检查")
            return
        }
    }

    /// 分叉点取自 merge-base；没有共同历史时为 nil，不当作错误。
    @Test("分叉点", arguments: ["sha1", "sha256"])
    func forkPoint(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)

        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "root"])
        let root = try await refs.resolve("HEAD")
        _ = try await runner.run(["switch", "-q", "-c", "topic"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "topic"])
        let topic = try await refs.resolve("HEAD")
        _ = try await runner.run(["switch", "-q", "--orphan", "lone"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "lone"])
        let lone = try await refs.resolve("HEAD")

        #expect(try await refs.forkPoint(of: topic, base: root) == root)
        #expect(try await refs.forkPoint(of: lone, base: root) == nil)

        await #expect(throws: RepositoryReadError.self) {
            try await refs.forkPoint(of: "HEAD", base: root)
        }
    }

    /// 批量输出按段解析：状态、结果树、冲突路径与段尾的空字段；路径可以含换行，段数不符或字段不对都是格式错误。
    @Test("merge-tree 批量输出的解析")
    func parseBatch() throws {
        let tree1 = String(repeating: "a", count: 40)
        let tree256 = String(repeating: "b", count: 64)
        let path = "dir/it's \"引号\" *?\n换行.txt"
        let data = Data("1\0\(tree1)\0\00\0\(tree256)\0\(path)\0other\0\0".utf8)

        #expect(
            try RepositoryReferences.parseMergeTreeBatch(data, count: 2) == [
                MergeTreeBatchResult(isClean: true, conflicts: []),
                MergeTreeBatchResult(isClean: false, conflicts: [path, "other"]),
            ]
        )
        #expect(try RepositoryReferences.parseMergeTreeBatch(Data(), count: 0).isEmpty)

        // 段数与输入不符、状态不是 0 / 1、结果树不是哈希、缺少段尾
        let malformed = [
            (Data("1\0\(tree1)\0\0".utf8), 2),
            (Data("2\0\(tree1)\0\0".utf8), 1),
            (Data("1\0not-a-tree\0\0".utf8), 1),
            (Data("0\0\(tree1)\0a.txt".utf8), 1),
        ]

        for (data, count) in malformed {
            #expect(throws: RepositoryReadError.self) {
                try RepositoryReferences.parseMergeTreeBatch(data, count: count)
            }
        }
    }

    /// Update Branch：合并会先检出要更新的分支，变基把分支接到父分支上；冲突留下进行中的操作，本地改动挡住时不动 HEAD。
    @Test("Update Branch 的合并、变基、冲突与本地改动", arguments: ["sha1", "sha256"])
    func updateBranch(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        let sync = RepositorySync(runner: runner)

        try write("a\n", to: "file.txt", in: fixture)
        _ = try await runner.run(["add", "-A"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])
        _ = try await runner.run(["branch", "merge-me"])
        _ = try await runner.run(["branch", "rebase-me"])
        _ = try await runner.run(["branch", "conflict"])

        // 各分支先有自己的提交，父分支 main 再前进
        for branch in ["merge-me", "rebase-me"] {
            _ = try await runner.run(["switch", "-q", branch])
            try write(branch + "\n", to: branch + ".txt", in: fixture)
            _ = try await runner.run(["add", "-A"])
            _ = try await runner.run(["commit", "-q", "-m", branch])
        }

        _ = try await runner.run(["switch", "-q", "conflict"])
        try write("conflict\n", to: "file.txt", in: fixture)
        _ = try await runner.run(["commit", "-q", "-am", "conflict"])

        _ = try await runner.run(["switch", "-q", "main"])
        try write("main\n", to: "file.txt", in: fixture)
        _ = try await runner.run(["commit", "-q", "-am", "main"])
        let main = try await refs.resolve("main")

        // 合并：从 main 出发更新 merge-me，HEAD 切到 merge-me 并生成合并提交
        try await sync.updateBranch("refs/heads/merge-me", from: "refs/heads/main", rebase: false)
        #expect(try await runner.status().branch.head == "merge-me")
        let mergeParents = try await runner.run(["rev-list", "--parents", "-n", "1", "HEAD"])
        #expect(String(decoding: mergeParents, as: UTF8.self).split(separator: " ").count == 3)

        // 变基：rebase-me 的提交接在 main 之上
        try await sync.updateBranch("refs/heads/rebase-me", from: "refs/heads/main", rebase: true)
        #expect(try await runner.status().branch.head == "rebase-me")
        #expect(try await refs.resolve("rebase-me^") == main)

        // 本地改动挡住时报告工作区不干净，HEAD 不变
        try write("dirty\n", to: "rebase-me.txt", in: fixture)
        await #expect(throws: RepositorySyncError.dirtyWorkingCopy) {
            try await sync.updateBranch("refs/heads/conflict", from: "refs/heads/main", rebase: false)
        }
        #expect(try await runner.status().branch.head == "rebase-me")
        _ = try await runner.run(["checkout", "--", "rebase-me.txt"])

        // 冲突：合并失败后留下进行中的合并
        await #expect(throws: GitError.self) {
            try await sync.updateBranch("refs/heads/conflict", from: "refs/heads/main", rebase: false)
        }
        #expect(try await runner.status().branch.head == "conflict")
        #expect(try await runner.status().entries.contains { $0.kind == .conflicted })

        await #expect(throws: RepositoryReadError.self) {
            try await sync.updateBranch("refs/heads/main", from: "refs/heads/main", rebase: false)
        }
    }

    /// 自动归档写入待审阅标记，取消归档一并清除；跳过与隐藏提示各自独立，随快照读回。
    @Test("分支整理的标记")
    func metadataFlags() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        let branch = "refs/heads/feature/it's-\"合并\""

        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["branch", "feature/it's-\"合并\""])

        try await refs.setArchived(true, branches: [branch], review: true)
        try await refs.setSkipsAutoArchive(true, branches: [branch])
        try await refs.setHidesMergedHint(true, branches: [branch])

        var metadata = try await refs.snapshot().metadata(for: branch)
        #expect(metadata.isArchived && metadata.needsArchiveReview)
        #expect(metadata.skipsAutoArchive && metadata.hidesMergedHint)

        try await refs.markArchiveReviewed(branches: [branch])
        metadata = try await refs.snapshot().metadata(for: branch)
        #expect(metadata.isArchived && !metadata.needsArchiveReview)

        // 撤销自动归档：取消归档同时去掉待审阅标记
        try await refs.setArchived(true, branches: [branch], review: true)
        try await refs.setArchived(false, branches: [branch])
        metadata = try await refs.snapshot().metadata(for: branch)
        #expect(!metadata.isArchived && !metadata.needsArchiveReview)
        #expect(metadata.skipsAutoArchive)

        // 配置里的布尔写法与 Git 一致：只写键也表示真
        let parsed = try BranchMetadata.parse(Data(
            "branch.a.spooky-archive-review\0branch.a.spooky-skip-auto-archive\nno\0branch.a.spooky-hide-merged-hint\nyes\0"
                .utf8
        ))
        let flags = try #require(parsed["refs/heads/a"])
        #expect(flags.needsArchiveReview)
        #expect(!flags.skipsAutoArchive)
        #expect(flags.hidesMergedHint)
    }
}

// MARK: - Helpers

extension BranchComparisonTests {
    /// 在工作区里写一个文件，按需创建目录。
    private func write(_ content: String, to path: String, in fixture: TemporaryRepository) throws {
        let url = fixture.directory.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
    }
}
