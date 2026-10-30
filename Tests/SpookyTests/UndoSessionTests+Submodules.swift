import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Submodules

/// 子模块的添加、删除、移动、改名与本地设置靠反向操作撤销：撤销后回到操作前，重做时再执行一次，添加的重做复用留下的 Git 目录；
/// 写进 `.gitmodules` 的设置按快照撤销，强制删除丢掉的改动找不回，不能撤销。
extension UndoSessionTests {
    /// 添加后撤销，子模块与 `.gitmodules` 都不在了，上游改名后重做仍能加回来；删除后撤销，子模块回来且是干净的，重做再删掉。
    @Test("子模块的添加与删除的撤销与重做")
    func submoduleAdditionAndRemoval() async throws {
        let fixture = try await Fixture(allowsFileSubmodules: true)
        defer { fixture.remove() }
        let session = fixture.session
        let upstream = try await Self.makeUpstream()
        defer { try? FileManager.default.removeItem(at: upstream.directory) }

        try await fixture.perform { _ = session.addSubmodule(url: upstream.path, path: "依赖/lib") }
        #expect(try await Self.submodules(in: fixture).map(\.path) == ["依赖/lib"])
        #expect(
            try await Self.settledState(of: session, redo: false) == .available(AppLocalization.text("submodule.add"))
        )

        try await fixture.perform { session.undoLastOperation() }
        #expect(try await Self.submodules(in: fixture).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fixture.directory.appending(path: ".gitmodules").path))

        // 上游改名后重做：复用留下的 Git 目录，不再克隆
        try FileManager.default.moveItem(atPath: upstream.path, toPath: upstream.path + " 旧")
        try await fixture.perform { session.redoLastOperation() }
        #expect(try await Self.submodules(in: fixture).map(\.path) == ["依赖/lib"])

        _ = try await fixture.runner.run(["commit", "-q", "-m", "子模块"])
        await fixture.refresh()

        let submodule = try #require(try await Self.submodules(in: fixture).first)
        try await fixture.perform { _ = session.deleteSubmodule(submodule, keepsWorkingTree: false, force: false) }
        #expect(try await Self.submodules(in: fixture).isEmpty)

        try await fixture.perform { session.undoLastOperation() }
        #expect(try await Self.submodules(in: fixture).map(\.state) == [.clean])

