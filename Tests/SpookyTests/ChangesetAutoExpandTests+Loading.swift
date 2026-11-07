import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Loading Boundaries

extension ChangesetAutoExpandTests {
    /// 已取得 Git 输出但尚未回传时切对象或关闭，旧清单不能按阈值展开新对象。
    @Test("自动展开拒绝切换或关闭后的迟到清单", arguments: 0 ... 2, [false, true])
    func lateChanges(kind: Int, closes: Bool) async throws {
        let fixture = try await ChangesetFixture.make()
        let tools = try FileViewsTests.temporaryDirectory()
        defer {
            try? Data().write(to: tools.appending(path: "release"))
            fixture.close()
            try? FileManager.default.removeItem(at: tools)
        }

        let gated = try gatedRunner(location: fixture.runner.location, tools: tools)
        fixture.setThreshold(Int.max)
        let session = fixture.session

        if kind == 0 {
            session.history.show(fixture.commits[2], runner: gated)
        } else if kind == 1 {
            fixture.open(session.comparison, runner: gated)
        } else {
            session.stashes.refresh(runner: gated, records: false)
            try await FileViewsTests.wait { session.stashes.isLoaded }
            session.stashes.selectedIDs = [try #require(session.stashes.entries.first).id]
        }

        try await FileViewsTests.wait { FileManager.default.fileExists(atPath: tools.appending(path: "read").path) }
        let oldTasks = session.history.activeTasks + session.stashes.activeTasks
        fixture.setThreshold(0)

        if closes {
            session.history.close()
            session.comparison.close()
            session.stashes.close()
        } else {
            try await switchObject(kind: kind, fixture: fixture)
        }

        try Data().write(to: tools.appending(path: "release"))
        for task in oldTasks { await task.value }
        try await fixture.waitForChanges()
        #expect(session.history.expandedPaths.isEmpty)
        #expect(session.comparison.expandedPaths.isEmpty)
        #expect(session.stashes.expandedPaths.isEmpty)
        #expect(session.history.diffs.isEmpty && session.comparison.diffs.isEmpty && session.stashes.diffs.isEmpty)

        if closes {
            #expect(session.history.changes.isEmpty && session.comparison.changes.isEmpty && session.stashes.changes.isEmpty)
        } else if kind == 0 {
            #expect(session.history.selectedCommit?.id == fixture.commits[1].id)
            #expect(session.history.changes.count == 2)
        } else if kind == 1 {
            #expect(session.comparison.target?.id == fixture.commits[1].id)
            #expect(session.comparison.changes.count == 2)
        } else {
            #expect(session.stashes.selectedStash?.id == session.stashes.entries.last?.id)
            #expect(session.stashes.changes.count == 2)
        }
    }

    /// 新对象用正常执行器读取，旧请求仍被独立闸门挡住。
    private func switchObject(kind: Int, fixture: ChangesetFixture) async throws {
        let session = fixture.session

        if kind == 0 {
            session.history.show(fixture.commits[1], runner: fixture.runner)
        } else if kind == 1 {
            fixture.open(session.comparison, target: 1)
        } else {
            session.stashes.refresh(runner: fixture.runner, records: false)
            try await FileViewsTests.wait { !session.stashes.isLoading }
            session.stashes.selectedIDs = [try #require(session.stashes.entries.last).id]
        }
    }

    /// 只阻塞变更清单：先保存真实 Git 输出，再等待测试放行；补丁与其它命令照常执行。
    private func gatedRunner(location: RepositoryLocation, tools: URL) throws -> GitRunner {
        let script = tools.appending(path: "git")
        try Data("""
            #!/bin/sh
            tools='\(tools.path)'
            case " $* " in
                *' --numstat '*)
                    output=$(mktemp "$tools/output.XXXXXXXX")
                    /usr/bin/git "$@" > "$output"
                    code=$?
                    : > "$tools/read"
                    while [ ! -e "$tools/release" ]; do sleep 0.02; done
                    cat "$output"
                    rm -f "$output"
                    exit $code
                    ;;
            esac
            exec /usr/bin/git "$@"
            """.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        return GitRunner(
            location: location,
            executablePath: script.path,
            environment: .inherit.updating(["GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"])
        )
    }
}
