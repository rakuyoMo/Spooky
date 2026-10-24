import Foundation
import Testing

@testable import SpookyKit

// MARK: - Reset, Checkout and Rebase Onto

extension RepositoryRewriteTests {
    /// 三档重置都把 HEAD 移回目标；soft 把撤下的改动留在暂存区，mixed 留在工作区，hard 连本地改动一起丢弃。
    @Test("重置的三档与工作区改动", arguments: [ResetMode.soft, .mixed, .hard])
    func reset(mode: ResetMode) async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        try write("本地改动\n", to: file(0), in: repository)
        let rewrite = RepositoryRewrite(runner: repository.runner)

        #expect(try await rewrite.commitsLeaving(to: commits[0]).map(\.id) == [commits[1]])

        try await rewrite.reset(to: commits[0], mode: mode)

        let status = try await repository.runner.status()
        let removed = status.entries.first { $0.path == file(1) }
        #expect(status.branch.oid == commits[0])

        switch mode {
        case .soft:
            #expect(removed?.hasStagedChanges ?? false)
            #expect(try read(file(0), in: repository) == "本地改动\n")

        case .mixed:
            #expect(removed?.kind == .untracked)
            #expect(try read(file(0), in: repository) == "本地改动\n")

        case .hard:
            #expect(status.entries.isEmpty)
            #expect(try read(file(0), in: repository) == "一\n")
        }
    }

    /// 本地分支名切换分支；标签、提交与远端分支都分离 HEAD。
    @Test("检出分支、标签、提交与远端分支")
    func checkoutRevision() async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        _ = try await repository.runner.run(["branch", "功能/分支", commits[0]])
        _ = try await repository.runner.run(["tag", "v1", commits[0]])
        _ = try await repository.runner.run(["update-ref", "refs/remotes/origin/main", commits[1]])
        let rewrite = RepositoryRewrite(runner: repository.runner)

        #expect(try await rewrite.checkoutTarget(for: "功能/分支") == .branch("refs/heads/功能/分支"))
        #expect(try await rewrite.checkoutTarget(for: "v1") == .detached(commits[0]))
        #expect(try await rewrite.checkoutTarget(for: "origin/main") == .detached(commits[1]))

        try await rewrite.checkout(revision: "功能/分支")
        #expect(try await repository.runner.status().branch.head == "功能/分支")

        try await rewrite.checkout(revision: "origin/main")
        let detached = try await repository.runner.status().branch
        #expect(detached.head == nil)
        #expect(detached.oid == commits[1])

        try await rewrite.checkout(revision: String(commits[0].prefix(10)))
        #expect(try await head(in: repository) == commits[0])

        await #expect(throws: GitError.self) { try await rewrite.checkout(revision: "--orphan") }
    }

    /// 变基到别处只移走当前基点之后的提交，Skip Hooks 绕过 pre-rebase 钩子。
    @Test("变基到别处")
    func rebaseOnto() async throws {
        let (repository, commits) = try await makeRepository(["基础", "旧基点"])
        defer { repository.remove() }

        _ = try await repository.runner.run(["switch", "-q", "-c", "topic"])
        try write("主题\n", to: "主题 *.txt", in: repository)
        _ = try await repository.runner.run(["add", "--all"])
        _ = try await repository.runner.run(["commit", "-q", "-m", "主题"])
        let newBase = try await sideBranch(["新基点"], from: commits[0], in: repository).last ?? ""
        _ = try await repository.runner.run(["switch", "-q", "topic"])
        try installHook("pre-rebase", script: "exit 1", in: repository)
        let rewrite = RepositoryRewrite(runner: repository.runner)

        await #expect(throws: GitError.self) {
            try await rewrite.rebase(onto: newBase, from: commits[1], skipHooks: false)
        }

        try await rewrite.rebase(onto: "side", from: commits[1], skipHooks: true)

        #expect(try await subjects(in: repository) == ["主题", "新基点", "基础"])
    }

    /// 已跟踪文件有未暂存的改动时，变基被挡住，失败归为本地改动。
    @Test("变基被本地改动挡住")
    func rebaseBlockedByLocalChanges() async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        try write("本地\n", to: file(1), in: repository)

        let error = await #expect(throws: GitError.self) {
            try await RepositoryRewrite(runner: repository.runner)
                .rebase(onto: commits[0], from: commits[0], skipHooks: false)
        }

        #expect(error?.category == .localChanges)
    }

    /// 在仓库的钩子目录写一个可执行的 sh 钩子。
    func installHook(_ name: String, script: String, in repository: TemporaryRepository) throws {
        let hooks = repository.directory.appending(path: ".git/hooks")
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)

        let hook = hooks.appending(path: name)
        try Data("#!/bin/sh\n\(script)\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)
    }
}
