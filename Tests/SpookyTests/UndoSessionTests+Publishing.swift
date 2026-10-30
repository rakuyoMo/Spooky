import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Publishing

/// 远端上的引用靠反向操作撤销：发布的分支与标签在远端删掉，改名的远端分支改回原名，撤销与重做记在 Activity 的 Remote 页；
/// 远端被别人改过时撤销失败，记录留在撤销栈。
extension UndoSessionTests {
    /// 发布分支撤销后远端没有这个分支、本地分支没有上游，重做后两者都恢复；撤销与重做都记在 Remote 页。
    @Test("发布分支的撤销与重做")
    func publishBranchRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let bare = try await Self.makeRemote(for: fixture)
        defer { try? FileManager.default.removeItem(atPath: bare) }
        let publish = AppLocalization.text("sync.publish")
        let target = ActivityTarget.push("origin", refspec: "refs/heads/main:refs/heads/main")

        _ = try await fixture.runner.run(["remote", "add", "origin", bare])

        try await fixture.perform { Self.publishMain(in: session, target: target) }
        #expect(try await Self.references(in: bare, of: fixture) == ["refs/heads/main"])
        #expect(try await Self.upstream(in: fixture) == "origin")
        #expect(try await Self.settledState(of: session, redo: false) == .available(publish))

        try await fixture.perform { session.undoLastOperation() }
        #expect(try await Self.references(in: bare, of: fixture).isEmpty)
        #expect(try await Self.upstream(in: fixture) == nil)

        try await fixture.perform { session.redoLastOperation() }
        #expect(try await Self.references(in: bare, of: fixture) == ["refs/heads/main"])
        #expect(try await Self.upstream(in: fixture) == "origin")

