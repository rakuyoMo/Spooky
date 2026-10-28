import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositorySyncTests

/// 同步测试的远端只指向测试目录中的裸仓库。
struct RepositorySyncTests {
    /// 发布后由第二个工作区更新，再完成 Fetch、Pull 和 Push。
    @Test("首次发布、获取、显式 merge / rebase、拒绝与无上游")
    func dailyFlow() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize()
        let runner = fixture.runner
        let sync = RepositorySync(runner: runner)
        let refs = RepositoryReferences(runner: runner)
        let bare = fixture.directory.appendingPathComponent("remote.git").path
        let otherPath = fixture.directory.appendingPathComponent("other").path
        try FileManager.default.createDirectory(
            at: fixture.directory.appendingPathComponent(".git/info"),
            withIntermediateDirectories: true
        )
        try Data("remote.git/\nother/\n".utf8)
            .write(to: fixture.directory.appendingPathComponent(".git/info/exclude"))
        _ = try await runner.run(["init", "--bare", bare])
        _ = try await runner.run(["remote", "add", "origin", bare])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])

        do {
            try await sync.pull(rebase: false)
            Issue.record("无上游的拉取应失败")
        } catch let error as GitError {
            #expect(error.category == .noUpstream)
            #expect(error.exitCode != 0 && !error.message.isEmpty)
        }

        let published = try await sync.push(
            branch: "main",
            remote: "origin",
            destination: "main",
            setUpstream: true
        )
        #expect(published.contains { $0.flag == "*" && $0.reference == "refs/heads/main" })
        #expect(
            try await refs.snapshot().references.first { $0.id == "refs/heads/main" }?.upstream
                == "refs/remotes/origin/main"
        )
        _ = try await runner.run(["clone", "-b", "main", bare, otherPath])
        let other = fixture.runner(at: otherPath)
        _ = try await other.run(["config", "--local", "user.name", "Other"])
        _ = try await other.run(["config", "--local", "user.email", "other@example.invalid"])
        _ = try await other.run(["config", "--local", "commit.gpgSign", "false"])
        _ = try await other.run(["commit", "--allow-empty", "-m", "remote update"])
        _ = try await other.run(["push", "origin", "main"])
        let fetched = try await sync.fetch(prune: true)
        #expect(fetched.contains { $0.reference == "refs/remotes/origin/main" })
        let before = try await refs.resolve("HEAD")
        let upstream = try await refs.resolve("refs/remotes/origin/main")
        #expect(try await refs.divergence(local: before, upstream: upstream).behind == 1)
        try await refs.create(
            name: "tracked",
            startingAt: "refs/remotes/origin/main",
            track: true,
            checkout: false
        )
        #expect(
            try await refs.snapshot().references.first { $0.id == "refs/heads/tracked" }?.upstream
                == "refs/remotes/origin/main"
        )
        _ = try await runner.run(["config", "--local", "pull.rebase", "true"])
        try await sync.pull(rebase: false)
        #expect(try await refs.resolve("HEAD") == upstream)

        _ = try await runner.run(["commit", "--allow-empty", "-m", "local update"])
        _ = try await other.run(["commit", "--allow-empty", "-m", "another remote"])
        _ = try await other.run(["push", "origin", "main"])
        do {
            _ = try await sync.push(branch: "main", remote: "origin", destination: "main", setUpstream: false)
            Issue.record("分叉历史的普通推送应被拒绝")
        } catch let error as GitError {
            #expect(error.category == .pushRejected)
            #expect(error.exitCode == 1 && !error.result.standardOutput.isEmpty)
        }
        try await sync.pull(rebase: true)
        _ = try await sync.push(branch: "main", remote: "origin", destination: "main", setUpstream: false)
        #expect(try await runner.status().branch.ahead == 0)
    }

    /// 检出不覆盖改动，普通删除不删除未合并提交。
    @Test("分支名称、未合并删除、检出保护和合并预览")
    func branchSafety() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize()
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        let sync = RepositorySync(runner: runner)
        let file = fixture.directory.appendingPathComponent("file")
        try Data("base\n".utf8).write(to: file)
        _ = try await runner.run(["add", "file"])
        _ = try await runner.run(["commit", "-m", "base"])
        let name = "topic/你好'$(value)"
        try await refs.create(name: name, startingAt: "HEAD", track: false, checkout: true)
        try Data("topic\n".utf8).write(to: file)
        _ = try await runner.run(["commit", "-am", "topic"])
        try await refs.checkout("refs/heads/main")
        do {
            try await refs.delete(["refs/heads/" + name])
            Issue.record("未合并分支不能删除")
        } catch ReferenceError.unmergedBranches(let names, let error) {
            #expect(names == ["refs/heads/" + name])
            #expect(error.category == .branchNotMerged && error.exitCode == 1)
        }
        try Data("main\n".utf8).write(to: file)
        do {
            try await refs.checkout("refs/heads/" + name)
            Issue.record("检出不能覆盖本地修改")
        } catch let error as GitError {
            #expect(error.category == .localChanges)
        }
        #expect(try String(contentsOf: file, encoding: .utf8) == "main\n")
        await #expect(throws: RepositorySyncError.dirtyWorkingCopy) {
            try await sync.merge("refs/heads/" + name)
        }
        _ = try await runner.run(["commit", "-am", "main"])
        guard case .conflicts(let paths) = try await sync.previewMerge("refs/heads/" + name) else {
            Issue.record("预览必须发现冲突")
            return
        }
        #expect(paths == ["file"])
        #expect(try await runner.status().entries.isEmpty)
        #expect(RepositoryReferences.normalizedName(" /..feature 你:*好@{test") == "feature-你好test")
        _ = try await runner.run(["switch", "--detach", "HEAD"])
        #expect(try await runner.status().branch.head == nil)
        await #expect(throws: RepositorySyncError.requiresBranch) { try await sync.pull(rebase: false) }
    }

    /// 不支持 merge-tree 的环境必须显示未知，不能误报为可干净合并。
    @Test("合并预览不可用与远端不存在的诊断")
    func previewUnavailable() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize()
        _ = try await fixture.runner.run([
            "remote", "add", "missing", fixture.directory.appendingPathComponent("missing.git").path,
        ])
        do {
            _ = try await RepositorySync(runner: fixture.runner).fetch()
            Issue.record("不存在的远端不能获取成功")
        } catch let error as GitError {
            #expect(error.category == .remoteNotFound && error.exitCode == 128)
            #expect(!error.message.isEmpty)
        }
        let executable = fixture.directory.appendingPathComponent("git-preview")
        let script = """
            #!/bin/sh
            for argument do
                case "$argument" in
                    rev-parse) printf '%s\\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; exit 0 ;;
                    merge-base) exit 1 ;;
                    merge-tree) printf '%s\\n' 'unknown option: write-tree' >&2; exit 129 ;;
                esac
            done
            exit 1
            """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let runner = fixture.runner(at: fixture.directory.path, executable: executable.path)
        guard case .unavailable(let message) = try await RepositorySync(runner: runner).previewMerge("HEAD")
        else {
            Issue.record("预览失败必须保留未知状态")
            return
        }
        #expect(message.contains("unknown option"))
    }
}

