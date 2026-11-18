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
