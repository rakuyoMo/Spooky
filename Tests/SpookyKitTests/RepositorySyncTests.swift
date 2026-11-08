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

        try Self.exclude("remote.git/\nother/\n", in: fixture)
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

        // 首次发布设好上游
        let published = try await sync.push(
            branch: "main",
            remote: "origin",
            destination: "main",
            setUpstream: true
        )

        #expect(published.contains { $0.flag == "*" && $0.reference == "refs/heads/main" })
        #expect(try await Self.upstream(of: "refs/heads/main", in: refs) == "refs/remotes/origin/main")

        // 另一个工作区推上一个提交，获取后落后一个提交
        let other = try await Self.otherClone(of: bare, in: fixture)
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

        #expect(try await Self.upstream(of: "refs/heads/tracked", in: refs) == "refs/remotes/origin/main")

        // 显式的 merge 拉取不受 pull.rebase 影响
        _ = try await runner.run(["config", "--local", "pull.rebase", "true"])
        try await sync.pull(rebase: false)
        #expect(try await refs.resolve("HEAD") == upstream)

        // 两边各有新提交时普通推送被拒绝，变基拉取后再推
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

    /// 检出不覆盖改动，普通删除不删除未合并提交，合并预览发现冲突且不改动工作区；
    /// 不支持 merge-tree 的环境必须显示未知，不能误报为可干净合并。
    @Test("分支名称、未合并删除、检出保护、合并预览与预览不可用")
    func branchSafety() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        let sync = RepositorySync(runner: runner)
        let file = fixture.directory.appendingPathComponent("file")
        let name = "topic/你好'$(value)"

        try Data("base\n".utf8).write(to: file)
        _ = try await runner.run(["add", "file"])
        _ = try await runner.run(["commit", "-m", "base"])

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

        // 有本地改动时检出与合并都不开始
        try Data("main\n".utf8).write(to: file)

        do {
            try await refs.checkout("refs/heads/" + name)
            Issue.record("检出不能覆盖本地修改")
        } catch let error as GitError {
            #expect(error.category == .localChanges)
        }

        #expect(try String(contentsOf: file, encoding: .utf8) == "main\n")

        await #expect(throws: RepositorySyncError.dirtyWorkingCopy(rebase: false)) {
            try await sync.merge("refs/heads/" + name)
        }

        // 合并预览只报出冲突的文件
        _ = try await runner.run(["commit", "-am", "main"])

        guard case .conflicts(let paths) = try await sync.previewMerge("refs/heads/" + name) else {
            Issue.record("预览必须发现冲突")
            return
        }

        #expect(paths == ["file"])
        #expect(try await runner.status().entries.isEmpty)
        #expect(RepositoryReferences.normalizedName(" /..feature 你:*好@{test") == "feature-你好test")

        // 分离 HEAD 时拉取要求先在分支上
        _ = try await runner.run(["switch", "--detach", "HEAD"])
        #expect(try await runner.status().branch.head == nil)

        await #expect(throws: RepositorySyncError.requiresBranch) {
            try await sync.pull(rebase: false)
        }

        try await Self.previewUnavailable(in: fixture)
    }
}

// MARK: - Untracked Files

extension RepositorySyncTests {
    /// 只有未跟踪的文件时拉取与合并照常执行，文件不动；合并预览把快进算作干净，HEAD 自身与已并入的分支算作无需合并。
    /// 远端或所选版本带来同名文件时由 Git 拒绝：HEAD 与未跟踪文件的内容都不变，错误保留 Git 的原文。
    @Test("只有未跟踪文件时直接拉取与合并，同名文件由 Git 拒绝")
    func untrackedFiles() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let sync = RepositorySync(runner: runner)
        let bare = fixture.directory.appendingPathComponent("remote.git").path

        try Self.exclude("remote.git/\nother/\n", in: fixture)
        _ = try await runner.run(["init", "--bare", bare])
        _ = try await runner.run(["remote", "add", "origin", bare])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await sync.push(branch: "main", remote: "origin", destination: "main", setUpstream: true)

        let other = try await Self.otherClone(of: bare, in: fixture)

