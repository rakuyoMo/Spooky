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
