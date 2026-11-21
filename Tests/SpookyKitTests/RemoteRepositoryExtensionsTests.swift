import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteRepositoryExtensionsTests

/// 服务器仓库的子模块、工作树与 Git LFS：克隆、检出与传输都由 B 上的 Git 完成，路径都是 B 上的绝对路径。
///
/// 仅在显式启用时访问测试专用仓库；每项测试结束时关掉自己的连接、删掉自己的目录。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteRepositoryExtensionsTests {
    /// 子模块在 B 上添加、提交后去掉初始化再更新、改地址后同步；子模块里有未跟踪文件时不强制就不删，强制删除后 B 上的目录随之删掉。
    @Test("服务器上的子模块：添加、更新、同步与删除")
    func submodules() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection(configuration: Self.submoduleConfiguration(in: fixture))

        do {
            _ = try await RemoteFixture.raw([
                "git", "config", "--file", fixture.root + "/全局.gitconfig", "protocol.file.allow", "always",
            ])

            let runner = GitRunner(location: try await remote.open().location, remote: remote)
            let submodules = RepositorySubmodules(runner: runner)
            let upstream = fixture.root + "/上游 lib"
            let head = try await Self.makeUpstream(at: upstream)
            let path = "依赖/my lib"

            _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "父仓库"])
            try await submodules.add(url: upstream, path: path, reusesGitDirectory: false)

            var submodule = try #require(try await submodules.list().first)
            #expect(submodule.path == path && submodule.state == .clean)
            #expect(submodule.pointer == head && submodule.checkedOut == head)

            // 提交后去掉初始化：没有检出；更新时由 B 上的 Git 初始化并检出指针所指的提交
            _ = try await runner.run(["commit", "-q", "-m", "添加子模块"])
            _ = try await runner.run(["submodule", "deinit", "-q", "-f", "--", path])

            submodule = try #require(try await submodules.list().first)
            #expect(submodule.state == .uninitialized && submodule.checkedOut == nil)

            try await submodules.update([submodule], recursive: true)

            submodule = try #require(try await submodules.list().first)
            #expect(submodule.state == .clean && submodule.checkedOut == head)

            // .gitmodules 的地址改了才提示同步，同步后子模块仓库的远端随之改写
            try await submodules.setURL(upstream + "/", for: submodule, in: .shared)
            submodule = try #require(try await submodules.list().first)
            #expect(submodule.needsSynchronizing)

            try await submodules.synchronize([submodule])
            submodule = try #require(try await submodules.list().first)
            #expect(!submodule.needsSynchronizing)
            #expect(try await submodules.remoteURL(of: submodule) == upstream + "/")

            // 修改地址不暂存 .gitmodules，删除前先暂存，否则 Git 拒绝删除
            _ = try await runner.run(["add", ".gitmodules"])

            // 未跟踪文件写在 B 上的子模块里
            try await RepositoryFiles(runner: runner)
                .write(Data("x\n".utf8), to: fixture.repository + "/" + path + "/新 文件.txt")

            await #expect(throws: SubmoduleError.localModifications) {
                try await submodules.delete(submodule, keepsWorkingTree: false, force: false)
            }

            try await submodules.delete(submodule, keepsWorkingTree: false, force: true)
            #expect(try await submodules.list().isEmpty)
            _ = try await RemoteFixture.raw(["/bin/test", "!", "-e", fixture.repository + "/" + path])

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 工作树在 B 上新建、移动与删除；在 B 上直接挪走的工作树失效，选中的目录先核对再修复。
    @Test("服务器上的工作树：新建、清单、移动、失效与修复、删除")
    func worktrees() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let runner = GitRunner(location: try await remote.open().location, remote: remote)
            let worktrees = RepositoryWorktrees(runner: runner)
            let added = fixture.root + "/工作 树 [*]"
            let moved = fixture.root + "/移 走"
            let manual = fixture.root + "/手 动"

            _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "first"])
            _ = try await runner.run(["branch", "feature"])
            try await worktrees.add(at: added, revision: "feature", detach: false, force: false)

            var list = try await worktrees.list()
            #expect(list.map(\.path) == [fixture.repository, added])
            #expect(list.first?.isCurrent ?? false)
            #expect(list.last?.branchName == "feature")

            try await worktrees.move(try #require(list.last), to: moved)
            list = try await worktrees.list()
            #expect(list.last?.path == moved)
            #expect(list.last?.isValid ?? false)

            // 绕过 Git 在 B 上挪走目录
            _ = try await RemoteFixture.raw(["/bin/mv", moved, manual])

            let stale = try #require(try await worktrees.list().last)
            #expect(!stale.isValid)

            await #expect(throws: WorktreeRepairProblem.directoryMissing) {
                try await worktrees.validateRepair(of: stale, at: fixture.root + "/不存在")
            }

            try await worktrees.validateRepair(of: stale, at: manual)
            try await worktrees.repair(at: manual)

            let repaired = try #require(try await worktrees.list().last)
            #expect(repaired.path == manual && repaired.isValid)

            try await worktrees.remove(repaired, force: false)
            #expect(try await worktrees.list().map(\.path) == [fixture.repository])
            _ = try await RemoteFixture.raw(["/bin/test", "!", "-e", manual])

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }

    /// B 的 PATH 里没有 git-lfs 时报出能力缺失；PATH 里有 git-lfs 时（与在 B 上修好 PATH 之后相同），
    /// 启用、跟踪、推送、获取与拉取都由 B 上的 Git LFS 完成，传输进度传回 A。
    ///
    /// 两种情形各用一个仓库：同一仓库的连接共用 B 上的会话，命令沿用会话建立时的环境。
    /// 仓库路径里不放通配符：git-lfs 推送时把仓库路径当成匹配模式，遇到 `[` 报出语法错误。
    @Test("服务器上的 Git LFS：找不到时报出能力缺失，找得到时启用、跟踪、推送、获取与拉取")
    func lfs() async throws {
        let fixture = try await RemoteFixture.create()

        do {
            try await Self.lfsMissing(in: fixture)
            try await Self.lfsTransfer(in: fixture, directory: try await RemoteFixture.lfsDirectory())
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            try await fixture.remove()
            throw error
        }
    }
}

