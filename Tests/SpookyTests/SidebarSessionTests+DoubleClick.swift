import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - DoubleClick

extension SidebarSessionTests {
    /// 双击 HEAD 分支什么都不做；仓库正在写入时双击其它分支与标签响铃；在别的工作树检出的本地分支打开那个工作树；
    /// 远端分支有不跟踪它的同名本地分支时先询问，Continue 后只改上游并检出，本地提交不被重置，失败时按真实结果说明。
    @Test("双击 HEAD、不能检出、别的工作树与同名的远端分支")
    func doubleClickRules() async throws {
        let parent = FileManager.default.temporaryDirectory
            .appending(path: "spooky-double-click-" + UUID().uuidString)

        let directory = parent.appending(path: "repo")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        let file = directory.appending(path: "a.txt")

        try Data("main\n".utf8).write(to: file)
        _ = try await runner.run(["add", "a.txt"])
        _ = try await runner.run(["commit", "-q", "-m", "main"])
        _ = try await runner.run(["remote", "add", "origin", directory.path])
        _ = try await runner.run(["tag", "v1"])

        // 本地分支各有自己的提交，同名的远端分支停在 main 上
        for name in ["other", "busy", "blocked", "parked"] {
            _ = try await runner.run(["switch", "-q", "-c", name, "main"])
            try Data((name + "\n").utf8).write(to: file)
            _ = try await runner.run(["commit", "-q", "-am", name])
            _ = try await runner.run(["update-ref", "refs/remotes/origin/" + name, "main"])
        }

        // parked 在打开窗口之前就已在别的工作树检出
        _ = try await runner.run(["switch", "-q", "main"])
        let parked = parent.appending(path: "parked").path
        _ = try await runner.run(["worktree", "add", "-q", parked, "parked"])

        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        defer { session.close() }

        session.display(location)
        session.refresh()
        await settle(session)

        try checkUnavailable(in: session, location: location)
        try await checkWorktreeRouting(in: session, worktree: parked)
        try await checkTrackingCheckout(in: session, runner: runner, parent: parent)
    }
}

// MARK: - Private

extension SidebarSessionTests {
    /// 仓库正在写入时，双击其它本地分支、远端分支与标签都响铃；双击 HEAD 分支不响铃，平时也不执行任何 Git。
    private func checkUnavailable(in session: RepositorySession, location: RepositoryLocation) throws {
        let references = session.history.snapshot?.references ?? []
        let main = try #require(references.first { $0.id == "refs/heads/main" })

        session.doubleClick(main, in: .currentWindow) { Issue.record("HEAD 分支不响铃") }
        #expect(session.writeTask == nil)

        // 另一个写操作占着仓库
        #expect(RepositoryWriteLocks.shared.acquire(location))
        defer { RepositoryWriteLocks.shared.release(location) }

        var beeps: [String] = []
        let ids = ["refs/heads/main", "refs/heads/other", "refs/remotes/origin/other", "refs/tags/v1"]

        for id in ids {
            let reference = try #require(references.first { $0.id == id })
            session.doubleClick(reference, in: .currentWindow) { beeps.append(id) }
        }

        #expect(beeps == Array(ids.dropFirst()))
        #expect(session.writeTask == nil)
    }

    /// 在别的工作树检出的本地分支：双击在本窗口打开那个工作树，按住 ⌘ 时在新标签页打开，不执行 Git。
    private func checkWorktreeRouting(in session: RepositorySession, worktree: String) async throws {
        var opened: [(location: RepositoryLocation, target: RepositoryOpenTarget)] = []
        session.onOpenRepository = { opened.append(($0, $1)) }

        await until { session.worktrees.branchWorktrees["refs/heads/parked"] != nil }
        let parked = try #require(session.history.branches.first { $0.id == "refs/heads/parked" })

        session.doubleClick(parked, in: .currentWindow) { Issue.record("可以打开工作树时不响铃") }
        session.doubleClick(parked, in: .newTab) { Issue.record("可以打开工作树时不响铃") }

        #expect(opened.map { $0.target } == [.currentWindow, .newTab])
        #expect(session.writeTask == nil)

        // 临时目录经过符号链接，比较两边解析后的路径
        let expected = URL(fileURLWithPath: worktree).resolvingSymlinksInPath().path
        let paths = opened.map { URL(fileURLWithPath: $0.location.path).resolvingSymlinksInPath().path }

        #expect(paths == [expected, expected])
    }

