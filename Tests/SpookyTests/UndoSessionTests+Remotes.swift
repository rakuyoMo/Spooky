import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Remotes

/// 远端写操作靠反向操作撤销：添加、改名、删除与修改设置都能撤销与重做，前提不符时报仓库已改变，与快照记录交错时照栈的顺序撤销。
extension UndoSessionTests {
    /// 添加、改名与删除远端各自撤销后恢复、重做后再次生效；改名与删除带着远端跟踪分支与跟踪设置一起改回。
    /// 撤销添加之前远端已在外部被删掉：报仓库已改变，撤销栈不动。
    @Test("远端的添加、改名与删除的撤销与重做")
    func remoteLifecycleRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        let bare = try await Self.makeRemote(for: fixture)
        defer { try? FileManager.default.removeItem(atPath: bare) }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        // 添加：撤销后没有这个远端，重做时再添加一次
        try await fixture.perform { Self.addRemote("origin", url: bare, in: session) }

        #expect(try await Self.remoteNames(in: fixture) == ["origin"])
        #expect(try await Self.settledState(of: session, redo: false) == .available("Add Remote"))

        try await fixture.perform { session.undoLastOperation() }
        #expect(try await Self.remoteNames(in: fixture).isEmpty)

        try await fixture.perform { session.redoLastOperation() }
        #expect(try await Self.remoteNames(in: fixture) == ["origin"])

        // 改名：main 的跟踪设置与远端跟踪分支随之改回
        _ = try await fixture.runner.run(["push", "-q", "-u", "origin", "main"])
        try await fixture.perform { Self.renameRemote("origin", to: "fork", in: session) }
        #expect(try await Self.upstream(in: fixture) == "fork")

        try await fixture.perform { session.undoLastOperation() }

        #expect(try await Self.remoteNames(in: fixture) == ["origin"])
        #expect(try await Self.upstream(in: fixture) == "origin")
        #expect(try await Self.trackingReferences(in: fixture) == ["refs/remotes/origin/main"])

        try await fixture.perform { session.redoLastOperation() }
        #expect(try await Self.upstream(in: fixture) == "fork")

        // 删除：远端、远端跟踪分支与 main 的跟踪设置都回来
        try await fixture.perform { Self.removeRemotes(["fork"], in: session) }

        #expect(try await Self.remoteNames(in: fixture).isEmpty)
        #expect(try await Self.upstream(in: fixture) == nil)

        try await fixture.perform { session.undoLastOperation() }

        #expect(try await Self.remoteNames(in: fixture) == ["fork"])
        #expect(try await Self.upstream(in: fixture) == "fork")
        #expect(try await Self.trackingReferences(in: fixture) == ["refs/remotes/fork/main"])

        try await fixture.perform { session.redoLastOperation() }
        #expect(try await Self.remoteNames(in: fixture).isEmpty)

        // 前提不符：添加的远端在外部被删掉后撤销添加
        try await fixture.perform { Self.addRemote("origin", url: bare, in: session) }

        let count = session.undoHistory?.undoEntries.count
        _ = try await fixture.runner.run(["remote", "remove", "origin"])
        await fixture.refresh()

        try await fixture.perform { session.undoLastOperation() }