// MARK: - Steps

extension RemoteRepositoryExtensionsTests {
    /// 允许 B 上的子模块经 file 协议克隆的测试配置：Git 默认不许子模块使用本机路径的地址。
    ///
    /// 放行写在测试目录里的全局配置文件中：B 上的包装器会清掉 `GIT_CONFIG_COUNT` 一类的环境变量。
    private static func submoduleConfiguration(in fixture: RemoteFixture) -> SSHConfiguration {
        var configuration = RemoteFixture.configuration
        configuration.remoteEnvironment["GIT_CONFIG_GLOBAL"] = fixture.root + "/全局.gitconfig"
        return configuration
    }

    /// 找不到 git-lfs：状态里没有版本，写操作带着 `git lfs version` 的结果报出能力缺失，仓库里没有 `.gitattributes`。
    private static func lfsMissing(in fixture: RemoteFixture) async throws {
        let path = fixture.root + "/没有 LFS"
        try await RemoteFixture.initializeRepository(at: path)

        let connection = RemoteConnection(
            host: "spooky-test",
            path: path,
            configuration: RemoteFixture.lfsConfiguration(searchPath: "/usr/bin:/bin")
        )

        do {
            let runner = GitRunner(location: try await connection.open().location, remote: connection)
            let lfs = RepositoryLFS(runner: runner)

            let status = try await lfs.status()
            #expect(status.version == nil && !status.isSupported && !status.isEnabled)

            let error = await #expect(throws: LFSError.self) {
                try await lfs.track(["*.bin"])
            }

            if case .unavailable(let result) = error {
                #expect(result.exitCode == 1)
            } else {
                Issue.record("应报出能力缺失")
            }

            _ = try await RemoteFixture.raw(["/bin/test", "!", "-e", path + "/.gitattributes"])

            await connection.close()
        } catch {
            await connection.close()
            throw error
        }
    }

    /// 启用并跟踪后提交 LFS 文件；只推送引用时裸仓库里没有 LFS 对象，推送 LFS 后有了；
    /// B 上没有过滤器的克隆只检出指针，获取只下载对象，拉取把指针换成内容。
    private static func lfsTransfer(in fixture: RemoteFixture, directory: String) async throws {
        let configuration = RemoteFixture.lfsConfiguration(searchPath: directory + ":/usr/bin:/bin")
        let repository = fixture.root + "/LFS 仓库"
        let path = fixture.root + "/克 隆"
        try await RemoteFixture.initializeRepository(at: repository)

        let remote = RemoteConnection(host: "spooky-test", path: repository, configuration: configuration)
        let clone = RemoteConnection(host: "spooky-test", path: path, configuration: configuration)

        do {
            let runner = GitRunner(location: try await remote.open().location, remote: remote)
            let lfs = RepositoryLFS(runner: runner)
            let origin = fixture.root + "/远 端.git"
            let content = Data((0 ..< 4096).map { UInt8(truncatingIfNeeded: $0 &* 31) })

            try await lfs.install()
            #expect(try await lfs.status().isEnabled)

            try await lfs.track(files: ["大 文件.bin"])
            try await RepositoryFiles(runner: runner).write(content, to: repository + "/大 文件.bin")
            _ = try await runner.run(["add", "--all"])
            _ = try await runner.run(["commit", "-q", "-m", "LFS"])

            _ = try await RemoteFixture.raw([
                "git", "-c", "init.templateDir=", "init", "-q", "--bare", "-b", "main", origin,
            ])

            _ = try await runner.run(["remote", "add", "origin", origin])
            _ = try await runner.run(["push", "--no-verify", "-q", "origin", "main"])
            #expect(try await RemoteFixture.fileCount(in: origin + "/lfs/objects") == 0)

            let pushed = OutputLog()
            try await lfs.push(to: "origin", onOutput: pushed.append)
            #expect(try await RemoteFixture.fileCount(in: origin + "/lfs/objects") == 1)
            #expect(pushed.text.contains("Uploading LFS objects") && pushed.text.contains("(0/1)"))

            // B 上的测试环境没有全局过滤器，克隆只检出指针文件
            _ = try await RemoteFixture.raw(["git", "clone", "-q", "--", origin, path])

            let cloneRunner = GitRunner(location: try await clone.open().location, remote: clone)
            let cloneLFS = RepositoryLFS(runner: cloneRunner)
            let file = path + "/大 文件.bin"
            let read = { try await RepositoryFiles(runner: cloneRunner).read([file])[file] }

            let pointer = try #require(try await read())
            #expect(pointer.starts(with: Data("version https://git-lfs.github.com/spec/v1".utf8)))

            try await cloneLFS.install()
            try await cloneLFS.fetch(from: "origin")
            #expect(try await RemoteFixture.fileCount(in: path + "/.git/lfs/objects") == 1)
            #expect(try await read() == pointer)

            try await cloneLFS.pull(from: "origin")
            #expect(try await read() == content)

            await clone.close()
            await remote.close()
        } catch {
            await clone.close()
            await remote.close()
            throw error
        }
    }

    /// 在 B 上建出有两个空提交的上游仓库，返回最新提交。
    private static func makeUpstream(at path: String) async throws -> String {
        let identity = [
            "-c", "user.name=Spooky Test",
            "-c", "user.email=spooky@example.invalid",
            "-c", "commit.gpgSign=false",
        ]

        _ = try await RemoteFixture.raw(["git", "-c", "init.templateDir=", "init", "-q", "-b", "main", path])

        for message in ["一", "二"] {
            _ = try await RemoteFixture.raw(
                ["git", "-C", path] + identity + ["commit", "-q", "--allow-empty", "-m", message]
            )
        }

        let head = try await RemoteFixture.raw(["git", "-C", path, "rev-parse", "HEAD"])
        return String(decoding: head.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
    }
}

