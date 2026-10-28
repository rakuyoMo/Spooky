import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - UndoSessionTests

/// 按仓库的撤销与重做：写操作的登记、菜单的标题与不可用原因、窗口的撤销对象，以及经写队列的执行。
@MainActor
struct UndoSessionTests {
    /// 提交可以撤销：撤销后提交前暂存的改动回到暂存区，重做后提交回来；菜单标题由撤销管理器生成。
    @Test("提交的撤销与重做")
    func commitRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let root = try await fixture.head()
        let stage = AppLocalization.text("working.stage")
        let commit = AppLocalization.text("working.commit")

        try fixture.write("changed\n")
        await fixture.refresh()
        try await fixture.perform { session.stageAll(staged: true) }
        try await fixture.perform {
            session.confirmCommit(("提交 [x]", ""), amend: false, signOff: false, skipHooks: false)
        }

        let committed = try await fixture.head()
        #expect(committed != root)
        #expect(try await Self.settledState(of: session, redo: false) == .available(commit))

        // 撤销提交：HEAD 回到原处，改动回到暂存区，下一项是暂存
        try await fixture.perform { session.undoLastOperation() }
        #expect(try await fixture.head() == root)
        #expect(session.status?.entries.first?.staged == .modified)
        #expect(try await Self.settledState(of: session, redo: false) == .available(stage))
        #expect(try await Self.settledState(of: session, redo: true) == .available(commit))

        try await fixture.perform { session.redoLastOperation() }
        #expect(try await fixture.head() == committed)
        #expect(try await Self.settledState(of: session, redo: true) == .empty)

