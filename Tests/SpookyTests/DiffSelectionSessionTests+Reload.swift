import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

extension DiffSelectionSessionTests {
    /// 第一份真实补丁在输出前停住，重读、切文件或换仓库后不允许它回写选择。
    @Test("过期 Diff 读取不能修改新范围", arguments: ["reload", "file", "repository"])
    func delayedRead(change: String) async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        try await prepare(fixture)

        let other = try await UndoSessionTests.Fixture()
        defer { other.remove() }

        let row = try #require(fixture.session.selectedID)
        await fixture.session.shutdown()

        // 换成只拦下一次 Diff 的执行器，重新打开同一个仓库
        let root = fixture.directory.appending(path: ".git")
        let gate = try ProcessGate(in: root)
        defer { gate.release() }

        let runner = try gatedRunner(fixture, gate: gate, root: root)
        let otherRunner = other.runner
        let location = fixture.location
        let activities = RepositoryActivities()
        let session = RepositorySession(makeRunner: { $0 == location ? runner : otherRunner }, activities: activities)
        defer { session.close() }

        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()

        session.selectedID = row
        await until { !session.isLoadingDiff && session.diffSnapshot?.diff != nil }

        let old = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        try activateFirstRow(old)
        let selected = old.selected

        // 下一次 Diff 停在闸门上，这时改变范围
        try Data().write(to: root.appending(path: "arm"))
        session.loadDiff()
        await gate.arrival()

        switch change {
        case "reload": session.loadDiff()

        case "file":
            session.selectedID = nil
            session.selectedID = row

        default: session.display(other.location)
        }

        gate.release()
        await until { !session.isLoadingDiff && !activities.items.contains { $0.state == "activity.running" } }

        if change == "reload" {
            #expect(session.diffSelections.selection(file: 0, hunk: 0) === old)
            #expect(old.selected == selected)
        } else {
            #expect(!old.isActive && old.selected.isEmpty)

            if change == "file" {
                #expect(session.diffSelections.scope?.row == row)
                #expect(session.diffSelections.selection(file: 0, hunk: 0)?.selected.isEmpty ?? false)
            } else {
                #expect(session.diffSelections.scope == nil)
                #expect(session.diffSnapshot == nil)
            }
        }

        await session.shutdown()
    }

    /// 只拦下本测试仓库里武装后的一次 Diff：武装期间的 Diff 都先读出真实补丁，读完后认领到武装的一个停在闸门上，
    /// 放行后再输出；其余命令直接交给系统 Git。
    ///
    /// 会话取消读取时先向进程组发 TERM，宽限期过后才 KILL。读补丁时被取消的进程还没认领，武装留给会话重发的读取；
    /// 认领前开始忽略 TERM，认领了的进程一定走到闸门报到。
    func gatedRunner(_ fixture: UndoSessionTests.Fixture, gate: ProcessGate, root: URL) throws -> GitRunner {
        let script = root.appending(path: "selection-git")
        let source = """
            #!/bin/sh
            set -eu
            root=\(GitRunner.shellQuoted(root.path))
            kind=other
            for arg in "$@"; do
                if [ "$arg" = diff ]; then kind=diff; break; fi
            done
            if [ "$kind" = diff ] && [ -f "$root/arm" ]; then
                held="$root/held-$$"
                /usr/bin/git "$@" > "$held"

                trap '' TERM
                if mv "$root/arm" "$root/claimed" 2>/dev/null; then
                    \(gate.command)
                fi
                trap - TERM

                cat "$held"
            else
                exec /usr/bin/git "$@"
            fi

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
