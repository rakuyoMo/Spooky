import Foundation
import Synchronization
import Testing

@testable import SpookyKit

// MARK: - StepRecorder

/// 记下同步依次开始的步骤，供断言执行顺序与停下的位置。
private final class StepRecorder: Sendable {
    /// 已开始的步骤。
    private let steps = Mutex<[SyncStep]>([])

    /// 至今开始过的步骤，按开始顺序。
    var recorded: [SyncStep] { steps.withLock { $0 } }

    /// 记下一个开始的步骤。
    func append(_ step: SyncStep) {
        steps.withLock { $0.append(step) }
    }

    /// 清空记录，准备观察下一次同步。
    func reset() {
        steps.withLock { $0 = [] }
    }
}

// MARK: - SyncFixture

/// 一个本地工作区、一个裸远端，以及另一个模拟别人推送的克隆；都在临时目录里。
private struct SyncFixture {
    /// 本地工作区与它的隔离执行器。
    let repository: TemporaryRepository

    /// 裸远端的路径。
    let bare: String

    /// 模拟别人推送的克隆。
    let other: GitRunner

    /// 本地工作区的执行器。
    var runner: GitRunner { repository.runner }

    /// 本地工作区的同步服务。
    var sync: RepositorySync { RepositorySync(runner: runner) }

    /// 初始化本地仓库、发布 `main` 并克隆出另一个工作区。
    static func make(objectFormat: String = "sha1") async throws -> Self {
        let repository = try TemporaryRepository()
        try await repository.initialize(objectFormat: objectFormat)
        let runner = repository.runner
        let bare = repository.directory.appendingPathComponent("remote.git").path
        let otherPath = repository.directory.appendingPathComponent("other").path

        // 远端与另一个克隆都放在工作区目录里，排除后不影响工作区状态
        try FileManager.default.createDirectory(
            at: repository.directory.appendingPathComponent(".git/info"),
            withIntermediateDirectories: true
        )
        try Data("remote.git/\nother/\nlibrary/\n".utf8)
            .write(to: repository.directory.appendingPathComponent(".git/info/exclude"))

        _ = try await runner.run(["init", "--bare", "--object-format=" + objectFormat, bare])
        _ = try await runner.run(["remote", "add", "origin", bare])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])

        _ = try await RepositorySync(runner: runner)
            .push(branch: "main", remote: "origin", destination: "main", setUpstream: true)

        _ = try await runner.run(["clone", "-q", "-b", "main", bare, otherPath])
        let other = repository.runner(at: otherPath)
        _ = try await other.run(["config", "--local", "user.name", "Other"])
        _ = try await other.run(["config", "--local", "user.email", "other@example.invalid"])
        _ = try await other.run(["config", "--local", "commit.gpgSign", "false"])

        return Self(repository: repository, bare: bare, other: other)
    }

    /// 另一个克隆先跟上远端，再提交并推送一次，模拟远端有了新提交。
    func pushFromOther(_ message: String) async throws {
        _ = try await other.run(["fetch", "-q", "origin"])
        _ = try await other.run(["reset", "-q", "--hard", "origin/main"])
        _ = try await other.run(["commit", "--allow-empty", "-m", message])
        _ = try await other.run(["push", "-q", "origin", "HEAD:main"])
    }

    /// 读取裸远端上某个引用指向的提交。
    func remoteObject(_ reference: String) async throws -> String {
        let output = try await repository.runner(at: bare).run(["rev-parse", "--verify", reference])
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
    }

    /// 本地工作区里某个版本指向的提交。
    func localObject(_ revision: String) async throws -> String {
        try await RepositoryReferences(runner: runner).resolve(revision)
    }

    /// 本地 `main` 对 `origin/main` 的强推核对。
    func previewMain() async throws -> ForcePushPreview {
        try await sync.forcePushPreview(branch: "refs/heads/main", destination: "refs/remotes/origin/main")
    }

    /// 把本地 `main` 推到远端 `main`，可带推送选项与强推期望值。
    @discardableResult
    func pushMain(
        options: PushOptions = PushOptions(),
        lease: String? = nil
    ) async throws -> [RemoteReferenceUpdate] {
        try await sync.push(
            branch: "main",
            remote: "origin",
            destination: "main",
            setUpstream: false,
            options: options,
            lease: lease
        )
    }

    /// 同步本地 `main` 与远端 `main`，把每一步记进 `steps`。
    func syncMain(options: SyncOptions = SyncOptions(), steps: StepRecorder) async throws {
        try await sync.sync(remote: "origin", branch: "refs/heads/main", options: options) { step in
            steps.append(step)
        }
    }
}