        // 另一个克隆提交一个新文件并推上远端
        func pushFile(_ name: String) async throws {
            let file = fixture.directory.appendingPathComponent("other/" + name)
            try Data("remote\n".utf8).write(to: file)
            _ = try await other.run(["add", name])
            _ = try await other.run(["commit", "-m", name])
            _ = try await other.run(["push", "origin", "main"])
        }

        let notes = fixture.directory.appendingPathComponent("notes.txt")
        try Data("mine\n".utf8).write(to: notes)

        // 拉取：远端带来别的文件
        try await pushFile("incoming.txt")
        try await sync.pull(rebase: false)

        let incoming = fixture.directory.appendingPathComponent("incoming.txt")

        #expect(FileManager.default.fileExists(atPath: incoming.path))
        #expect(try String(contentsOf: notes, encoding: .utf8) == "mine\n")

        // 合并：本地分支领先 HEAD 一个提交，可以快进
        _ = try await runner.run(["switch", "-q", "-c", "topic"])
        try Data("topic\n".utf8).write(to: fixture.directory.appendingPathComponent("topic.txt"))
        _ = try await runner.run(["add", "topic.txt"])
        _ = try await runner.run(["commit", "-m", "topic"])
        _ = try await runner.run(["switch", "-q", "main"])

        #expect(try await sync.previewMerge("refs/heads/topic") == .clean)
        #expect(try await sync.previewMerge("refs/heads/main") == .unchanged)
        #expect(try await sync.merge("refs/heads/topic") == .merged)
        #expect(try await sync.previewMerge("refs/heads/topic") == .unchanged)
        #expect(try String(contentsOf: notes, encoding: .utf8) == "mine\n")

        try await Self.expectUntrackedConflicts(in: fixture, pushing: pushFile)
    }
}

// MARK: - Publish

extension RepositorySyncTests {
    /// 仓库还没有分支与标签时，发布仓库照样推送；Git 报出的失败原样交给调用方，也不会给任何分支设上游。
    /// 发布仓库推上全部本地分支与标签，别的远端的跟踪分支不跟着推；原来没有上游的分支跟踪新远端，已有的上游不被换掉。
    @Test("推送全部分支与标签，只给没有上游的分支设上游；没有分支与标签时推送失败")
    func pushBranchesAndTags() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let sync = RepositorySync(runner: runner)
        let old = fixture.directory.appendingPathComponent("old.git").path
        let new = fixture.directory.appendingPathComponent("new.git").path

        try Self.exclude("old.git/\nnew.git/\n", in: fixture)
        _ = try await runner.run(["init", "-q", "--bare", old])
        _ = try await runner.run(["init", "-q", "--bare", new])
        _ = try await runner.run(["remote", "add", "new", new])

        try await Self.pushWithoutReferences(sync, runner: runner, remote: new)

        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["tag", "-a", "-m", "发布", "v1"])

        // feature/中文 跟踪 old 上的同名分支；old 还有一个只在本地的跟踪分支 x
        _ = try await runner.run(["remote", "add", "old", old])
        _ = try await runner.run(["branch", "feature/中文"])
        _ = try await runner.run(["push", "-q", "-u", "old", "feature/中文"])
        _ = try await runner.run(["update-ref", "refs/remotes/old/x", "HEAD"])

        let pushed: Set<String> = ["refs/heads/main", "refs/heads/feature/中文", "refs/tags/v1"]
        let updates = try await sync.pushBranchesAndTags(to: "new")
        #expect(Set(updates.map(\.reference)) == pushed)

        // 新远端上只有本地分支与标签，没有任何远端跟踪分支
        let remoteReferences = try await fixture.runner(at: new).run(["for-each-ref", "--format=%(refname)"])
        let names = String(decoding: remoteReferences, as: UTF8.self).split(separator: "\n").map(String.init)
        #expect(Set(names) == pushed)

        let refs = RepositoryReferences(runner: runner)
        #expect(try await Self.upstream(of: "refs/heads/main", in: refs) == "refs/remotes/new/main")
        #expect(try await Self.upstream(of: "refs/heads/feature/中文", in: refs) == "refs/remotes/old/feature/中文")

        await #expect(throws: RepositorySyncError.missingRemote) {
            _ = try await sync.pushBranchesAndTags(to: "missing")
        }
    }
}

