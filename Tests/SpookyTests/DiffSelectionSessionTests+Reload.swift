import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

extension DiffSelectionSessionTests {
    /// 第一份真实补丁在输出前等待，取消 / 切文件 / 换仓库后不允许它回写选择。
    @Test("过期 Diff 读取不能修改新范围", arguments: ["reload", "file", "repository", "close"])
    func delayedRead(change: String) async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        try await prepare(fixture)
        let other = try await UndoSessionTests.Fixture()
        defer { other.remove() }
        let row = try #require(fixture.session.selectedID)
        await fixture.session.shutdown()
        let root = fixture.directory.appending(path: ".git")
        let runner = try gatedRunner(fixture, root: root)
        let otherRunner = other.runner
        let location = fixture.location
        let activities = RepositoryActivities()
        let session = RepositorySession(makeRunner: { $0 == location ? runner : otherRunner }, activities: activities)
        defer { session.close() }
        defer { try? Data().write(to: root.appending(path: "release")) }
        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()
        session.selectedID = row
        try await FileViewsTests.wait { !session.isLoadingDiff && session.diffSnapshot?.diff != nil }
        let old = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        old.activate(at: try #require(old.rows.firstIndex { $0 != nil }))
        let selected = old.selected
        try Data().write(to: root.appending(path: "arm"))
        session.loadDiff()
        try await FileViewsTests.wait { FileManager.default.fileExists(atPath: root.appending(path: "started").path) }

        switch change {
        case "reload": session.loadDiff()

        case "file":
            session.selectedID = nil
            session.selectedID = row

        case "repository": session.display(other.location)

        default: session.close()
        }
        try Data().write(to: root.appending(path: "release"))
        try await FileViewsTests.wait { !session.isLoadingDiff }
        try await FileViewsTests.wait { !activities.items.contains { $0.state == "activity.running" } }
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

    /// 只阻塞本测试新建仓库的一次 Diff，实际输出仍由系统 Git 产生。
    func gatedRunner(_ fixture: UndoSessionTests.Fixture, root: URL) throws -> GitRunner {
        let script = root.appending(path: "selection-git")
        let source = """
            #!/bin/sh
            set -eu
            root=\(GitRunner.shellQuoted(root.path))
            kind=other
            for arg in "$@"; do
                if [ "$arg" = diff ]; then kind=diff; break; fi
            done
            if [ "$kind" = diff ] && [ -f "$root/arm" ] && mv "$root/arm" "$root/claimed" 2>/dev/null; then
                /usr/bin/git "$@" > "$root/held-patch"
                touch "$root/started"
                count=0
                while [ ! -f "$root/release" ]; do
                    count=$((count + 1))
                    if [ "$count" -gt 30000 ]; then exit 91; fi
                    sleep 0.01
                done
                cat "$root/held-patch"
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
