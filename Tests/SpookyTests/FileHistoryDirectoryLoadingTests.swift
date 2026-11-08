import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 用实际 Git 闸门验证目录读取的失败隔离与过期请求取消。
@MainActor
struct FileHistoryDirectoryLoadingTests {
    /// 失败文件可独立重试；连续重读和 A → B → A 不让旧任务清除当前请求。
    @Test("目录逐文件重试与过期请求隔离")
    func requestIdentity() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        let tools = try FileViewsTests.temporaryDirectory()

        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: tools)
        }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        try Data("first\n".utf8).write(to: directory.appending(path: "a.txt"))
        try Data("other\n".utf8).write(to: directory.appending(path: "b.txt"))
        let first = try await commit(runner)
        try Data("second\n".utf8).write(to: directory.appending(path: "a.txt"))
        let second = try await commit(runner)
        let firstFiles = try await RepositoryHistory(runner: runner).changes(in: first.id)
        let secondFiles = try await RepositoryHistory(runner: runner).changes(in: second.id)

        let stale = try ProcessGate(in: tools, name: "stale")
        let current = try ProcessGate(in: tools, name: "current")

        defer {
            stale.release()
            current.release()
        }

        let gated = try gatedRunner(location: runner.location, tools: tools, gates: [("*", stale)])
        let latest = try gatedRunner(location: runner.location, tools: tools, gates: [("*", current)])
        let activities = RepositoryActivities()
        let state = FileHistoryDirectoryState()
        defer { state.close() }

        // 一个文件读取失败时另一个照常显示，失败记进 Activity
        try Data().write(to: tools.appending(path: "fail"))
        state.open(commit: first, files: firstFiles, runner: gated, activities: activities, records: true)

        for file in firstFiles {
            state.setVisible(file.path, visible: true, identity: state.identity)
        }

        await until { state.loadingPaths.isEmpty }
        #expect(state.failures["a.txt"] != nil && state.failures["b.txt"] == nil)
        #expect(state.diffs["b.txt"] != nil)
        #expect(activities.items.contains { $0.state == "activity.failed" })

        // 重试停在闸门上时连续重读，再经 A → B → A 回到第一个提交，只有最后的请求放行
        try FileManager.default.removeItem(at: tools.appending(path: "fail"))
        state.load("a.txt", retry: true)
        await stale.arrival()
        state.reloadDiffs()
        state.reloadDiffs()
        let oldIdentity = state.identity

        state.open(commit: second, files: secondFiles, runner: gated, activities: activities, records: true)
        state.setVisible("a.txt", visible: true, identity: state.identity)
        state.open(commit: first, files: firstFiles, runner: latest, activities: activities, records: true)
        state.setVisible("a.txt", visible: true, identity: state.identity)
        state.setVisible("a.txt", visible: false, identity: oldIdentity)
        await current.arrival()
        let request = state.requests["a.txt"]
        current.release()

        // 每次读取结束时记一条 Activity：两次首读、一次重试、两轮重读各两项与两次切换，共九条
        await until { activities.items.count == 9 && state.loadingPaths.isEmpty }
        #expect(state.requests["a.txt"] == request)
        #expect(state.commit?.id == first.id)
        #expect(state.failures.isEmpty)

        let file = try #require(state.diffs["a.txt"]?.diff?.files.first)
        #expect(file.hunks.flatMap(\.lines).contains { String(decoding: $0.content, as: UTF8.self) == "first" })

        // 关闭后清空全部内容
        state.close()
        #expect(state.files.isEmpty && state.diffs.isEmpty && state.loadingPaths.isEmpty)
    }

    /// 连续更新选项时必须实际启动不同参数的查询，取消的读取记为 Cancelled。
    @Test("目录读取中连续更新上下文和空白选项")
    func preferenceChanges() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        let tools = try FileViewsTests.temporaryDirectory()
        let suite = "Spooky.DirectoryOptions." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))

        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: tools)
        }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        let original = (1 ... 30).map { "line \($0)" }.joined(separator: "\n") + "\n"
        try Data(original.utf8).write(to: directory.appending(path: "a.txt"))
        _ = try await commit(runner)

        let changed = original
            .replacingOccurrences(of: "line 15", with: "changed 15")
            .replacingOccurrences(of: "line 25", with: "line   25")

        try Data(changed.utf8).write(to: directory.appending(path: "a.txt"))
        let head = try await commit(runner)
        let files = try await RepositoryHistory(runner: runner).changes(in: head.id)

        let contexts = [1, 5, 10]
        let gates = try contexts.map { try ProcessGate(in: tools, name: "unified-\($0)") }

        defer {
            for gate in gates {
                gate.release()
            }
        }

        let gated = try gatedRunner(
            location: runner.location,
            tools: tools,
            gates: zip(contexts.map(String.init), gates).map { ($0, $1) }
        )

        let activities = RepositoryActivities()
        let state = FileHistoryDirectoryState(defaults: defaults)
        defer { state.close() }

        // 每次改选项后都等到带新上下文行数的查询真正启动
        defaults.set(1, forKey: DiffPreferences.contextLinesKey)
        state.open(commit: head, files: files, runner: gated, activities: activities, records: true)
        state.setVisible("a.txt", visible: true, identity: state.identity)
        await gates[0].arrival()

        defaults.set(5, forKey: DiffPreferences.contextLinesKey)
        state.reloadDiffs()
        await gates[1].arrival()

        defaults.set(10, forKey: DiffPreferences.contextLinesKey)
        defaults.set(true, forKey: DiffPreferences.ignoresWhitespaceKey)
        state.reloadDiffs()
        await gates[2].arrival()

        // 只放行最后一次查询；三次读取各记一条 Activity
        let request = state.requests["a.txt"]
        gates[2].release()
        await until { activities.items.count == 3 && state.loadingPaths.isEmpty }

        let expected = try await RepositoryHistory(runner: runner).diff(
            in: head.id,
            file: #require(files.first),
            options: DiffOptions(contextLines: 10, ignoresWhitespace: true)
        )

        #expect(state.diffs["a.txt"]?.diff == expected.diff)
        #expect(state.requests["a.txt"] == request)
        #expect(state.failures.isEmpty)
        #expect(activities.items.filter { $0.state == "activity.cancelled" }.count == 2)
        #expect(activities.items.filter { $0.state == "activity.finished" }.count == 1)
    }

    /// 换仓库后的同路径请求与关闭后的空状态都不接受迟到结果。
    @Test("目录加载中切换同路径目标或关闭")
    func targetBoundary() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        let replacement = try FileViewsTests.temporaryDirectory()
        let tools = try FileViewsTests.temporaryDirectory()

        defer {
            for url in [directory, replacement, tools] {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        try Data("old target\n".utf8).write(to: directory.appending(path: "a.txt"))
        let old = try await commit(runner)
        let oldFiles = try await RepositoryHistory(runner: runner).changes(in: old.id)

        let newRunner = try await FileViewsTests.initializeRepository(at: .local(path: replacement.path))
        try Data("new target\n".utf8).write(to: replacement.appending(path: "a.txt"))
        let new = try await commit(newRunner)
        let newFiles = try await RepositoryHistory(runner: newRunner).changes(in: new.id)

        // 先换到另一个仓库的同路径文件，再只关闭不换目标
        for close in [false, true] {
            let gate = try ProcessGate(in: tools, name: "close-\(close)")
            defer { gate.release() }

            let gated = try gatedRunner(location: runner.location, tools: tools, gates: [("*", gate)])
            let activities = RepositoryActivities()
            let state = FileHistoryDirectoryState()
            defer { state.close() }

            state.open(commit: old, files: oldFiles, runner: gated, activities: activities, records: true)
            state.setVisible("a.txt", visible: true, identity: state.identity)
            await gate.arrival()
            let identity = state.identity
            state.close()

            if !close {
                state.open(commit: new, files: newFiles, runner: newRunner, activities: activities, records: true)
                state.setVisible("a.txt", visible: true, identity: state.identity)
                state.setVisible("a.txt", visible: false, identity: identity)
            }

            // 旧读取记为 Cancelled 后再核对，迟到结果没有写进新状态
            gate.release()
            await until { activities.items.count == (close ? 1 : 2) && state.loadingPaths.isEmpty }
            #expect(activities.items.contains { $0.state == "activity.cancelled" })
            #expect(state.failures.isEmpty)

            if close {
                #expect(state.commit == nil && state.files.isEmpty && state.diffs.isEmpty && state.requests.isEmpty)
            } else {
                try await expectReplacement(state, commit: new)
            }
        }
    }

    /// 新目标显示自己的内容，重读也使用新目标的执行器。
    private func expectReplacement(_ state: FileHistoryDirectoryState, commit: HistoryCommit) async throws {
        #expect(state.commit?.id == commit.id)

        let lines = try #require(state.diffs["a.txt"]?.diff).files
            .flatMap(\.hunks)
            .flatMap(\.lines)

        #expect(lines.map { String(decoding: $0.content, as: UTF8.self) } == ["new target"])

        state.reloadDiffs()
        await until { state.loadingPaths.isEmpty }
        #expect(state.diffs["a.txt"] != nil)
    }

    /// 只拦下 `a.txt` 的补丁：`fail` 存在时直接失败；否则读出真实补丁，按上下文行数停在对应闸门上，放行后再输出。
    ///
    /// - Parameter gates: shell `case` 模式与闸门，模式匹配 `--unified=` 的值，`*` 匹配全部。
    private func gatedRunner(
        location: RepositoryLocation,
        tools: URL,
        gates: [(String, ProcessGate)]
    ) throws -> GitRunner {
        let script = tools.appending(path: "git-" + UUID().uuidString)
        let branches = gates.map { "            \($0)) \($1.command) ;;" }.joined(separator: "\n")
        let source = """
            #!/bin/sh
            tools=\(GitRunner.shellQuoted(tools.path))
            case "$*" in
                *show*":(top,literal)a.txt"*)
                    if [ -e "$tools/fail" ]; then echo 'test read failed' >&2; exit 17; fi
                    output=$(mktemp "$tools/output.XXXXXXXX")
                    /usr/bin/git "$@" > "$output"
                    code=$?
                    unified=
                    for arg in "$@"; do
                        case "$arg" in --unified=*) unified=${arg#--unified=} ;; esac
                    done
                    case "$unified" in
            \(branches)
                    esac
                    cat "$output"
                    rm -f "$output"
                    exit $code
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

    /// 提交当前工作区并读取真实元信息。
    private func commit(_ runner: GitRunner) async throws -> HistoryCommit {
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-qm", "change"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        return try #require(try await RepositoryHistory(runner: runner).page(roots: [head]).commits.first)
    }
}