// MARK: - Options

extension RepositorySyncTests {
    /// 自动获取与获取全部远端都按 Git 的 skipFetchAll 跳过远端；键里的远端名可以含点。
    @Test("skipFetchAll 的解析")
    func skippedRemotesParsing() throws {
        let records = [
            "remote.origin.skipfetchall\ntrue",
            "remote.my.mirror.skipfetchall",
            "remote.备份 远端.skipfetchall\nyes",
            "remote.later.skipfetchall\ntrue",
            "remote.later.skipfetchall\nfalse",
        ]
        let data = Data(records.joined(separator: "\u{0}").utf8) + Data([0])

        #expect(try RepositorySync.skippedRemotes(in: data) == ["origin", "my.mirror", "备份 远端"])
        #expect(try RepositorySync.skippedRemotes(in: Data()).isEmpty)

        #expect(throws: RepositoryReadError.self) {
            try RepositorySync.skippedRemotes(in: Data("branch.main.remote\norigin\u{0}".utf8))
        }
    }

    /// 获取全部远端时跳过设了 skipFetchAll 的远端，明确选中它时照常获取；清理与标签按选项写入。
    @Test("Fetch 跳过远端、清理已删除分支与获取标签")
    func fetchSkipsAndPrunes() async throws {
        let fixture = try await SyncFixture.make()
        defer { fixture.repository.remove() }
        let runner = fixture.runner
        let sync = fixture.sync

        _ = try await runner.run(["remote", "add", "mirror.backup", fixture.bare])
        _ = try await runner.run(["config", "--local", "remote.mirror.backup.skipFetchAll", "true"])
        _ = try await fixture.other.run(["push", "-q", "origin", "HEAD:refs/heads/gone"])
        _ = try await fixture.other.run(["tag", "v1"])
        _ = try await fixture.other.run(["push", "-q", "origin", "v1"])

        let all = try await sync.fetch(submodules: true)
        #expect(all.allSatisfy { !$0.reference.hasPrefix("refs/remotes/mirror.backup/") })
        #expect(all.contains { $0.reference == "refs/remotes/origin/gone" })

        let explicit = try await sync.fetch(remote: "mirror.backup", allTags: true)
        #expect(explicit.contains { $0.reference == "refs/remotes/mirror.backup/main" })
        _ = try await fixture.localObject("refs/tags/v1")

        _ = try await fixture.other.run(["push", "-q", "origin", ":refs/heads/gone"])
        let pruned = try await sync.fetch(remote: "origin", prune: true)
        #expect(pruned.contains { $0.flag == "-" && $0.reference == "refs/remotes/origin/gone" })

        await #expect(throws: RepositorySyncError.missingRemote) {
            _ = try await sync.fetch(remote: "missing")
        }
    }

    /// 递归子模块时，仓库本身获取完之后再获取每个已检出子模块的远端。
    @Test("Fetch 递归子模块")
    func fetchSubmodules() async throws {
        let fixture = try await SyncFixture.make()
        defer { fixture.repository.remove() }
        let runner = fixture.runner
        let directory = fixture.repository.directory
        let library = directory.appendingPathComponent("library").path
        let upstream = fixture.repository.runner(at: library)

        _ = try await runner.run(["init", "-q", "-b", "main", library])
        _ = try await upstream.run(["config", "--local", "user.name", "Library"])
        _ = try await upstream.run(["config", "--local", "user.email", "library@example.invalid"])
        _ = try await upstream.run(["commit", "-q", "--allow-empty", "-m", "first"])

        _ = try await runner.run([
            "-c", "protocol.file.allow=always",
            "submodule", "add", "-q", library, "子模块 lib",
        ])
        _ = try await runner.run(["commit", "-q", "-m", "add submodule"])
        _ = try await upstream.run(["commit", "-q", "--allow-empty", "-m", "second"])

        let submodule = fixture.repository.runner(at: directory.appendingPathComponent("子模块 lib").path)
        let latest = try await RepositoryReferences(runner: upstream).resolve("HEAD")

        // 测试里的子模块远端是本机目录，Git 默认只允许用户直接发起的 file 传输
        _ = try await submodule.run(["config", "--local", "protocol.file.allow", "always"])

        _ = try await fixture.sync.fetch(remote: "origin", submodules: true)

        let fetched = try await RepositoryReferences(runner: submodule).resolve("refs/remotes/origin/main")
        #expect(fetched == latest)
    }

    /// 变基拉取不受仓库里 pull.rebase=false 影响，结果是线性历史。
    @Test("Pull 显式变基")
    func pullRebase() async throws {
        let fixture = try await SyncFixture.make()
        defer { fixture.repository.remove() }
        let runner = fixture.runner

        _ = try await runner.run(["config", "--local", "pull.rebase", "false"])
        try await fixture.pushFromOther("remote")
        _ = try await runner.run(["commit", "--allow-empty", "-m", "local"])

        try await fixture.sync.pull(rebase: true)

        let parents = try await runner.run(["rev-list", "--parents", "-n", "1", "HEAD"])
        #expect(String(decoding: parents, as: UTF8.self).split(separator: " ").count == 2)
        #expect(try await runner.status().branch.behind == 0)
    }

    /// 推送全部标签与子模块检查都写进参数；没有子模块时检查直接通过。
    @Test("Push 全部标签与子模块选项")
    func pushOptions() async throws {
        let fixture = try await SyncFixture.make()
        defer { fixture.repository.remove() }
        let runner = fixture.runner

        _ = try await runner.run(["commit", "--allow-empty", "-m", "tagged"])
        _ = try await runner.run(["tag", "-a", "-m", "发布", "v1.0"])

        var options = PushOptions()
        options.allTags = true
        options.submodules = .check

        let updates = try await fixture.pushMain(options: options)
        #expect(updates.contains { $0.reference == "refs/tags/v1.0" && $0.flag == "*" })

        let tagged = try await fixture.remoteObject("refs/tags/v1.0^{commit}")
        #expect(try await tagged == fixture.localObject("HEAD"))
    }
}