        // 撤销只连接远端、不推送分支，Remote 页只写远端名；重做与原操作写同一个 refspec
        let undo = Self.activity(UndoManager().undoMenuTitle(forUndoActionName: publish), in: fixture)
        let redo = Self.activity(UndoManager().redoMenuTitle(forUndoActionName: publish), in: fixture)
        #expect(undo?.kind == .remote)
        #expect(undo?.target == .push("origin"))
        #expect(redo?.target == target)
    }

    /// 另一个克隆把发布的分支推进一个提交后撤销：租约拒绝，远端分支不变，记录留在撤销栈。
    @Test("发布的分支被推进后撤销失败")
    func publishBranchLeaseRejected() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let bare = try await Self.makeRemote(for: fixture)
        defer { try? FileManager.default.removeItem(atPath: bare) }
        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        _ = try await fixture.runner.run(["remote", "add", "origin", bare])
        try await fixture.perform {
            Self.publishMain(in: session, target: .push("origin", refspec: "refs/heads/main:refs/heads/main"))
        }

        // 另一个克隆在 main 上提交并推送
        let clone = bare + "-克隆"
        defer { try? FileManager.default.removeItem(atPath: clone) }
        _ = try await fixture.runner.run(["clone", "-q", "--branch", "main", "--", bare, clone])
        _ = try await fixture.runner.run([
            "-C", clone, "-c", "user.name=Other", "-c", "user.email=other@example.invalid",
            "commit", "-q", "--allow-empty", "-m", "其它",
        ])
        _ = try await fixture.runner.run(["-C", clone, "push", "-q", "origin", "main"])
        let pushed = try await fixture.runner.run(["-C", bare, "rev-parse", "refs/heads/main"])

        try await fixture.perform { session.undoLastOperation() }
        #expect(failures.count == 1)
        #expect(try await fixture.runner.run(["-C", bare, "rev-parse", "refs/heads/main"]) == pushed)
        #expect(session.undoHistory?.undoEntries.count == 1)
    }

    /// 发布标签撤销后远端没有这个标签，重做后又有；远端原来就有同名标签时发布不进撤销栈。
    @Test("发布标签的撤销与重做")
    func publishTagRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let bare = try await Self.makeRemote(for: fixture)
        defer { try? FileManager.default.removeItem(atPath: bare) }

        _ = try await fixture.runner.run(["remote", "add", "origin", bare])
        _ = try await fixture.runner.run(["tag", "-a", "-m", "说明", "发布/v1"])
        _ = try await fixture.runner.run(["tag", "v2"])

        try await fixture.perform { Self.publishTag("发布/v1", in: session) }
        #expect(try await Self.references(in: bare, of: fixture) == ["refs/tags/发布/v1"])

        try await fixture.perform { session.undoLastOperation() }
        #expect(try await Self.references(in: bare, of: fixture).isEmpty)

        try await fixture.perform { session.redoLastOperation() }
        #expect(try await Self.references(in: bare, of: fixture) == ["refs/tags/发布/v1"])

        // 远端已有 v2 时发布不新建标签，撤销栈不动
        _ = try await fixture.runner.run(["push", "-q", "origin", "v2"])
        try await fixture.perform { Self.publishTag("v2", in: session) }
        #expect(session.undoHistory?.undoEntries.count == 1)
        #expect(session.undoHistory?.irreversibleTitle == nil)
    }

    /// 重命名远端分支撤销后远端只剩原名字、指向原来的提交，重做后又是新名字。
    @Test("重命名远端分支的撤销与重做")
    func renameRemoteBranchRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let bare = try await Self.makeRemote(for: fixture)
        defer { try? FileManager.default.removeItem(atPath: bare) }
        let root = try await fixture.head()

        _ = try await fixture.runner.run(["remote", "add", "origin", bare])
        _ = try await fixture.runner.run(["push", "-q", "origin", "main"])

        try await fixture.perform {
            session.performGit(
                { runner, output in
                    try await RepositoryReferences(runner: runner)
                        .renameRemoteBranch("main", on: "origin", to: "功能/改名", onOutput: output)
                },
                title: AppLocalization.text("branch.renameRemote"),
                target: .push("origin"),
                undo: .renamingRemoteBranch("main", on: "origin", to: "功能/改名")
            )
        }
        #expect(try await Self.references(in: bare, of: fixture) == ["refs/heads/功能/改名"])

        try await fixture.perform { session.undoLastOperation() }
        #expect(try await Self.references(in: bare, of: fixture) == ["refs/heads/main"])
        #expect(try await fixture.runner.run(["-C", bare, "rev-parse", "refs/heads/main"]) == Data((root + "\n").utf8))

        try await fixture.perform { session.redoLastOperation() }
        #expect(try await Self.references(in: bare, of: fixture) == ["refs/heads/功能/改名"])
    }
}

// MARK: - Helpers

extension UndoSessionTests {
    /// 像发布分支的对话框一样经写队列发布 main，发布后跟踪推上去的远端分支。
    static func publishMain(in session: RepositorySession, target: ActivityTarget) {
        session.performGit(
            { runner, output in
                _ = try await RepositorySync(runner: runner)
                    .push(branch: "main", remote: "origin", destination: "main", setUpstream: true, onOutput: output)
            },
            title: AppLocalization.text("sync.publish"),
            target: target,
            undo: .publishingBranch("main", to: "origin", as: "main", setsUpstream: true)
        )
    }

    /// 像发布标签的对话框一样经写队列把标签发布到 origin。
    static func publishTag(_ name: String, in session: RepositorySession) {
        session.performGit(
            { runner, output in try await RepositoryTags(runner: runner).publish(name, to: "origin", onOutput: output) },
            title: AppLocalization.text("tag.publish"),
            target: .push("origin"),
            undo: .publishingTag(name, to: "origin")
        )
    }

    /// 裸仓库里全部分支与标签的引用名，按名称排列。
    static func references(in bare: String, of fixture: Fixture) async throws -> [String] {
        let output = try await fixture.runner.run(["-C", bare, "for-each-ref", "--format=%(refname)", "refs/heads", "refs/tags"])
        return String(decoding: output, as: UTF8.self).split(separator: "\n").map(String.init)
    }

    /// 本仓库标题为 `title` 的最近一条 Activity 记录。
    static func activity(_ title: String, in fixture: Fixture) -> RepositoryActivity? {
        fixture.session.activities.items.first { $0.repository == fixture.location && $0.title == title }
    }
}