// MARK: - Publish

extension RepositorySyncTests {
    /// 发布仓库推上全部本地分支与标签，别的远端的跟踪分支不跟着推；原来没有上游的分支跟踪新远端，已有的上游不被换掉。
    @Test("推送全部分支与标签，只给没有上游的分支设上游")
    func pushBranchesAndTags() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let old = fixture.directory.appendingPathComponent("old.git").path
        let new = fixture.directory.appendingPathComponent("new.git").path

        // 两个裸远端放在工作区目录里，排除后不影响工作区状态
        try FileManager.default.createDirectory(
            at: fixture.directory.appendingPathComponent(".git/info"),
            withIntermediateDirectories: true
        )
        try Data("old.git/\nnew.git/\n".utf8)
            .write(to: fixture.directory.appendingPathComponent(".git/info/exclude"))

        _ = try await runner.run(["init", "-q", "--bare", old])
        _ = try await runner.run(["init", "-q", "--bare", new])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["tag", "-a", "-m", "发布", "v1"])

        // feature/中文 跟踪 old 上的同名分支；old 还有一个只在本地的跟踪分支 x
        _ = try await runner.run(["remote", "add", "old", old])
        _ = try await runner.run(["branch", "feature/中文"])
        _ = try await runner.run(["push", "-q", "-u", "old", "feature/中文"])
        _ = try await runner.run(["update-ref", "refs/remotes/old/x", "HEAD"])
        _ = try await runner.run(["remote", "add", "new", new])

        let sync = RepositorySync(runner: runner)
        let pushed: Set<String> = ["refs/heads/main", "refs/heads/feature/中文", "refs/tags/v1"]
        let updates = try await sync.pushBranchesAndTags(to: "new")
        #expect(Set(updates.map(\.reference)) == pushed)

        // 新远端上只有本地分支与标签，没有任何远端跟踪分支
        let remoteReferences = try await fixture.runner(at: new).run(["for-each-ref", "--format=%(refname)"])
        let names = String(decoding: remoteReferences, as: UTF8.self).split(separator: "\n").map(String.init)
        #expect(Set(names) == pushed)

        let branches = try await RepositoryReferences(runner: runner).snapshot().references
        #expect(branches.first { $0.id == "refs/heads/main" }?.upstream == "refs/remotes/new/main")
        #expect(branches.first { $0.id == "refs/heads/feature/中文" }?.upstream == "refs/remotes/old/feature/中文")

        await #expect(throws: RepositorySyncError.missingRemote) {
            _ = try await sync.pushBranchesAndTags(to: "missing")
        }
    }
}