// MARK: - Force Push

extension RepositorySyncTests {
    /// 远端有本地从未见过的提交时提示个数；陈旧的期望值被拒绝，核对过的期望值才能覆盖。
    @Test("安全强推的状态与租约", arguments: ["sha1", "sha256"])
    func forcePushLease(objectFormat: String) async throws {
        let fixture = try await SyncFixture.make(objectFormat: objectFormat)
        defer { fixture.repository.remove() }
        let runner = fixture.runner

        _ = try await runner.run(["commit", "--allow-empty", "-m", "pushed"])
        try await fixture.pushMain()
        let pushed = try await fixture.localObject("HEAD")

        // 改写已推送的提交，远端仍是改写前的版本
        _ = try await runner.run(["commit", "--amend", "--allow-empty", "-m", "rewritten"])
        let matching = try await fixture.previewMain()
        #expect(matching.status == .matchesLastKnown)
        #expect(matching.introduced == 1 && matching.overwritten == 1)
        #expect(matching.destination == pushed)

        // 别人在改写前的版本上又推了一个提交
        try await fixture.pushFromOther("newer")
        _ = try await fixture.sync.fetch(remote: "origin")
        let newer = try await fixture.previewMain()
        #expect(newer.status == .newerOnRemote(1))
        #expect(newer.overwritten == 2)

        do {
            try await fixture.pushMain(lease: pushed)
            Issue.record("陈旧的期望值必须被拒绝")
        } catch let error as GitError {
            #expect(error.category == .pushRejected)
            #expect(String(decoding: error.result.standardOutput, as: UTF8.self).contains("stale info"))
        }

        #expect(try await fixture.remoteObject("refs/heads/main") == newer.destination)

        try await fixture.pushMain(lease: newer.destination)
        #expect(try await fixture.remoteObject("refs/heads/main") == fixture.localObject("HEAD"))
        #expect(try await fixture.previewMain().status == .sameRevision)

        await #expect(throws: RepositoryReadError.self) {
            try await fixture.pushMain(lease: "HEAD")
        }
    }

    /// 只落后的远端不需要说明；改写后的历史与远端不一致、但远端没有新提交时提示核对。
    @Test("安全强推的另外两种状态")
    func forcePushOtherStates() async throws {
        let fixture = try await SyncFixture.make()
        defer { fixture.repository.remove() }
        let runner = fixture.runner

        _ = try await runner.run(["commit", "--allow-empty", "-m", "ahead"])
        let ahead = try await fixture.previewMain()
        #expect(ahead.status == .fastForward)
        #expect(ahead.introduced == 1 && ahead.overwritten == 0)

        // 推出 A，本地再提交 B 后丢掉 A 与 B，从根提交另起 C：改写前的版本是 B，远端仍是 A
        try await fixture.pushMain()
        _ = try await runner.run(["commit", "--allow-empty", "-m", "unpushed"])
        _ = try await runner.run(["reset", "-q", "--hard", "HEAD~2"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "restarted"])

        let differs = try await fixture.previewMain()
        #expect(differs.status == .differsFromLastKnown)
        #expect(differs.overwritten == 1)

        await #expect(throws: RepositoryReadError.self) {
            _ = try await fixture.sync.forcePushPreview(branch: "main", destination: "origin/main")
        }
    }
}

