import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Busy

extension WorkingCopyFileListTests {
    /// 暂存停在中途时只有受影响的行显示目标状态并禁用，其它行的勾选框仍可点、图标与文件名不变灰；
    /// 这时点下的请求排在后面，放行后在同一个写操作里依次执行。暂存失败时排在后面的请求一并丢弃，
    /// 行按真实索引恢复；其它窗口改动索引的写操作执行期间所有行变灰、勾选框禁用，获取这类写操作执行期间不变灰。
    @Test("文件级写操作的局部忙态")
    func localBusyState() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        await fixture.session.shutdown()

        // 三个改过的已跟踪文件
        for name in ["b.txt", "c.txt"] {
            try Data("base\n".utf8).write(to: fixture.directory.appending(path: name))
        }

        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-q", "-m", "files"])

        for name in ["a b.txt", "b.txt", "c.txt"] {
            try Data("changed\n".utf8).write(to: fixture.directory.appending(path: name))
        }

        let root = fixture.directory.appending(path: ".git")
        let gate = try ProcessGate(in: root)
        defer { gate.release() }

        let runner = try fixture.gatedRunner(intercepting: "add", gate: gate)
        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        defer { session.close() }

        var failures = 0
        session.onFailure = { _ in failures += 1 }

        session.display(fixture.location)
        session.refresh(full: true)
        await session.waitForRefresh()

        let list = FileListHarness(session: session, source: StatusSource())
        let entries = try #require(session.status?.entries)
        let entry = { (path: String) in try #require(entries.first { $0.path == path }) }

        // 暂存 a 停在中途：只有 a 显示勾选并禁用，b、c 照常可点，文件名不变灰
        try gate.arm()
        session.stage([try entry("a b.txt")], staged: true)
        await gate.arrival()

        render(list)
        #expect(checkboxes(list).map(\.isEnabled) == [false, true, true])
        #expect(checkboxes(list).first?.state == .on)
        #expect(labelColors(list).allSatisfy { $0 == .controlTextColor })

        // 这时勾选 b：排在后面，b 同样显示勾选并禁用
        session.stage([try entry("b.txt")], staged: true)
        render(list)

        #expect(session.queuedStaging.count == 1)
        #expect(checkboxes(list).map(\.isEnabled) == [false, false, true])

        // 放行后 a、b 依次暂存，c 不动
        gate.release()
        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(stagedPaths(session) == ["a b.txt", "b.txt"])
        #expect(!session.isStaging && session.stagingOverrides.isEmpty)

        // 暂存 c 时索引被锁住而失败：排在后面的取消暂存 a 一并丢弃，行按真实索引恢复
        try gate.arm()
        session.stage([try entry("c.txt")], staged: true)
        await gate.arrival()

        session.stage([try entry("a b.txt")], staged: false)
        try Data().write(to: root.appending(path: "index.lock"))
        gate.release()

        await session.writeTask?.value
        await session.waitForRefresh()
        try FileManager.default.removeItem(at: root.appending(path: "index.lock"))

        render(list)
        #expect(failures == 1)
        #expect(stagedPaths(session) == ["a b.txt", "b.txt"])
        #expect(!session.isStaging && session.queuedStaging.isEmpty && session.stagingOverrides.isEmpty)
        #expect(checkboxes(list).map(\.state) == [.on, .on, .off])

        // 其它窗口改动索引的写操作执行期间：所有行变灰，勾选框禁用
        let staging = RepositoryWrite(location: fixture.location, session: nil, title: "Stage")
        #expect(RepositoryWriteQueue.shared.begin(staging))
        render(list)

        #expect(labelColors(list).allSatisfy { $0 == .secondaryLabelColor })
        #expect(checkboxes(list).allSatisfy { !$0.isEnabled })

        RepositoryWriteQueue.shared.finish(staging)

        // 不改动工作区的写操作（获取）执行期间：不变灰，勾选框照样可点
        let fetching = RepositoryWrite(
            location: fixture.location,
            session: nil,
            title: "Fetch",
            touchesWorkingCopy: false
        )

        #expect(RepositoryWriteQueue.shared.begin(fetching))
        render(list)

        #expect(labelColors(list).allSatisfy { $0 == .controlTextColor })
        #expect(checkboxes(list).allSatisfy { $0.isEnabled })

        RepositoryWriteQueue.shared.finish(fetching)
        await session.shutdown()
    }

    /// 不改动工作区的写操作（获取）占着仓库时，暂存与提交排进队列：暂存的行先显示目标状态，期间再点的并进它，
    /// 刷新不撤回；在队列里取消后目标状态撤回、并进的请求一并丢弃，再暂存时轮到后照常执行。
    /// 提交排队时提交区锁住、不再接受提交；取消后恢复，标题与正文不变。
    @Test("排队的暂存与提交")
    func queuedStagingAndCommit() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        // 两个改过的已跟踪文件
        try Data("base\n".utf8).write(to: fixture.directory.appending(path: "b.txt"))
        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-q", "-m", "files"])

        for name in ["a b.txt", "b.txt"] {
            try Data("changed\n".utf8).write(to: fixture.directory.appending(path: name))
        }

