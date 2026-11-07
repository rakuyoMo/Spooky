import Foundation
import Testing

@testable import SpookyKit

/// 合并停在冲突上时返回冲突结果；同样以非零退出的其它失败照原样抛出 Git 的错误。
extension RepositorySyncTests {
    /// 普通合并与压缩合并的内容冲突都返回冲突结果，Git 留下合并状态与冲突文件。
    @Test("合并与压缩合并的冲突返回冲突结果", arguments: [false, true])
    func mergeConflicts(squash: Bool) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize()

        let runner = fixture.runner
        try await divergedBranches(fixture, side: "side\n", main: "main\n")

        var options = MergeOptions()
        options.squash = squash

        let outcome = try await RepositorySync(runner: runner)
            .merge("refs/heads/side", options: options)

        let head = try await runner.status().branch.oid
        let progress = try await WorkingCopyOperations(runner: runner)
            .context(head: head)
            .progress

        #expect(outcome == .conflicts)
        #expect(progress?.state == (squash ? .squash : .merge))
        #expect(try await runner.status().entries.map(\.kind) == [.conflicted])
    }

    /// 合并干净、只是 pre-merge-commit 钩子失败时同样以 1 退出，仍是失败；锁文件挡住的合并抛出原始错误。
    @Test("钩子失败与锁文件仍抛出 Git 的错误")
    func mergeFailures() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize()

        let runner = fixture.runner
        let sync = RepositorySync(runner: runner)
        try await divergedBranches(fixture, side: "side\n", main: "base\n", other: "other\n")

        // 钩子拒绝合并提交：Git 留下 MERGE_HEAD，但没有冲突文件
        let located = try await runner.run(["rev-parse", "--path-format=absolute", "--git-path", "hooks"])
        let hooks = String(decoding: located, as: UTF8.self).trimmingCharacters(in: .newlines)

        let hook = URL(fileURLWithPath: hooks).appending(path: "pre-merge-commit")
        try FileManager.default.createDirectory(atPath: hooks, withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 1\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)

        var options = MergeOptions()
        options.alwaysCreateCommit = true

        do {
            try await sync.merge("refs/heads/side", options: options)
            Issue.record("钩子失败的合并应抛出错误")
        } catch let error as GitError {
            #expect(error.exitCode == 1)
        }

        // 清掉钩子留下的合并状态，再用锁文件挡住下一次合并
        _ = try await runner.run(["merge", "--abort"])
        try FileManager.default.removeItem(at: hook)

        let lock = URL(fileURLWithPath: hooks).deletingLastPathComponent().appending(path: "index.lock")
        try Data().write(to: lock)

        do {
            try await sync.merge("refs/heads/side", options: options)
            Issue.record("锁文件挡住的合并应抛出错误")
        } catch let error as GitError {
            #expect(error.exitCode == 128)
            #expect(error.message.contains("index.lock"))
        }

        try FileManager.default.removeItem(at: lock)
    }
}

// MARK: - Private

extension RepositorySyncTests {
    /// 在 base 上分出 side 分支：两边都改 file；给出 other 时 main 改另一个文件，合并不冲突。
    private func divergedBranches(
        _ fixture: TemporaryRepository,
        side: String,
        main: String,
        other: String? = nil
    ) async throws {
        let runner = fixture.runner
        let file = fixture.directory.appending(path: "file")

        try Data("base\n".utf8).write(to: file)
        _ = try await runner.run(["add", "-A"])
        _ = try await runner.run(["commit", "-q", "-m", "base"])

        _ = try await runner.run(["checkout", "-q", "-b", "side"])
        try Data(side.utf8).write(to: file)
        _ = try await runner.run(["commit", "-q", "-am", "side"])
        _ = try await runner.run(["checkout", "-q", "main"])

        try Data(main.utf8).write(to: file)

        if let other {
            try Data(other.utf8).write(to: fixture.directory.appending(path: "other"))
        }

        _ = try await runner.run(["add", "-A"])
        _ = try await runner.run(["commit", "-q", "-m", "main"])
    }
}
