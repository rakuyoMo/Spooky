import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Loading Boundaries

extension ChangesetAutoExpandTests {
    /// 已取得 Git 输出但尚未回传时切对象或关闭，旧清单不能按阈值展开新对象。
    @Test("自动展开拒绝切换或关闭后的迟到清单")
    func lateChanges() async throws {
        let fixture = try await ChangesetFixture.make()
        let tools = try FileViewsTests.temporaryDirectory()

        defer {
            fixture.close()
            try? FileManager.default.removeItem(at: tools)
        }

        // 提交、比较与储藏依次在切到新对象或关闭详情后放行旧清单
        for closes in [false, true] {
            for kind in 0 ... 2 {
                let directory = tools.appending(path: "\(closes)-\(kind)")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try await releaseLate(kind: kind, closes: closes, fixture: fixture, tools: directory)

                try expectLateResult(kind: kind, closes: closes, fixture: fixture)
            }
        }
    }

    /// 让一种对象的变更清单停在闸门上，调低阈值并切换或关闭后再放行，等新旧读取都结束。
    private func releaseLate(kind: Int, closes: Bool, fixture: ChangesetFixture, tools: URL) async throws {
        let gate = try ProcessGate(in: tools)
        defer { gate.release() }

        let gated = try gatedRunner(location: fixture.runner.location, tools: tools, gate: gate)
        let session = fixture.session
        fixture.setThreshold(Int.max)

        // 储藏先读完列表，闸门只拦下选中储藏后的变更清单
        if kind == 2 {
            session.stashes.refresh(runner: gated, records: false)
            await until { !session.stashes.isLoading }
        }

        try Data().write(to: tools.appending(path: "arm"))

        switch kind {
        case 0: session.history.show(fixture.commits[2], runner: gated)
        case 1: fixture.open(session.comparison, runner: gated)
        default: session.stashes.selectedIDs = [try #require(session.stashes.entries.first).id]
        }

        await gate.arrival()
        let oldTasks = session.history.activeTasks + session.stashes.activeTasks
        fixture.setThreshold(0)

        if closes {
            session.history.close()
            session.comparison.close()
            session.stashes.close()
        } else {
            try await switchObject(kind: kind, fixture: fixture)
        }

        gate.release()

        for task in oldTasks {
            await task.value
        }

        try await fixture.waitForChanges()
    }

    /// 三处详情都没有被旧清单展开或读取补丁；切换时新对象按阈值 0 读完清单。
    private func expectLateResult(kind: Int, closes: Bool, fixture: ChangesetFixture) throws {
        let session = fixture.session
        #expect(fixture.expansions[0 ... 2].allSatisfy { $0.isEmpty })
        #expect(fixture.cachedPaths[0 ... 2].allSatisfy { $0.isEmpty })

        if closes {
            #expect(session.history.changes.isEmpty)
            #expect(session.comparison.changes.isEmpty)
            #expect(session.stashes.changes.isEmpty)
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

    /// 新对象用正常执行器读取，旧请求仍停在闸门上。
    private func switchObject(kind: Int, fixture: ChangesetFixture) async throws {
        let session = fixture.session

        if kind == 0 {
            session.history.show(fixture.commits[1], runner: fixture.runner)
        } else if kind == 1 {
            fixture.open(session.comparison, target: 1)
        } else {
            session.stashes.refresh(runner: fixture.runner, records: false)
            await until { !session.stashes.isLoading }
            session.stashes.selectedIDs = [try #require(session.stashes.entries.last).id]
        }
    }

    /// 只拦下武装后的一次变更清单：武装期间的变更清单都先读出真实输出，读完后认领到武装的一个停在闸门上，
    /// 放行后再输出；其余命令直接交给系统 Git。
    ///
    /// 读到一半被取消的进程不占用武装；认领前开始忽略取消发出的 TERM，认领了的进程一定走到闸门报到。
    private func gatedRunner(location: RepositoryLocation, tools: URL, gate: ProcessGate) throws -> GitRunner {
        let script = tools.appending(path: "git")
        let source = """
            #!/bin/sh
            tools=\(GitRunner.shellQuoted(tools.path))
            case " $* " in
                *' --numstat '*)
                    if [ -f "$tools/arm" ]; then
                        held="$tools/held-$$"
                        /usr/bin/git "$@" > "$held"
                        code=$?

                        trap '' TERM
                        if mv "$tools/arm" "$tools/claimed" 2>/dev/null; then
                            \(gate.command)
                        fi
                        trap - TERM

                        cat "$held"
                        exit $code
                    fi
                    ;;
            esac
            exec /usr/bin/git "$@"

            """

        try Data(source.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)

        return GitRunner(
            location: location,
            executablePath: script.path,
            environment: .inherit.updating(["GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"])
        )
    }
}