        fixture.session.refresh(full: true)
        await fixture.session.waitForRefresh()

        let list = FileListHarness(session: fixture.session, source: StatusSource())

        try await checkQueuedStaging(in: list, location: fixture.location)
        try checkQueuedCommit(in: fixture.session, location: fixture.location)

        await fixture.session.shutdown()
    }
}

// MARK: - Queued

extension WorkingCopyFileListTests {
    /// 获取占着仓库时暂存 a 再勾选 b：两行先显示勾选，取消后撤回；再暂存 a，获取结束后轮到并执行。
    ///
    /// - Parameters:
    ///   - list: 接着会话的文件列表，行依次是 a、b，都只有未暂存的改动。
    ///   - location: 仓库。
    private func checkQueuedStaging(in list: FileListHarness, location: RepositoryLocation) async throws {
        let session = list.session
        let entries = try #require(session.status?.entries)
        let entry = { (path: String) in try #require(entries.first { $0.path == path }) }

        let fetching = RepositoryWrite(
            location: location,
            session: nil,
            title: "Fetch",
            touchesWorkingCopy: false
        )

        #expect(RepositoryWriteQueue.shared.begin(fetching))

        // 暂存 a 排进队列：a 显示勾选并禁用，b 照常可点，文件名不变灰
        session.stage([try entry("a b.txt")], staged: true)
        render(list)

        #expect(session.staging == .waiting)
        #expect(checkboxes(list).map(\.isEnabled) == [false, true])
        #expect(checkboxes(list).first?.state == .on)
        #expect(labelColors(list).allSatisfy { $0 == .controlTextColor })

        // 这时勾选 b：并进排着的暂存，刷新后两行仍显示勾选
        session.stage([try entry("b.txt")], staged: true)
        session.refresh(full: true)
        await session.waitForRefresh()
        render(list)

        #expect(session.queuedStaging.count == 1)
        #expect(checkboxes(list).map(\.state) == [.on, .on])

        // 在活动区取消：目标状态撤回，并进的请求一并丢弃
        let record = try #require(session.activities.items.first { $0.state == "activity.waiting" })
        record.cancel?()
        render(list)

        #expect(record.state == "activity.cancelled")
        #expect(session.staging == .idle && session.queuedStaging.isEmpty && session.stagingOverrides.isEmpty)
        #expect(checkboxes(list).map(\.state) == [.off, .off])

        // 再暂存 a：获取结束后轮到，照常执行
        session.stage([try entry("a b.txt")], staged: true)
        RepositoryWriteQueue.shared.finish(fetching)

        await until { session.staging == .idle }
        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(stagedPaths(session) == ["a b.txt"])
        #expect(session.stagingOverrides.isEmpty)
    }

    /// 获取占着仓库时提交：提交区锁住、不再接受提交；在队列里取消后恢复，标题与正文不变。
    ///
    /// - Parameters:
    ///   - session: 已有暂存改动的会话。
    ///   - location: 仓库。
    private func checkQueuedCommit(in session: RepositorySession, location: RepositoryLocation) throws {
        let fetching = RepositoryWrite(
            location: location,
            session: nil,
            title: "Fetch",
            touchesWorkingCopy: false
        )

        #expect(RepositoryWriteQueue.shared.begin(fetching))
        defer { RepositoryWriteQueue.shared.finish(fetching) }

        session.commitSubject = "Subject"
        session.commitBody = "Body"
        session.commit()

        // 提交排进队列：进入提交中状态
        #expect(session.isCommitting)
        #expect(!session.canCommit)

        // 在活动区取消：恢复可提交，草稿不变
        let record = try #require(session.activities.items.first { $0.state == "activity.waiting" })
        record.cancel?()

        #expect(!session.isCommitting)
        #expect(session.canCommit)
        #expect(session.commitSubject == "Subject" && session.commitBody == "Body")
    }
}

// MARK: - Helpers

extension WorkingCopyFileListTests {
    /// 按会话现在的状态重新渲染列表。
    private func render(_ list: FileListHarness) {
        list.coordinator.update(listing: list.listing, style: .init(fontSize: .medium, truncation: .beginning))
    }

    /// 各行的勾选框，自上而下。
    private func checkboxes(_ list: FileListHarness) -> [NSButton] {
        (0 ..< list.outline.numberOfRows).compactMap { row in
            list.node(at: row).flatMap { node in
                list.coordinator.statusCell(node).subviews
                    .compactMap { $0 as? WorkingCopyFileList.StagingButton }
                    .first
            }
        }
    }

    /// 各行文件名的颜色，自上而下。
    private func labelColors(_ list: FileListHarness) -> [NSColor?] {
        (0 ..< list.outline.numberOfRows).compactMap { row in
            list.node(at: row).map { node in
                list.coordinator.pathCell(node).subviews
                    .compactMap { $0 as? NSTextField }
                    .first?
                    .textColor
            }
        }
    }

    /// 会话状态里有已暂存改动的路径。
    private func stagedPaths(_ session: RepositorySession) -> [String] {
        (session.status?.entries ?? []).filter(\.hasStagedChanges).map(\.path).sorted()
    }
}