// MARK: - Steps

extension RepositorySyncTests {
    /// 没有分支与标签时推送失败，Git 原文不变；远端仍在，本地配置里没有任何分支的上游。
    private static func pushWithoutReferences(
        _ sync: RepositorySync,
        runner: GitRunner,
        remote: String
    ) async throws {
        do {
            _ = try await sync.pushBranchesAndTags(to: "new")
            Issue.record("没有分支与标签的推送应失败")
        } catch let error as GitError {
            #expect(error.exitCode == 1)
            #expect(error.message.contains("No refs in common"))
        }

        let config = try await runner.run(["config", "--local", "--list"])
        let entries = String(decoding: config, as: UTF8.self).split(separator: "\n")
        #expect(entries.contains("remote.new.url=" + remote))
        #expect(!entries.contains { $0.hasPrefix("branch.") })
    }

    /// 假的 git 让 merge-tree 报出不认识的选项：预览保留未知状态与 Git 的原文。
    private static func previewUnavailable(in fixture: TemporaryRepository) async throws {
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
        let preview = try await RepositorySync(runner: runner).previewMerge("HEAD")

        guard case .unavailable(let message) = preview else {
            Issue.record("预览失败必须保留未知状态")
            return
        }

        #expect(message.contains("unknown option"))
    }

    /// 远端带来与未跟踪文件同名的文件：拉取与合并都被 Git 拒绝，文件内容与 HEAD 不变。
    ///
    /// - Parameter pushing: 让远端多出一个这个名字的文件。
    private static func expectUntrackedConflicts(
        in fixture: TemporaryRepository,
        pushing: (String) async throws -> Void
    ) async throws {
        let runner = fixture.runner
        let sync = RepositorySync(runner: runner)
        let clash = fixture.directory.appendingPathComponent("clash.txt")
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")

        try await pushing("clash.txt")
        try Data("mine\n".utf8).write(to: clash)

        do {
            try await sync.pull(rebase: false)
            Issue.record("会覆盖未跟踪文件的拉取应被 Git 拒绝")
        } catch let error as GitError {
            #expect(error.message.contains("untracked working tree files would be overwritten"))
        }

        // 拉取的获取已更新远端跟踪分支，再直接合并它
        do {
            try await sync.merge("refs/remotes/origin/main")
            Issue.record("会覆盖未跟踪文件的合并应被 Git 拒绝")
        } catch let error as GitError {
            #expect(error.message.contains("untracked working tree files would be overwritten"))
        }

        #expect(try String(contentsOf: clash, encoding: .utf8) == "mine\n")
        #expect(try await RepositoryReferences(runner: runner).resolve("HEAD") == head)
    }

    /// 从裸远端克隆 `main` 到 `other`，提交身份只写进克隆自己的本地配置。
    private static func otherClone(of bare: String, in fixture: TemporaryRepository) async throws -> GitRunner {
        let path = fixture.directory.appendingPathComponent("other").path
        _ = try await fixture.runner.run(["clone", "-b", "main", bare, path])

        let other = fixture.runner(at: path)
        _ = try await other.run(["config", "--local", "user.name", "Other"])
        _ = try await other.run(["config", "--local", "user.email", "other@example.invalid"])
        _ = try await other.run(["config", "--local", "commit.gpgSign", "false"])

        return other
    }
}

// MARK: - Helpers

extension RepositorySyncTests {
    /// 把放在工作区目录里的裸远端与克隆写进 `.git/info/exclude`，不影响工作区状态。
    ///
    /// - Parameter patterns: 排除规则，每行一条。
    static func exclude(_ patterns: String, in fixture: TemporaryRepository) throws {
        try FileManager.default.createDirectory(
            at: fixture.directory.appendingPathComponent(".git/info"),
            withIntermediateDirectories: true
        )

        try Data(patterns.utf8).write(to: fixture.directory.appendingPathComponent(".git/info/exclude"))
    }

    /// 本地分支的上游；没有设上游时为 nil。
    private static func upstream(of branch: String, in refs: RepositoryReferences) async throws -> String? {
        try await refs.snapshot().references.first { $0.id == branch }?.upstream
    }
}