// MARK: - Push To

extension RepositorySyncTests {
    /// 任意版本推到分支名或完整引用，Gerrit 评审引用原样写入；非法目标在执行前被拒绝。
    @Test("Push To 分支名、Gerrit 评审引用与非法目标")
    func pushToReference() async throws {
        let fixture = try await SyncFixture.make()
        defer { fixture.repository.remove() }
        let sync = fixture.sync
        let review = "refs/for/主分支%topic=测试"

        _ = try await fixture.runner.run(["commit", "--allow-empty", "-m", "review"])

        let updates = try await sync.push(revision: "main", remote: "origin", to: review)
        #expect(updates.contains { $0.reference == review })
        #expect(try await fixture.remoteObject(review) == fixture.localObject("HEAD"))

        _ = try await sync.push(revision: "HEAD~1", remote: "origin", to: "功能/新分支", skipHooks: true)
        #expect(try await fixture.remoteObject("refs/heads/功能/新分支") == fixture.localObject("HEAD~1"))

        await #expect(throws: RepositoryReadError.invalidQuery) {
            _ = try await sync.push(revision: "main", remote: "origin", to: "--force")
        }

        await #expect(throws: GitError.self) {
            _ = try await sync.push(revision: "main", remote: "origin", to: "bad..name")
        }

        await #expect(throws: RepositorySyncError.missingRemote) {
            _ = try await sync.push(revision: "main", remote: "missing", to: "main")
        }

        await #expect(throws: GitError.self) {
            _ = try await sync.push(revision: "no-such-revision", remote: "origin", to: "main")
        }
    }
}

// MARK: - Rebase & Sync

extension RepositorySyncTests {
    /// 变基到另一个分支得到线性历史；工作区不干净时不开始，冲突时留下进行中的变基。
    @Test("Rebase 当前分支")
    func rebaseCurrentBranch() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize()
        let runner = fixture.runner
        let sync = RepositorySync(runner: runner)
        let file = fixture.directory.appendingPathComponent("文件 [1].txt")

