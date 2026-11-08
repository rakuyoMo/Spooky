import Foundation
import Testing

@testable import SpookyKit

/// 置顶、归档、父分支与分支整理的标记写在分支配置段里，随分支改名移动、随删除清除。
struct BranchMetadataTests {
    /// 名称含点、斜杠、引号与中文的分支也能按完整引用名读回，取消标记后键被删除；
    /// 改名带走整个分支配置段，删除分支时一并清除，不留下孤立的键；
    /// 自动归档写入待审阅标记，取消归档一并清除，跳过自动归档与归档各自独立；
    /// 只接受完整的本地分支引用，父分支不能是自身，也不能是缩写。
    @Test("置顶、归档、父分支与整理标记的读写，随改名移动、随删除清除，拒绝无效的分支")
    func roundTrip() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)

        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["branch", "feature/v1.2/功能"])

        #expect(try await refs.metadata().isEmpty)

        // 写入与读回
        let branch = "refs/heads/feature/v1.2/功能"
        try await refs.setPinned(true, branches: [branch, "refs/heads/main"])
        try await refs.setArchived(true, branches: [branch])
        try await refs.setParent("refs/heads/main", of: branch)

        let written = try await refs.metadata()

        #expect(written[branch] == BranchMetadata(isPinned: true, isArchived: true, parent: "refs/heads/main"))
        #expect(written["refs/heads/main"] == BranchMetadata(isPinned: true))

        // 取消标记；取消一个本来就没有的标记同样成功
        try await refs.setPinned(false, branches: [branch, "refs/heads/main"])
        try await refs.setArchived(false, branches: [branch])
        try await refs.setParent(nil, of: branch)
        try await refs.setArchived(false, branches: ["refs/heads/main"])

        #expect(try await refs.metadata().isEmpty)

        // 改名带走整个分支配置段，删除分支时一并清除
        _ = try await runner.run(["branch", "topic"])
        try await refs.setPinned(true, branches: ["refs/heads/topic"])
        try await refs.setParent("refs/heads/main", of: "refs/heads/topic")

        _ = try await runner.run(["branch", "-m", "topic", "renamed"])

        let renamed = try await refs.metadata()

        #expect(renamed["refs/heads/topic"] == nil)
        #expect(renamed["refs/heads/renamed"] == BranchMetadata(isPinned: true, parent: "refs/heads/main"))

        _ = try await runner.run(["branch", "-D", "renamed"])

        #expect(try await refs.metadata().isEmpty)

        // 分支整理的标记：自动归档带待审阅标记，审阅后只去掉待审阅
        let quoted = "refs/heads/feature/it's-\"合并\""
        _ = try await runner.run(["branch", "feature/it's-\"合并\""])

        try await refs.setArchived(true, branches: [quoted], review: true)
        try await refs.setSkipsAutoArchive(true, branches: [quoted])

        var metadata = try await refs.snapshot().metadata(for: quoted)

        #expect(metadata.isArchived && metadata.needsArchiveReview)
        #expect(metadata.skipsAutoArchive)

        try await refs.markArchiveReviewed(branches: [quoted])
        metadata = try await refs.snapshot().metadata(for: quoted)

        #expect(metadata.isArchived && !metadata.needsArchiveReview)

        // 撤销自动归档：取消归档同时去掉待审阅标记，跳过自动归档保留
        try await refs.setArchived(true, branches: [quoted], review: true)
        try await refs.setArchived(false, branches: [quoted])
        metadata = try await refs.snapshot().metadata(for: quoted)

        #expect(!metadata.isArchived && !metadata.needsArchiveReview)
        #expect(metadata.skipsAutoArchive)

        // 无效的分支在执行 Git 之前就被拒绝
        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await refs.setPinned(true, branches: ["main"])
        }

        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await refs.setArchived(true, branches: ["refs/remotes/origin/main"])
        }

        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await refs.setPinned(true, branches: [])
        }

        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await refs.setParent("main", of: "refs/heads/topic")
        }

        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await refs.setParent("refs/heads/topic", of: "refs/heads/topic")
        }
    }

    /// 布尔值按 Git 的写法解析，只写键不写值也算真；键里缺少分支名时拒绝整份输出。
    @Test("解析布尔写法、空值与格式错误")
    func parsing() throws {
        let records = [
            "branch.a.spooky-pinned\nyes",
            "branch.a.spooky-archived",
            "branch.b.c.spooky-pinned\nOff",
            "branch.b.c.spooky-parent\nrefs/heads/a",
            "branch.d.spooky-parent\n",
            "branch.e.spooky-archive-review",
            "branch.e.spooky-skip-auto-archive\nno",
            "branch.e.spooky-archived\nyes",
        ]

        let data = Data((records.joined(separator: "\u{0}") + "\u{0}").utf8)
        let parsed = try BranchMetadata.parse(data)

        #expect(parsed["refs/heads/a"] == BranchMetadata(isPinned: true, isArchived: true))
        #expect(parsed["refs/heads/b.c"] == BranchMetadata(parent: "refs/heads/a"))
        #expect(parsed["refs/heads/d"] == BranchMetadata())

        // 分支整理的标记同样按布尔写法解析
        let flags = try #require(parsed["refs/heads/e"])

        #expect(flags.needsArchiveReview && !flags.skipsAutoArchive && flags.isArchived)

        #expect(throws: RepositoryReadError.malformedOutput("branch config")) {
            try BranchMetadata.parse(Data("branch.spooky-pinned\ntrue\u{0}".utf8))
        }
    }
}