        // 撤销与重做记进 Activity，名称由撤销管理器生成
        let titles = RepositoryActivities.shared.items
            .filter { $0.repository == fixture.location }
            .map(\.title)
        #expect(titles.contains(UndoManager().undoMenuTitle(forUndoActionName: commit)))
    }

    /// 丢弃所选的行可以撤销，误丢的改动能找回：撤销后文件回到丢弃前，重做再丢弃一次。
    @Test("丢弃行的撤销与重做")
    func discardLinesRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session

        session.onConfirm = { _, _, action, _ in action() }

        try fixture.write("base\nadded\n")
        await fixture.refresh()

        // 选中文件，等工作区一侧的 Diff 读完
        let entry = try #require(session.status?.entries.first)
        let row = StatusRowID(path: entry.path, kind: entry.kind)
        session.selectedID = row
        session.selectedIDs = [row]
        try await FileViewsTests.wait { session.diffSnapshot?.diff != nil }

        let file = try #require(session.diffSnapshot?.diff?.files.first)
        let hunk = try #require(file.hunks.first)
        let changes = hunk.lines.filter(\.isChange)
        let line = try #require(changes.first)

        try await fixture.perform { session.apply(file: file.id, hunk: hunk.id, lines: [line.id], discard: true) }
        #expect(try fixture.read() == "base\n")

        try await fixture.perform { session.undoLastOperation() }
        #expect(try fixture.read() == "base\nadded\n")

        try await fixture.perform { session.redoLastOperation() }
        #expect(try fixture.read() == "base\n")
    }

    /// 不能撤销的写操作清空撤销栈，菜单写明上一个操作不能撤销；自动获取这类不登记的操作不改动撤销栈。
    @Test("不能撤销的操作不入栈")
    func irreversibleOperations() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session

        try await fixture.createBranch("topic")
        try await fixture.perform {
            session.performGit({ _, _ in }, title: "Background", undo: .unrecorded)
        }

        #expect(try await Self.settledState(of: session, redo: false) == .available("Branch"))

        // 没有声明的写操作按不能撤销处理
        try await fixture.perform {
            session.performGit(
                { runner, _ in _ = try await runner.run(["config", "--local", "x.y", "z"]) },
                title: "Push"
            )
        }

        #expect(try await Self.settledState(of: session, redo: false) == .irreversible("Push"))
        #expect(session.undoHistory?.undoEntries.isEmpty ?? false)
    }

    /// 操作之后仓库在外部又被改动：菜单写明仓库已变化；看起来没变、内容却变了时，执行前的完整核对拒绝并说明原因。
    @Test("仓库在操作后又被改动")
    func changedRepository() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let stage = AppLocalization.text("working.stage")
        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        try fixture.write("changed\n")
        await fixture.refresh()
        try await fixture.perform { session.stageAll(staged: true) }
        #expect(try await Self.settledState(of: session, redo: false) == .available(stage))

        // 外部新建分支：界面的引用快照与记录不同
        _ = try await fixture.runner.run(["branch", "outside"])
        await fixture.refresh()
        try await FileViewsTests.wait { Self.hasBranch("outside", in: session) }
        #expect(
            try await Self.settledState(of: session, redo: false)
                == .blocked(stage, reason: "undo.reason.changed")
        )

        // 删掉外部分支后又一致
        _ = try await fixture.runner.run(["branch", "-D", "outside"])
        await fixture.refresh()
        #expect(try await Self.settledState(of: session, redo: false) == .available(stage))

        // 文件带着未暂存的改动时新建分支，之后再改一次这个文件：文件状态不变，只有完整核对能发现
        try fixture.write("changed twice\n")
        await fixture.refresh()
        try await fixture.createBranch("topic")

        try fixture.write("changed three times\n")
        await fixture.refresh()
        #expect(try await Self.settledState(of: session, redo: false) == .available("Branch"))

        try await fixture.perform { session.undoLastOperation() }
        #expect(failures.last?.title == AppLocalization.text("undo.error.changed"))
        #expect(session.undoHistory?.undoEntries.count == 2)
        #expect(try fixture.read() == "changed three times\n")
    }

    /// 写操作进行中与合并停在冲突上时都不能撤销，原因写明有正在进行的操作。
    @Test("操作进行中不能撤销")
    func busy() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let runner = fixture.runner

        try await fixture.createBranch("topic")

        // 写操作期间
        session.performGit(
            { _, _ in try await Task.sleep(for: .milliseconds(300)) },
            title: "Wait",
            undo: .unrecorded
        )
        #expect(session.undoMenuState(redo: false) == .blocked("Branch", reason: "undo.reason.busy"))
        await session.writeTask?.value
        await session.waitForRefresh()

        // 合并停在冲突上
        _ = try await runner.run(["switch", "-q", "topic"])
        try fixture.write("topic\n")
        _ = try await runner.run(["commit", "-q", "-a", "-m", "topic"])
        _ = try await runner.run(["switch", "-q", "main"])
        try fixture.write("main\n")
        _ = try await runner.run(["commit", "-q", "-a", "-m", "main"])
        _ = try await runner.execute(["merge", "-q", "topic"], acceptedExitCodes: [0, 1])

        await fixture.refresh()
        try await FileViewsTests.wait { session.context?.operation == .merge }
        #expect(session.undoMenuState(redo: false) == .blocked("Branch", reason: "undo.reason.busy"))
    }

    /// 同一仓库开在两个窗口里共用撤销栈：在一个窗口里做的操作可以在另一个窗口里撤销。
    @Test("两个窗口共用撤销栈")
    func sharedHistory() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let other = RepositorySession(makeRunner: { [runner = fixture.runner] _ in runner })
        defer { other.close() }

        other.display(fixture.location)
        try await fixture.createBranch("topic")

        other.refresh(full: true)
        await other.waitForRefresh()
        try await FileViewsTests.wait { Self.hasBranch("topic", in: other) }
        #expect(other.undoHistory === fixture.session.undoHistory)
        #expect(try await Self.settledState(of: other, redo: false) == .available("Branch"))

        other.undoLastOperation()
        await other.writeTask?.value

        let lookup = try await fixture.runner.execute(
            ["rev-parse", "-q", "--verify", "refs/heads/topic"],
            acceptedExitCodes: [1]
        )
        #expect(lookup.exitCode == 1)
    }

    /// 窗口把 Edit 菜单的撤销交给仓库的撤销管理器：标题是 “Undo <操作名>”，编辑文字时换成文字的撤销。
    @Test("窗口的撤销对象与菜单标题")
    func windowUndoManager() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let defaults = try #require(UserDefaults(suiteName: fixture.directory.appending(path: "defaults").path))
        let controller = RepositoryWindowController(
            coordinator: SpookyApplicationController(bookmarks: RepositoryBookmarks(defaults: defaults)),
            session: fixture.session
        )
        defer { controller.window?.close() }

        controller.display(fixture.location)
        await fixture.session.waitForRefresh()
        let window = try #require(controller.window)
        let item = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")

        #expect(window.undoManager === controller.repositoryUndoManager)
        #expect(!window.validateUserInterfaceItem(item))

        try await fixture.createBranch("topic")
        _ = try await Self.settledState(of: fixture.session, redo: false)
        #expect(window.validateUserInterfaceItem(item))
        #expect(item.title == UndoManager().undoMenuTitle(forUndoActionName: "Branch"))

        // 不能撤销的操作：菜单项不可用，标题写明原因
        fixture.session.undoHistory?.recordIrreversible("Push")
        #expect(!window.validateUserInterfaceItem(item))
        #expect(item.title == AppLocalization.text("undo.cannotUndo", "Push"))

        // 文字的撤销与仓库的撤销分开
        let field = NSTextField()
        window.contentView?.addSubview(field)
        window.makeFirstResponder(field)
        #expect(window.undoManager === controller.textUndoManager)
    }
}