        try await fixture.perform { session.redoLastOperation() }
        #expect(try await Self.submodules(in: fixture).isEmpty)
    }

    /// 移动（同时改名）、改名、本地配置里的地址、忽略模式与更新策略、`.gitmodules` 里的忽略模式各自撤销后回到操作前，
    /// 重做后回到操作后；撤销菜单写的是各自的操作名，选项按设置还是删除区分。
    @Test("子模块的移动、改名与设置的撤销与重做")
    func submoduleChangesRoundTrip() async throws {
        let fixture = try await Fixture(allowsFileSubmodules: true)
        defer { fixture.remove() }
        let session = fixture.session
        let submodule = try await Self.addCommittedSubmodule(in: fixture)
        defer { try? FileManager.default.removeItem(at: submodule.upstream) }

        // 本地配置里原来有更新策略，供删除选项的一项使用
        _ = try await fixture.runner.run(["config", "--local", "submodule.lib.update", "rebase"])
        await fixture.refresh()

        let operations: [(title: String, start: () -> Void)] = [
            ("submodule.move", { _ = session.moveSubmodule(submodule.value, to: "外层/新 位置", renaming: true) }),
            ("submodule.rename", { _ = session.renameSubmodule(submodule.value, to: "新名") }),
            (
                "submodule.editURL",
                { _ = session.setSubmoduleURL("https://example.com/lib.git", for: submodule.value, in: .local) }
            ),
            (
                "submodule.setIgnoreMode",
                { session.setSubmoduleOption(.ignore, to: "all", for: submodule.value, in: .local) }
            ),
            (
                "submodule.unsetUpdateStrategy",
                { session.setSubmoduleOption(.update, to: nil, for: submodule.value, in: .local) }
            ),
            (
                "submodule.setIgnoreMode",
                { session.setSubmoduleOption(.ignore, to: "dirty", for: submodule.value, in: .shared) }
            ),
        ]

        for operation in operations {
            let before = try await Self.submoduleState(in: fixture)
            try await fixture.perform(operation.start)
            let after = try await Self.submoduleState(in: fixture)
            #expect(after != before)

            // 撤销菜单写的是这次操作的名称
            let title = AppLocalization.text(operation.title)
            #expect(try await Self.settledState(of: session, redo: false) == .available(title))

            try await fixture.perform { session.undoLastOperation() }
            #expect(try await Self.submoduleState(in: fixture) == before)

            try await fixture.perform { session.redoLastOperation() }
            #expect(try await Self.submoduleState(in: fixture) == after)

            // 回到操作前，下一个操作仍用同一个子模块
            try await fixture.perform { session.undoLastOperation() }
        }
    }

    /// 子模块里有改动时强制删除：改动找不回，这次删除不能撤销，之前的撤销记录也一并清空。
    @Test("强制删除有改动的子模块不能撤销")
    func forcedSubmoduleRemoval() async throws {
        let fixture = try await Fixture(allowsFileSubmodules: true)
        defer { fixture.remove() }
        let session = fixture.session
        let submodule = try await Self.addCommittedSubmodule(in: fixture)
        defer { try? FileManager.default.removeItem(at: submodule.upstream) }

        try await fixture.createBranch("topic")
        try Data("改动\n".utf8).write(to: fixture.directory.appending(path: "lib/a.txt"))
        await fixture.refresh()

        try await fixture.perform { _ = session.deleteSubmodule(submodule.value, keepsWorkingTree: false, force: true) }
        #expect(try await Self.submodules(in: fixture).isEmpty)

        let title = AppLocalization.text("submodule.deleteSubmodules")
        #expect(try await Self.settledState(of: session, redo: false) == .irreversible(title))
        #expect(session.undoHistory?.undoEntries.isEmpty ?? false)
    }
}

// MARK: - Submodule Helpers

extension UndoSessionTests {
    /// 临时目录里有一个提交的上游仓库，作为子模块的地址。
    ///
    /// - Returns: 临时目录与上游仓库的路径；用完删掉临时目录。
    static func makeUpstream() async throws -> (directory: URL, path: String) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-undo-submodule 子模块-" + UUID().uuidString)
        let upstream = directory.appending(path: "上游 lib")
        try FileManager.default.createDirectory(at: upstream, withIntermediateDirectories: true)

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: upstream.path))
        try Data("一\n".utf8).write(to: upstream.appending(path: "a.txt"))
        _ = try await runner.run(["add", "a.txt"])
        _ = try await runner.run(["commit", "-q", "-m", "上游"])

        return (directory, upstream.path)
    }

    /// 在仓库里加入路径为 `lib` 的子模块并提交，再读取一次完整状态。
    ///
    /// - Returns: 加入的子模块与上游所在的临时目录；用完删掉临时目录。
    static func addCommittedSubmodule(in fixture: Fixture) async throws -> (value: Submodule, upstream: URL) {
        let upstream = try await makeUpstream()

        try await RepositorySubmodules(runner: fixture.runner)
            .add(url: upstream.path, path: "lib", reusesGitDirectory: false)
        _ = try await fixture.runner.run(["commit", "-q", "-m", "子模块"])
        await fixture.refresh()

        return (try #require(try await submodules(in: fixture).first), upstream.directory)
    }

    /// 仓库现在的子模块。
    static func submodules(in fixture: Fixture) async throws -> [Submodule] {
        try await RepositorySubmodules(runner: fixture.runner).list()
    }

    /// 子模块相关的现状：`.gitmodules` 的原文、本地配置里的子模块段与索引。
    static func submoduleState(in fixture: Fixture) async throws -> [Data] {
        let settings = try await fixture.runner.execute(
            ["config", "-z", "--local", "--get-regexp", #"^submodule\."#],
            acceptedExitCodes: [0, 1]
        )

        return [
            (try? Data(contentsOf: fixture.directory.appending(path: ".gitmodules"))) ?? Data(),
            settings.standardOutput,
            try await fixture.runner.run(["ls-files", "-s", "-z"]),
        ]
    }
}