// MARK: - RemoteFixture

extension RemoteFixture {
    /// B 上 git-lfs 所在的目录：先找 B 的非交互 PATH，再找 Homebrew 的两处默认位置；都没有时测试失败。
    static func lfsDirectory() async throws -> String {
        let result = try await raw([
            "/bin/sh", "-c",
            """
            for directory in $(printf '%s' "$PATH" | tr ':' ' ') /opt/homebrew/bin /usr/local/bin; do
                if test -x "$directory/git-lfs"; then printf '%s' "$directory"; exit 0; fi
            done
            """,
        ])

        let directory = String(decoding: result.standardOutput, as: UTF8.self)
        return try #require(
            directory.isEmpty ? nil : directory,
            "B 的 PATH 与 Homebrew 的默认位置里都找不到 git-lfs"
        )
    }

    /// 测试配置换上指定的 PATH；放进 git-lfs 所在的目录，与在 B 上修好非交互 shell 的 PATH 之后相同。
    static func lfsConfiguration(searchPath: String) -> SSHConfiguration {
        var configuration = configuration
        configuration.remoteEnvironment["PATH"] = searchPath
        return configuration
    }

    /// B 上目录里的文件数；目录不存在时为 0。
    static func fileCount(in directory: String) async throws -> Int {
        let result = try await raw([
            "/bin/sh", "-c",
            #"test -d "$1" || { echo 0; exit 0; }; find "$1" -type f | wc -l"#,
            "sh", directory,
        ])

        let count = String(decoding: result.standardOutput, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Int(count) ?? -1
    }
}