// MARK: - Helpers

extension UndoSessionTests {
    /// 等会话不再忙于写入或刷新，再读菜单状态；本机仓库的文件监听随时可能触发一次刷新。
    static func settledState(of session: RepositorySession, redo: Bool) async throws -> UndoMenuState {
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while .now < deadline {
            let state = session.undoMenuState(redo: redo)
            guard case .blocked(_, reason: "undo.reason.busy") = state else { return state }

            try await Task.sleep(for: .milliseconds(20))
        }

        return session.undoMenuState(redo: redo)
    }

    /// 会话的引用快照里是否已有这个本地分支。
    static func hasBranch(_ name: String, in session: RepositorySession) -> Bool {
        session.history.snapshot?.references.contains { $0.id == "refs/heads/" + name } ?? false
    }
}

// MARK: UndoSessionTests.Fixture

extension UndoSessionTests {
    /// 一个提交过一次的临时仓库，以及显示它的会话。
    @MainActor
    struct Fixture {
        /// 仓库目录，路径带空格与中文。
        let directory: URL

        /// 仓库位置。
        let location: RepositoryLocation

        /// 忽略用户配置的执行器。
        let runner: GitRunner

        /// 显示仓库的会话。
        let session: RepositorySession

        /// 建好仓库并读取一次完整状态。
        init() async throws {
            directory = FileManager.default.temporaryDirectory.appending(path: "spooky-undo 撤销-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            location = RepositoryLocation.local(path: directory.path)
            runner = try await FileViewsTests.initializeRepository(at: location)

            try Data("base\n".utf8).write(to: directory.appending(path: "a b.txt"))
            _ = try await runner.run(["add", "--all"])
            _ = try await runner.run(["commit", "-q", "-m", "root"])

            let runner = runner
            session = RepositorySession(makeRunner: { _ in runner })
            session.display(location)
            session.refresh(full: true)
            await session.waitForRefresh()
        }

        /// 发起写操作，等它与随后的完整刷新、引用读取都结束。
        func perform(_ start: () -> Void) async throws {
            start()
            await session.writeTask?.value
            await session.waitForRefresh()
            await waitForReads()
        }

        /// 经会话的写队列新建分支，声明为可撤销，操作名为 “Branch”。
        func createBranch(_ name: String) async throws {
            try await perform {
                session.performGit(
                    { runner, _ in _ = try await runner.run(["branch", name]) },
                    title: "Branch",
                    undo: .reversible
                )
            }
        }

        /// 读取一次完整状态，等引用与储藏也读完。
        func refresh() async {
            session.refresh(full: true)
            await session.waitForRefresh()
            await waitForReads()
        }

        /// 改写仓库里唯一的文件。
        func write(_ content: String) throws {
            try Data(content.utf8).write(to: directory.appending(path: "a b.txt"))
        }

        /// 读出仓库里唯一的文件。
        func read() throws -> String {
            try String(contentsOf: directory.appending(path: "a b.txt"), encoding: .utf8)
        }

        /// HEAD 所在的提交。
        func head() async throws -> String {
            try await RepositoryReferences(runner: runner).resolve("HEAD")
        }

        /// 关闭会话并删除临时仓库。
        func remove() {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        /// 等引用与储藏的读取结束；读取期间又要求的刷新在读完后另起任务，也一起等完。
        private func waitForReads() async {
            var awaited = Set<Task<Void, Never>>()

            while
                let task = (session.history.activeTasks + session.stashes.activeTasks)
                    .first(where: { !awaited.contains($0) })
            {
                await task.value
                awaited.insert(task)
            }
        }
    }
}