        try Data("base\n".utf8).write(to: file)
        _ = try await runner.run(["add", "--", file.lastPathComponent])
        _ = try await runner.run(["commit", "-q", "-m", "base"])
        _ = try await runner.run(["switch", "-q", "-c", "topic"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "topic"])
        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "main"])
        _ = try await runner.run(["switch", "-q", "topic"])

        try await sync.rebase(onto: "main")
        #expect(try await runner.run(["merge-base", "--is-ancestor", "main", "topic"]).isEmpty)

        try Data("dirty\n".utf8).write(to: file)

        await #expect(throws: RepositorySyncError.dirtyWorkingCopy) {
            try await sync.rebase(onto: "main")
        }

        _ = try await runner.run(["commit", "-q", "-am", "topic change"])
        _ = try await runner.run(["switch", "-q", "main"])
        try Data("main\n".utf8).write(to: file)
        _ = try await runner.run(["commit", "-q", "-am", "main change"])
        _ = try await runner.run(["switch", "-q", "topic"])

        await #expect(throws: GitError.self) {
            try await sync.rebase(onto: "main", skipHooks: true)
        }

        #expect(try await WorkingCopyOperations(runner: runner).context(head: nil).operation == .rebase)
    }

    /// 三步依次执行；推送被远端钩子拒绝时停在推送，前两步的结果保留。
    @Test("Sync 的步骤顺序与中途失败")
    func syncSteps() async throws {
        let fixture = try await SyncFixture.make()
        defer { fixture.repository.remove() }
        let runner = fixture.runner
        let steps = StepRecorder()

        try await fixture.pushFromOther("remote")
        _ = try await runner.run(["commit", "--allow-empty", "-m", "local"])

        var options = SyncOptions()
        options.rebase = true

        try await fixture.syncMain(options: options, steps: steps)
        #expect(steps.recorded == [.fetch, .pull, .push])
        #expect(try await fixture.remoteObject("refs/heads/main") == fixture.localObject("HEAD"))

        try await fixture.pushFromOther("again")
        _ = try await runner.run(["commit", "--allow-empty", "-m", "local again"])
        steps.reset()

        // 之后远端的 pre-receive 钩子拒绝一切推送
        let hooks = URL(fileURLWithPath: fixture.bare).appendingPathComponent("hooks")
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)
        let hook = hooks.appendingPathComponent("pre-receive")
        try Data("#!/bin/sh\necho 'rejected by policy' >&2\nexit 1\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)

        do {
            try await fixture.syncMain(steps: steps)
            Issue.record("被拒绝的推送不能报告成功")
        } catch let error as GitError {
            #expect(error.category == .pushRejected)
            #expect(error.message.contains("rejected by policy"))
        }

        #expect(steps.recorded == [.fetch, .pull, .push])
        #expect(try await runner.status().branch.behind == 0)

        try Data("dirty\n".utf8).write(to: fixture.repository.directory.appendingPathComponent("dirty"))
        steps.reset()

        await #expect(throws: RepositorySyncError.dirtyWorkingCopy) {
            try await fixture.syncMain(steps: steps)
        }

        #expect(steps.recorded.isEmpty)
    }

    /// 远端仓库消失时停在获取，本地引用与 HEAD 都不变。
    @Test("Sync 在网络中断时停在获取并保持本地状态")
    func syncStopsAtFetch() async throws {
        let fixture = try await SyncFixture.make()
        defer { fixture.repository.remove() }
        let steps = StepRecorder()
        let head = try await fixture.localObject("HEAD")
        let tracking = try await fixture.localObject("refs/remotes/origin/main")

        try FileManager.default.removeItem(atPath: fixture.bare)

        do {
            try await fixture.syncMain(steps: steps)
            Issue.record("远端不存在时不能报告成功")
        } catch let error as GitError {
            #expect(error.category == .remoteNotFound)
        }

        #expect(steps.recorded == [.fetch])
        #expect(try await fixture.localObject("HEAD") == head)
        #expect(try await fixture.localObject("refs/remotes/origin/main") == tracking)
    }
}
