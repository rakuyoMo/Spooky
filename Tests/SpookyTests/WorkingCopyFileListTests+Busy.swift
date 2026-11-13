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
    /// 行按真实索引恢复；其它窗口占用仓库时所有行变灰、勾选框禁用。
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

        let runner = try stagingGatedRunner(fixture, gate: gate, root: root)
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
        try Data().write(to: root.appending(path: "arm"))
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
        try Data().write(to: root.appending(path: "arm"))
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

        // 其它窗口占用仓库：所有行变灰，勾选框禁用
        #expect(RepositoryWriteLocks.shared.acquire(fixture.location))
        render(list)

        #expect(labelColors(list).allSatisfy { $0 == .secondaryLabelColor })
        #expect(checkboxes(list).allSatisfy { !$0.isEnabled })

        RepositoryWriteLocks.shared.release(fixture.location)
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

    /// 只拦下武装后的一次 `git add`：认领武装的进程停在闸门上，放行后再执行；其余命令直接交给系统 Git。
    private func stagingGatedRunner(
        _ fixture: UndoSessionTests.Fixture,
        gate: ProcessGate,
        root: URL
    ) throws -> GitRunner {
        let script = root.appending(path: "staging-git")
        let source = """
            #!/bin/sh
            set -eu
            root=\(GitRunner.shellQuoted(root.path))
            for arg in "$@"; do
                if [ "$arg" = add ] && mv "$root/arm" "$root/claimed" 2>/dev/null; then
                    \(gate.command)
                    break
                fi
            done
            exec /usr/bin/git "$@"

            """

        try Data(source.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)

        return GitRunner(
            location: fixture.location,
            executablePath: script.path,
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_PARAMETERS": nil,
                "GIT_CONFIG_COUNT": nil,
            ])
        )
    }
}
