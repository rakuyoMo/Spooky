import Foundation
import Testing

@testable import SpookyKit

// MARK: - RecoveryWorkflowTests

/// 本机的引用与恢复闭环：建分支 → 提交 → 标签 → 获取 → 变基拉取 → 推送 → 安全强推 → 从 Reflog 恢复。
struct RecoveryWorkflowTests {
    /// 一次完整流程只使用临时仓库与测试目录中的裸仓库，结束后删除。
    @Test("建分支、标签、变基拉取、安全强推与 Reflog 恢复")
    func recoveryLoop() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let sync = RepositorySync(runner: runner)
        let bare = fixture.directory.appending(path: "remote.git").path
        let branch = "feature/恢复"

        // 裸仓库与第二个工作区放在测试目录内，并从主工作区的状态中排除
        try FileManager.default.createDirectory(
            at: fixture.directory.appending(path: ".git/info"),
            withIntermediateDirectories: true
        )

        try Data("remote.git/\nother/\n".utf8).write(to: fixture.directory.appending(path: ".git/info/exclude"))
        _ = try await runner.run(["init", "--bare", bare])
        _ = try await runner.run(["remote", "add", "origin", bare])

        try await branchAndTag(branch, in: fixture)

        // 首次发布建立上游，另一个工作区随后在远端分支上追加一个提交
        _ = try await sync.push(branch: branch, remote: "origin", destination: branch, setUpstream: true)
        try await pushFromOtherWorkspace(bare: bare, branch: branch, in: fixture)

        let rebased = try await rebasePull(branch, in: fixture)
        _ = try await sync.push(branch: branch, remote: "origin", destination: branch, setUpstream: false)

        let rewrittenAgain = try await forcePush(branch, lease: rebased, bare: bare, in: fixture)

        // 从分支的 Reflog 找回改写前的提交，把分支恢复过去
        let reflog = RepositoryReflog(runner: runner)
        let entries = try await reflog.page(of: "refs/heads/" + branch).entries
        #expect(entries.first?.commit.id == rewrittenAgain)
        #expect(entries.contains { $0.commit.id == rebased })

        try await reflog.restore("refs/heads/" + branch, to: rebased, expected: rewrittenAgain)
        #expect(try await RepositoryReferences(runner: runner).resolve("refs/heads/" + branch) == rebased)
    }
}

// MARK: - Steps

extension RecoveryWorkflowTests {
    /// 根提交之后从 HEAD 新建并检出分支，提交一次并打上带说明的标签。
    private func branchAndTag(_ branch: String, in fixture: TemporaryRepository) async throws {
        let working = WorkingCopyOperations(runner: fixture.runner)
        let references = RepositoryReferences(runner: fixture.runner)

        try write("base\n", to: "说明 [v1].txt", in: fixture)
        try await working.stageAll(staged: true)
        try await working.commit(subject: "根提交", body: "")
        try await references.create(name: branch, startingAt: "HEAD", track: false, checkout: true)

        try write("feature\n", to: "feature.txt", in: fixture)
        try await working.stageAll(staged: true)
        try await working.commit(subject: "功能", body: "")
        let tagged = try await references.resolve("HEAD")

        try await RepositoryTags(runner: fixture.runner)
            .create(name: "v1.0", revision: "HEAD", message: "发布 1.0", sign: false)

        #expect(try await references.resolve("refs/tags/v1.0") == tagged)
    }

    /// 本地也提交一次形成分叉，获取后以变基方式拉取，本地提交排到远端提交之后；返回变基后的提交。
    private func rebasePull(_ branch: String, in fixture: TemporaryRepository) async throws -> String {
        let runner = fixture.runner
        let working = WorkingCopyOperations(runner: runner)
        let references = RepositoryReferences(runner: runner)
        let sync = RepositorySync(runner: runner)

        try write("local\n", to: "local.txt", in: fixture)
        try await working.stageAll(staged: true)
        try await working.commit(subject: "本地", body: "")
        _ = try await sync.fetch(prune: true)
        try await sync.pull(rebase: true)

        let rebased = try await references.resolve("HEAD")
        let fetched = try await references.resolve("refs/remotes/origin/" + branch)
        let output = try await runner.run(["rev-list", "--parents", "-n", "1", rebased])

        let parents = String(decoding: output, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")

        #expect(parents.dropFirst().first.map(String.init) == fetched)
        return rebased
    }

    /// 改写最后一个提交后普通推送被拒，按读到的远端值安全强推成功；再改写一次后，期望值已经过时的强推被拒，
    /// 远端保持上一次强推的提交。返回第二次改写后的提交。
    private func forcePush(
        _ branch: String,
        lease: String,
        bare: String,
        in fixture: TemporaryRepository
    ) async throws -> String {
        let runner = fixture.runner
        let references = RepositoryReferences(runner: runner)
        let sync = RepositorySync(runner: runner)

        _ = try await runner.run(["commit", "--amend", "-q", "-m", "本地（改写）"])
        let rewritten = try await references.resolve("HEAD")

        await #expect(throws: GitError.self) {
            try await sync.push(branch: branch, remote: "origin", destination: branch, setUpstream: false)
        }

        _ = try await sync.push(
            branch: branch,
            remote: "origin",
            destination: branch,
            setUpstream: false,
            lease: lease
        )

        let remoteHead = try await runner.run(["ls-remote", bare, "refs/heads/" + branch])
        #expect(String(decoding: remoteHead, as: UTF8.self).hasPrefix(rewritten))

        // 再改写一次，期望值仍是第一次强推前的远端值
        _ = try await runner.run(["commit", "--amend", "-q", "-m", "本地（再次改写）"])
        let rewrittenAgain = try await references.resolve("HEAD")

        await #expect(throws: GitError.self) {
            try await sync.push(
                branch: branch,
                remote: "origin",
                destination: branch,
                setUpstream: false,
                lease: lease
            )
        }

        let remoteAfterReject = try await runner.run(["ls-remote", bare, "refs/heads/" + branch])
        #expect(String(decoding: remoteAfterReject, as: UTF8.self).hasPrefix(rewritten))

        return rewrittenAgain
    }
}

// MARK: - Helpers

extension RecoveryWorkflowTests {
    /// 在测试仓库根目录写入一个文件。
    private func write(_ content: String, to name: String, in fixture: TemporaryRepository) throws {
        try Data(content.utf8).write(to: fixture.directory.appending(path: name))
    }

    /// 第二个工作区克隆裸仓库的分支，提交一次并推回去，作为别处的更新。
    private func pushFromOtherWorkspace(bare: String, branch: String, in fixture: TemporaryRepository) async throws {
        let otherPath = fixture.directory.appending(path: "other").path
        _ = try await fixture.runner.run(["clone", "-q", "-b", branch, bare, otherPath])

        let other = fixture.runner(at: otherPath)
        _ = try await other.run(["config", "--local", "user.name", "Other"])
        _ = try await other.run(["config", "--local", "user.email", "other@example.invalid"])
        _ = try await other.run(["config", "--local", "commit.gpgSign", "false"])

        try Data("remote\n".utf8).write(to: URL(fileURLWithPath: otherPath).appending(path: "remote.txt"))
        _ = try await other.run(["add", "--all"])
        _ = try await other.run(["commit", "-q", "-m", "别处的更新"])
        _ = try await other.run(["push", "-q", "origin", branch])
    }
}
