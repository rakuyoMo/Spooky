import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteUndoTests

/// 远端写操作的撤销：操作前记下的内容能把配置、远端跟踪分支与跟踪设置原样恢复；前提不符时拒绝，不做改动。
struct RemoteUndoTests {
    /// 一次删掉两个远端再撤销：配置的各节与远端跟踪分支（含符号引用）都与删除前相同，撤销与重做比较的仓库状态也相同。
    @Test("撤销删除远端")
    func undoRemove() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let remotes = RepositoryRemotes(runner: runner)
        let name = try await Self.addUpstream(bare, in: runner)

        // main 改为跟踪 up.stream/上游、推送到 origin，另有一项与远端无关的设置；
        // topic 跟踪本地的 main，分支段排在 main 后面、不受删除影响
        _ = try await runner.run(["branch", "-q", "--set-upstream-to=" + name + "/main", "main"])
        _ = try await runner.run(["config", "--local", "branch.main.pushRemote", "origin"])
        _ = try await runner.run(["config", "--local", "branch.main.rebase", "true"])
        _ = try await runner.run(["branch", "-q", "--track", "topic", "main"])
        _ = try await runner.run(["config", "--local", "remote.pushDefault", name])

        let sections = try await Self.sections(in: runner)
        let references = try await Self.trackingReferences(in: runner)
        let state = try await RepositoryUndo(runner: runner).capture()

        let record = try await remotes.removalRecord(of: [name, "origin"])
        try await remotes.remove(name)
        try await remotes.remove("origin")
        #expect(try await Self.trackingReferences(in: runner).isEmpty)

        try await remotes.undoRemove(record)
        #expect(try await Self.sections(in: runner) == sections)
        #expect(try await Self.trackingReferences(in: runner) == references)
        #expect(try await RepositoryUndo(runner: runner).capture() == state)
    }

    /// 改名与修改设置的撤销：远端跟踪分支随改名改回；地址、refspec 与 “获取全部” 整段换回，refspec 的先后不变。
    @Test("撤销改名与修改设置")
    func undoRenameAndSettings() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let remotes = RepositoryRemotes(runner: runner)
        let sections = try await Self.sections(in: runner)
        let references = try await Self.trackingReferences(in: runner)

        try await remotes.rename("origin", to: "fork")
        try await remotes.undoRename("origin", to: "fork")
        #expect(try await Self.sections(in: runner) == sections)
        #expect(try await Self.trackingReferences(in: runner) == references)

        let settings = try await remotes.settings(of: "origin")
        try await remotes.setURL(bare, of: "origin", push: true)
        try await remotes.addRefspec("+refs/tags/*:refs/tags/*", to: "origin", push: false)
        try await remotes.addRefspec("HEAD:refs/for/main", to: "origin", push: true)
        try await remotes.setSkipsFetchAll(true, for: "origin")
        #expect(try await Self.sections(in: runner) != sections)

        try await remotes.restoreSettings(settings, of: "origin")
        #expect(try await Self.sections(in: runner) == sections)
    }

    /// 仓库在操作之后又被改动、撤销的前提不再成立时拒绝撤销，配置保持原样。
    @Test("前提不符时拒绝撤销")
    func changedRepository() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let remotes = RepositoryRemotes(runner: runner)

        // 删除后又加回同名的远端
        let record = try await remotes.removalRecord(of: ["origin"])
        try await remotes.remove("origin")
        try await remotes.add(name: "origin", url: bare)

        var sections = try await Self.sections(in: runner)
        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await remotes.undoRemove(record) }
        #expect(try await Self.sections(in: runner) == sections)

        // 删除后分支段里与远端无关的项被改过
        try await remotes.remove("origin")
        _ = try await runner.run(["config", "--local", "branch.main.rebase", "true"])
        sections = try await Self.sections(in: runner)
        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await remotes.undoRemove(record) }
        #expect(try await Self.sections(in: runner) == sections)

        // 加上的远端已被删掉；改名前的名字又有了远端；改设置的远端已不在
        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await remotes.undoAdd("origin") }

        try await remotes.add(name: "origin", url: bare)
        try await remotes.add(name: "fork", url: bare)
        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await remotes.undoRename("origin", to: "fork") }
        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await remotes.restoreSettings([], of: "missing") }
        #expect(try await remotes.configurations().map(\.name) == ["fork", "origin"])
    }
}

// MARK: - Helpers

extension RemoteUndoTests {
    /// 加上名字含点与中文的远端：推送地址、两条获取 refspec、不获取标签，获取后有远端跟踪分支与 HEAD 符号引用。
    ///
    /// - Returns: 远端名。
    static func addUpstream(_ bare: String, in runner: GitRunner) async throws -> String {
        let name = "up.stream/上游"

        _ = try await runner.run(["remote", "add", "--", name, bare])
        _ = try await runner.run(["config", "--local", "remote." + name + ".pushurl", bare])
        _ = try await runner.run(["config", "--local", "--add", "remote." + name + ".fetch", "+refs/tags/*:refs/tags/*"])
        _ = try await runner.run(["config", "--local", "remote." + name + ".tagOpt", "--no-tags"])
        _ = try await runner.run(["fetch", "-q", "--", name])
        _ = try await runner.run(["symbolic-ref", "refs/remotes/" + name + "/HEAD", "refs/remotes/" + name + "/main"])
        return name
    }

    /// 仓库自己的配置按节排列：恢复时整节重写会移到文件末尾，节与节的先后不比较，节内各项的先后照比。
    static func sections(in runner: GitRunner) async throws -> [String] {
        let lines = String(decoding: try await runner.run(["config", "--local", "--list"]), as: UTF8.self)
            .split(separator: "\n")
            .map(String.init)

        let grouped = Dictionary(grouping: lines) { line in
            let key = line.prefix { $0 != "=" }
            return String(key[..<(key.lastIndex(of: ".") ?? key.endIndex)])
        }

        return grouped.keys.sorted().flatMap { grouped[$0] ?? [] }
    }

    /// 全部远端跟踪分支：引用名、对象与符号引用指向的引用名。
    static func trackingReferences(in runner: GitRunner) async throws -> [String] {
        try await String(
            decoding: runner.run(["for-each-ref", "--format=%(refname) %(objectname) %(symref)", "refs/remotes"]),
            as: UTF8.self
        )
        .split(separator: "\n")
        .map(String.init)
    }
}