        #expect(failures.last?.title == AppLocalization.text("undo.error.changed"))
        #expect(session.undoHistory?.undoEntries.count == count)
    }

    /// 去掉推送地址、删除 refspec 与 “获取全部” 各自撤销后配置回到操作前，重做后回到操作后。
    @Test("远端设置的撤销与重做")
    func remoteSettingsRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        let bare = try await Self.makeRemote(for: fixture)
        defer { try? FileManager.default.removeItem(atPath: bare) }

        let notes = "+refs/notes/*:refs/notes/*"
        session.onConfirm = { $0.action() }

        // 远端带着推送地址与另一条获取 refspec
        _ = try await fixture.runner.run(["remote", "add", "origin", bare])
        _ = try await fixture.runner.run(["config", "--local", "remote.origin.pushurl", bare])
        _ = try await fixture.runner.run(["config", "--local", "--add", "remote.origin.fetch", notes])

        let operations: [() -> Void] = [
            { session.confirmUnsetPushURL(of: "origin") },
            { session.confirmRemoveRefspec(notes, from: "origin", push: false) },
            { session.setSkipsFetchAll(true, for: "origin") },
        ]

        for operation in operations {
            let before = try await Self.remoteSettings(in: fixture)
            try await fixture.perform(operation)

            let after = try await Self.remoteSettings(in: fixture)
            #expect(after != before)

            try await fixture.perform { session.undoLastOperation() }
            #expect(try await Self.remoteSettings(in: fixture) == before)

            try await fixture.perform { session.redoLastOperation() }
            #expect(try await Self.remoteSettings(in: fixture) == after)
        }
    }

    /// 先提交、再给 main 跟踪的远端改名，连续撤销两次：改名先改回跟踪设置，提交的快照随后照常通过核对。
    @Test("远端改名与提交交错时的撤销")
    func remoteInterleavedWithSnapshot() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        let bare = try await Self.makeRemote(for: fixture)
        defer { try? FileManager.default.removeItem(atPath: bare) }

        let root = try await fixture.head()

        _ = try await fixture.runner.run(["remote", "add", "origin", bare])
        _ = try await fixture.runner.run(["push", "-q", "-u", "origin", "main"])

        // 暂存、提交，再给远端改名，撤销栈里三项
        try fixture.write("changed\n")
        await fixture.refresh()
        try await fixture.perform { session.stageAll(staged: true) }

        try await fixture.perform {
            session.confirmCommit(("提交", ""), amend: false, signOff: false, skipHooks: false)
        }

        try await fixture.perform { Self.renameRemote("origin", to: "fork", in: session) }
        #expect(session.undoHistory?.undoEntries.count == 3)

        // 先撤销改名，再撤销提交
        try await fixture.perform { session.undoLastOperation() }
        #expect(try await Self.upstream(in: fixture) == "origin")

        try await fixture.perform { session.undoLastOperation() }

        #expect(try await fixture.head() == root)
        #expect(session.undoHistory?.undoEntries.count == 1)
    }
}

// MARK: - Helpers

extension UndoSessionTests {
    /// 在临时目录里建一个裸仓库作远端。
    ///
    /// - Returns: 裸仓库的路径。
    static func makeRemote(for fixture: Fixture) async throws -> String {
        let path = FileManager.default.temporaryDirectory
            .appending(path: "spooky-undo-remote 远端-" + UUID().uuidString)
            .path

        _ = try await fixture.runner.run(["init", "-q", "--bare", path])
        return path
    }

    /// 像添加远端的对话框一样经写队列添加远端。
    static func addRemote(
        _ name: String,
        url: String,
        in session: RepositorySession
    ) {
        session.performGit(
            { runner, output in
                try await RepositoryRemotes(runner: runner).add(
                    name: name,
                    url: url,
                    onOutput: output
                )
            },
            title: "Add Remote",
            undo: .addingRemote(name)
        )
    }

    /// 像改名对话框一样经写队列给远端改名。
    static func renameRemote(
        _ name: String,
        to newName: String,
        in session: RepositorySession
    ) {
        session.performGit(
            { runner, _ in try await RepositoryRemotes(runner: runner).rename(name, to: newName) },
            title: "Rename Remote",
            undo: .renamingRemote(name, to: newName)
        )
    }

    /// 像删除对话框一样经写队列删除远端。
    static func removeRemotes(_ names: [String], in session: RepositorySession) {
        session.performGit(
            { runner, _ in
                for name in names {
                    try await RepositoryRemotes(runner: runner).remove(name)
                }
            },
            title: "Delete Remote",
            undo: .removingRemotes(names)
        )
    }

    /// 仓库里的远端名。
    static func remoteNames(in fixture: Fixture) async throws -> [String] {
        try await RepositoryRemotes(runner: fixture.runner).configurations().map(\.name)
    }

    /// 仓库配置里全部 `remote.` 开头的项，按配置文件中的顺序。
    static func remoteSettings(in fixture: Fixture) async throws -> String {
        let result = try await fixture.runner.execute(
            ["config", "-z", "--local", "--get-regexp", "^remote\\."],
            acceptedExitCodes: [0, 1]
        )

        return String(decoding: result.standardOutput, as: UTF8.self)
    }

    /// main 跟踪的远端；没有跟踪时为 nil。
    static func upstream(in fixture: Fixture) async throws -> String? {
        let result = try await fixture.runner.execute(
            ["config", "--local", "branch.main.remote"],
            acceptedExitCodes: [0, 1]
        )

        let value = String(decoding: result.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
        return value.isEmpty ? nil : value
    }

    /// 全部远端跟踪分支的引用名。
    static func trackingReferences(in fixture: Fixture) async throws -> [String] {
        let output = try await fixture.runner.run(["for-each-ref", "--format=%(refname)", "refs/remotes"])

        return String(decoding: output, as: UTF8.self)
            .split(separator: "\n")
            .map(String.init)
    }
}
