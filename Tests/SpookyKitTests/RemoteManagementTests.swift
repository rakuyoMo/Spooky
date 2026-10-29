import Foundation
import Testing

@testable import SpookyKit

/// 远端的增删改名、地址、refspec 与自动获取排除项只写仓库自己的配置；远端是测试目录里的裸仓库。
struct RemoteManagementTests {
    /// 添加前先连上远端；重名、连不上与非法地址都不留下配置；改名（含只差大小写）与删除带走远端跟踪分支。
    @Test("添加、重命名与删除远端", arguments: ["sha1", "sha256"])
    func lifecycle(objectFormat: String) async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: objectFormat)
        defer { fixture.remove() }

        let runner = fixture.runner
        let remotes = RepositoryRemotes(runner: runner)
        let refs = RepositoryReferences(runner: runner)

        try await remotes.add(name: "team/上游", url: bare)
        _ = try await runner.run(["fetch", "-q", "team/上游"])
        #expect(try await remotes.configurations().map(\.name) == ["origin", "team/上游"])

        await #expect(throws: GitError.self) {
            try await remotes.add(name: "team/上游", url: bare)
        }

        let missing = fixture.directory.appendingPathComponent("missing.git").path
        let unreachable = try await #require(throws: GitError.self) {
            try await remotes.add(name: "missing", url: missing)
        }
        #expect(unreachable.category == .remoteNotFound)

        await #expect(throws: ReferenceError.self) {
            try await remotes.add(name: "bad", url: "-oProxyCommand=touch")
        }
        await #expect(throws: ReferenceError.self) {
            try await remotes.add(name: "a=b", url: bare)
        }
        #expect(try await remotes.configurations().map(\.name) == ["origin", "team/上游"])

        try await remotes.rename("team/上游", to: "fork")
        #expect(try await BranchManagementTests.reference("refs/remotes/fork/main", in: refs) != nil)

        // 只差大小写的改名经临时名字中转，远端跟踪分支跟着改名
        try await remotes.rename("fork", to: "Fork")
        #expect(try await remotes.configurations().map(\.name) == ["Fork", "origin"])
        #expect(try await BranchManagementTests.reference("refs/remotes/Fork/main", in: refs) != nil)

        try await remotes.remove("Fork")
        #expect(try await remotes.configurations().map(\.name) == ["origin"])
        #expect(try await refs.snapshot().references.allSatisfy { !$0.id.hasPrefix("refs/remotes/Fork/") })
    }

    /// 获取与推送地址、refspec 的增改删与跳过自动获取都写进仓库配置，读回的设置与写入一致。
    @Test("修改地址、refspec 与自动获取排除项")
    func settings() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let remotes = RepositoryRemotes(runner: runner)
        let other = fixture.directory.appendingPathComponent("other.git").path
        _ = try await runner.run(["init", "-q", "--bare", other])

        try await remotes.setURL(other, of: "origin", push: true)
        try await remotes.setURL(bare, of: "origin", push: false)

        var origin = try #require(try await remotes.configurations().first)
        #expect(origin.url == bare)
        #expect(origin.effectivePushURL == other)

        try await remotes.unsetPushURL(of: "origin")
        try await remotes.unsetPushURL(of: "origin")
        origin = try #require(try await remotes.configurations().first)
        #expect(origin.effectivePushURL == bare)

        await #expect(throws: GitError.self) {
            try await remotes.setURL(fixture.directory.appendingPathComponent("none.git").path, of: "origin", push: false)
        }

        try await remotes.addRefspec("+refs/tags/*:refs/tags/*", to: "origin", push: false)
        try await remotes.replaceRefspec(
            "+refs/tags/*:refs/tags/*",
            with: "+refs/heads/release/*:refs/remotes/origin/release/*",
            in: "origin",
            push: false
        )
        try await remotes.addRefspec("HEAD:refs/for/main", to: "origin", push: true)

        origin = try #require(try await remotes.configurations().first)
        #expect(
            origin.fetchRefspecs
                == ["+refs/heads/*:refs/remotes/origin/*", "+refs/heads/release/*:refs/remotes/origin/release/*"]
        )
        #expect(origin.pushRefspecs == ["HEAD:refs/for/main"])

        try await remotes.removeRefspec("HEAD:refs/for/main", from: "origin", push: true)
        try await remotes.removeRefspec("HEAD:refs/for/main", from: "origin", push: true)

        await #expect(throws: ReferenceError.self) {
            try await remotes.addRefspec("refs/heads/*:refs/remotes/x", to: "origin", push: false)
        }

        try await remotes.setSkipsFetchAll(true, for: "origin")
        origin = try #require(try await remotes.configurations().first)
        #expect(origin.skipsFetchAll && origin.pushRefspecs.isEmpty)

        try await remotes.setSkipsFetchAll(false, for: "origin")
        origin = try #require(try await remotes.configurations().first)
        #expect(!origin.skipsFetchAll)
    }

    /// 引用快照按远端名给出全部设置的摘要：名字可含点与非 ASCII 字符；只改一个远端的设置只换它的摘要；摘要里不出现地址。
    @Test("快照里远端设置的摘要")
    func settingsDigests() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        _ = try await runner.run(["remote", "add", "up.stream/上游", bare])

        let before = try await refs.snapshot().remoteSettingsDigests
        #expect(Set(before.keys) == ["origin", "up.stream/上游"])
        #expect(before.values.allSatisfy { $0.count == 64 && !$0.contains("/") })
        #expect(try await refs.snapshot().remoteSettingsDigests == before)

        // 只加一条推送地址：这个远端的摘要变了，另一个不变
        _ = try await runner.run([
            "remote",
            "set-url",
            "--push",
            "up.stream/上游",
            "https://example.invalid/x.git",
        ])

        let after = try await refs.snapshot().remoteSettingsDigests
        #expect(after["up.stream/上游"] != before["up.stream/上游"])
        #expect(after["origin"] == before["origin"])
    }
}