    /// 远端分支有不跟踪它的同名本地分支时先询问：取消不改动任何东西；Continue 后检出本地分支并改设上游，本地提交与未跟踪文件不变；
    /// 询问之后分支被别的工作树占用时不写上游并说明原因；检出被本地修改挡住时说明上游已经改了，HEAD 与提交不变。
    private func checkTrackingCheckout(in session: RepositorySession, runner: GitRunner, parent: URL) async throws {
        var confirmations: [ConfirmationRequest] = []
        var failures: [AppFailure] = []

        session.onConfirm = { confirmations.append($0) }
        session.onFailure = { failures.append($0) }

        // 双击远端分支，返回随之出现的询问
        func confirmation(for name: String) throws -> ConfirmationRequest {
            let references = session.history.snapshot?.references ?? []
            let remote = try #require(references.first { $0.id == "refs/remotes/origin/" + name })
            let count = confirmations.count

            session.doubleClick(remote, in: .currentWindow) { Issue.record("可以检出时不响铃") }

            try #require(confirmations.count == count + 1)
            #expect(session.writeTask == nil)
            return confirmations[count]
        }

        // 取消：HEAD、本地分支的提交与上游都不变
        let other = try await BranchState.read("other", runner: runner)
        let cancelled = try confirmation(for: "other")

        #expect(cancelled.message == AppLocalization.text("branch.trackExisting.message", "other", "origin/other"))
        #expect(try await BranchState.read("other", runner: runner) == other)

        // Continue：检出本地分支并把上游改成远端分支，本地提交与未跟踪文件不变
        let note = parent.appending(path: "repo/note.txt")
        try Data("note\n".utf8).write(to: note)

        try confirmation(for: "other").action()
        await settle(session)

        #expect(try await BranchState.read("other", runner: runner) == BranchState(
            head: "other",
            tip: other.tip,
            upstream: "refs/remotes/origin/other"
        ))

        #expect(try String(contentsOf: note, encoding: .utf8) == "note\n")
        #expect(failures.isEmpty)

        // 询问之后 busy 在别的工作树检出：不写上游，说明分支被占用
        let occupied = try confirmation(for: "busy")
        _ = try await runner.run(["worktree", "add", "-q", parent.appending(path: "busy").path, "busy"])
        let busy = try await BranchState.read("busy", runner: runner)

        occupied.action()
        await settle(session)

        #expect(try await BranchState.read("busy", runner: runner) == busy)
        #expect(failures.map(\.title) == [AppLocalization.text("branch.error.inWorktree.title")])

        // 本地修改挡住检出：上游已经改了，HEAD、分支的提交与本地修改都不变
        let file = parent.appending(path: "repo/a.txt")
        try Data("local\n".utf8).write(to: file)
        let blocked = try await BranchState.read("blocked", runner: runner)

        try confirmation(for: "blocked").action()
        await settle(session)

        #expect(try await BranchState.read("blocked", runner: runner) == BranchState(
            head: blocked.head,
            tip: blocked.tip,
            upstream: "refs/remotes/origin/blocked"
        ))

        #expect(try String(contentsOf: file, encoding: .utf8) == "local\n")
        #expect(failures.last?.title == AppLocalization.text("branch.error.checkoutTracking.title"))
    }
}

// MARK: - BranchState

/// 直接从 Git 读出的 HEAD 所在的分支、某个本地分支的提交与上游；上游为空时是空字符串。
private struct BranchState: Equatable {
    /// HEAD 所在分支的短名。
    let head: String

    /// 本地分支指向的提交。
    let tip: String

    /// 本地分支上游的完整引用名。
    let upstream: String

    /// 直接向 Git 读出 HEAD 所在的分支，与指定本地分支的提交和上游。
    static func read(_ name: String, runner: GitRunner) async throws -> Self {
        let head = try await runner.run(["symbolic-ref", "-q", "--short", "HEAD"])
        let format = "--format=%(objectname)%00%(upstream)"
        let branch = try await runner.run(["for-each-ref", format, "refs/heads/" + name])

        let fields = String(decoding: branch, as: UTF8.self)
            .trimmingCharacters(in: .newlines)
            .components(separatedBy: "\0")

        return Self(
            head: String(decoding: head, as: UTF8.self).trimmingCharacters(in: .newlines),
            tip: fields.first ?? "",
            upstream: fields.count > 1 ? fields[1] : ""
        )
    }
}
