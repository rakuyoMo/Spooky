import Foundation
import Testing

@testable import SpookyKit

/// 置顶、归档与父分支写在分支配置段里，随分支改名移动、随删除清除。
struct BranchMetadataTests {
    /// 名称含点、斜杠与中文的分支也能按完整引用名读回，取消标记后键被删除。
    @Test("置顶、归档与父分支的写入、读回与取消")
    func roundTrip() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["branch", "feature/v1.2/功能"])

        #expect(try await refs.metadata().isEmpty)

        let branch = "refs/heads/feature/v1.2/功能"
        try await refs.setPinned(true, branches: [branch, "refs/heads/main"])
        try await refs.setArchived(true, branches: [branch])
        try await refs.setParent("refs/heads/main", of: branch)

        let written = try await refs.metadata()
        #expect(written[branch] == BranchMetadata(isPinned: true, isArchived: true, parent: "refs/heads/main"))
        #expect(written["refs/heads/main"] == BranchMetadata(isPinned: true))

        try await refs.setPinned(false, branches: [branch, "refs/heads/main"])
        try await refs.setArchived(false, branches: [branch])
        try await refs.setParent(nil, of: branch)

        // 取消一个本来就没有的标记同样成功
        try await refs.setArchived(false, branches: ["refs/heads/main"])
        #expect(try await refs.metadata().isEmpty)
    }

    /// 改名带走整个分支配置段，删除分支时一并清除，不留下孤立的键。
    @Test("分支改名与删除时附加信息随之移动与清除")
    func followsBranchLifecycle() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["branch", "topic"])
        try await refs.setPinned(true, branches: ["refs/heads/topic"])
        try await refs.setParent("refs/heads/main", of: "refs/heads/topic")

        _ = try await runner.run(["branch", "-m", "topic", "renamed"])
        let renamed = try await refs.metadata()
        #expect(renamed["refs/heads/topic"] == nil)
        #expect(renamed["refs/heads/renamed"] == BranchMetadata(isPinned: true, parent: "refs/heads/main"))

        _ = try await runner.run(["branch", "-D", "renamed"])
        #expect(try await refs.metadata().isEmpty)
    }

    /// 只接受完整的本地分支引用；父分支不能是自身，也不能是缩写。
    @Test("拒绝非本地分支、空列表与无效的父分支")
    func rejectsInvalidInput() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let refs = RepositoryReferences(runner: fixture.runner)

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
        ]
        let data = Data((records.joined(separator: "\u{0}") + "\u{0}").utf8)
        let parsed = try BranchMetadata.parse(data)

        #expect(parsed["refs/heads/a"] == BranchMetadata(isPinned: true, isArchived: true))
        #expect(parsed["refs/heads/b.c"] == BranchMetadata(parent: "refs/heads/a"))
        #expect(parsed["refs/heads/d"] == BranchMetadata())

        #expect(throws: RepositoryReadError.malformedOutput("branch config")) {
            try BranchMetadata.parse(Data("branch.spooky-pinned\ntrue\u{0}".utf8))
        }
    }
}
