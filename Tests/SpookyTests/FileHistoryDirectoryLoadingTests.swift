import Foundation
import Testing

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
            try? Data().write(to: tools.appending(path: "gate"))
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
        let gated = try gatedRunner(location: runner.location, tools: tools)
        let activities = RepositoryActivities()
        let state = FileHistoryDirectoryState()
        defer { state.close() }

        try Data().write(to: tools.appending(path: "fail"))
        state.open(commit: first, files: firstFiles, runner: gated, activities: activities, records: true)
        for file in firstFiles { state.setVisible(file.path, visible: true, identity: state.identity) }
        try await FileViewsTests.wait { state.failures["a.txt"] != nil && state.diffs["b.txt"] != nil }
        #expect(state.failures["b.txt"] == nil)
        #expect(activities.items.contains { $0.state == "activity.failed" })

        try FileManager.default.removeItem(at: tools.appending(path: "fail"))
        state.load("a.txt", retry: true)
        try await FileViewsTests.wait { FileManager.default.fileExists(atPath: tools.appending(path: "read").path) }
        state.reloadDiffs()
        state.reloadDiffs()
        let oldIdentity = state.identity

        state.open(commit: second, files: secondFiles, runner: gated, activities: activities, records: true)
        state.setVisible("a.txt", visible: true, identity: state.identity)
        state.open(commit: first, files: firstFiles, runner: gated, activities: activities, records: true)
        state.setVisible("a.txt", visible: true, identity: state.identity)
        state.setVisible("a.txt", visible: false, identity: oldIdentity)
        let request = state.requests["a.txt"]
        try Data().write(to: tools.appending(path: "gate"))
        try await FileViewsTests.wait { state.diffs["a.txt"] != nil && state.loadingPaths.isEmpty }
        #expect(state.requests["a.txt"] == request)
        #expect(state.commit?.id == first.id)
        #expect(state.failures.isEmpty)

        let file = try #require(state.diffs["a.txt"]?.diff?.files.first)
        #expect(file.hunks.flatMap(\.lines).contains { String(decoding: $0.content, as: UTF8.self) == "first" })
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
            try? Data().write(to: tools.appending(path: "gate"))
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: tools)
        }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        let original = (1 ... 30).map { "line \($0)" }.joined(separator: "\n") + "\n"
        try Data(original.utf8).write(to: directory.appending(path: "a.txt"))
        _ = try await commit(runner)
        let changed = original.replacingOccurrences(of: "line 15", with: "changed 15")
            .replacingOccurrences(of: "line 25", with: "line   25")
        try Data(changed.utf8).write(to: directory.appending(path: "a.txt"))
        let head = try await commit(runner)
        let files = try await RepositoryHistory(runner: runner).changes(in: head.id)
        let gated = try gatedRunner(location: runner.location, tools: tools)
        let activities = RepositoryActivities()
        let state = FileHistoryDirectoryState(defaults: defaults)
        defer { state.close() }
        defaults.set(1, forKey: DiffPreferences.contextLinesKey)
        state.open(commit: head, files: files, runner: gated, activities: activities, records: true)
        state.setVisible("a.txt", visible: true, identity: state.identity)
        try await FileViewsTests.wait { FileManager.default.fileExists(atPath: tools.appending(path: "read-1").path) }
        defaults.set(5, forKey: DiffPreferences.contextLinesKey)
        state.reloadDiffs()
        try await FileViewsTests.wait { FileManager.default.fileExists(atPath: tools.appending(path: "read-5").path) }
        defaults.set(10, forKey: DiffPreferences.contextLinesKey)
        defaults.set(true, forKey: DiffPreferences.ignoresWhitespaceKey)
        state.reloadDiffs()
        try await FileViewsTests.wait { FileManager.default.fileExists(atPath: tools.appending(path: "read-10").path) }
        let request = state.requests["a.txt"]
        try Data().write(to: tools.appending(path: "gate"))
        try await FileViewsTests.wait { state.diffs["a.txt"] != nil && state.loadingPaths.isEmpty && activities.items.count == 3 }
        let expected = try await RepositoryHistory(runner: runner).diff(
            in: head.id, file: #require(files.first), options: DiffOptions(contextLines: 10, ignoresWhitespace: true)
        )
        #expect(state.diffs["a.txt"]?.diff == expected.diff)
        #expect(state.requests["a.txt"] == request)
        #expect(state.failures.isEmpty)
        #expect(activities.items.filter { $0.state == "activity.cancelled" }.count == 2)
        #expect(activities.items.filter { $0.state == "activity.finished" }.count == 1)
    }

    /// 换仓库后的同路径请求与关闭后的空状态都不接受迟到结果。
    @Test("目录加载中切换同路径目标或关闭", arguments: [false, true])
    func targetBoundary(close: Bool) async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        let replacement = try FileViewsTests.temporaryDirectory()
        let tools = try FileViewsTests.temporaryDirectory()
        defer {
            try? Data().write(to: tools.appending(path: "gate"))
            for url in [directory, replacement, tools] { try? FileManager.default.removeItem(at: url) }
        }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        try Data("old target\n".utf8).write(to: directory.appending(path: "a.txt"))
        let old = try await commit(runner)
        let newRunner = try await FileViewsTests.initializeRepository(at: .local(path: replacement.path))
        try Data("new target\n".utf8).write(to: replacement.appending(path: "a.txt"))
        let new = try await commit(newRunner)
        let oldFiles = try await RepositoryHistory(runner: runner).changes(in: old.id)
        let newFiles = try await RepositoryHistory(runner: newRunner).changes(in: new.id)
        let activities = RepositoryActivities()
        let state = FileHistoryDirectoryState()
        defer { state.close() }
        state.open(
            commit: old, files: oldFiles, runner: try gatedRunner(location: runner.location, tools: tools),
            activities: activities, records: true
        )
        state.setVisible("a.txt", visible: true, identity: state.identity)
        try await FileViewsTests.wait { FileManager.default.fileExists(atPath: tools.appending(path: "read").path) }
        let identity = state.identity
        state.close()

        if !close {
            state.open(commit: new, files: newFiles, runner: newRunner, activities: activities, records: true)
            state.setVisible("a.txt", visible: true, identity: state.identity)
            state.setVisible("a.txt", visible: false, identity: identity)
        }

        try Data().write(to: tools.appending(path: "gate"))
        try await FileViewsTests.wait {
            activities.items.contains { $0.state == "activity.cancelled" }
                && state.loadingPaths.isEmpty && (close || state.diffs["a.txt"] != nil)
        }
        #expect(state.failures.isEmpty)

        if close {
            #expect(state.commit == nil && state.files.isEmpty && state.diffs.isEmpty && state.requests.isEmpty)
        } else {
            #expect(state.commit?.id == new.id)
            let lines = try #require(state.diffs["a.txt"]?.diff).files.flatMap(\.hunks).flatMap(\.lines)
            #expect(lines.map { String(decoding: $0.content, as: UTF8.self) } == ["new target"])
            state.reloadDiffs()
            try await FileViewsTests.wait { state.diffs["a.txt"] != nil }
        }
    }

    /// 真实 Git 读完后等待显式闸门，失败路径保留退出码与原文。
    private func gatedRunner(location: RepositoryLocation, tools: URL) throws -> GitRunner {
        let script = tools.appending(path: "git")
        try Data("""
            #!/bin/sh
            case "$*" in
                *show*":(top,literal)a.txt"*)
                    tools=$(dirname "$0")
                    if [ -e "$tools/fail" ]; then echo 'test read failed' >&2; exit 17; fi
                    output=$(mktemp "$tools/output.XXXXXXXX")
                    /usr/bin/git "$@" > "$output"
                    code=$?
                    for arg in "$@"; do
                        case "$arg" in --unified=*) : > "$tools/read-${arg#--unified=}" ;; esac
                    done
                    : > "$tools/read"
                    while [ ! -e "$tools/gate" ]; do sleep 0.02; done
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

    /// 提交当前工作区并读取真实元信息。
    private func commit(_ runner: GitRunner) async throws -> HistoryCommit {
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-qm", "change"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        return try #require(try await RepositoryHistory(runner: runner).page(roots: [head]).commits.first)
    }
}
