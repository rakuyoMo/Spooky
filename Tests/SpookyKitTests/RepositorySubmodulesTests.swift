import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositorySubmodulesTests

/// 子模块：清单把 `.gitmodules`、本地配置、索引与 `submodule status` 合在一起，配置不完整的子模块同样列出；
/// 增删改移、初始化、更新、同步与修复都在父仓库所在的机器上由 Git 完成。
struct RepositorySubmodulesTests {
    /// 添加后列出一个干净的子模块；子模块里的改动与检出别的提交分别反映在概况与状态里。
    @Test("添加、列出与概况")
    func addListAndSummary() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        try await submodules.add(url: repositories.upstreamPath, path: "依赖/my lib", reusesGitDirectory: false)

        var list = try await submodules.list()
        #expect(list.count == 1)

        let added = try #require(list.first)
        #expect(added.name == "依赖/my lib")
        #expect(added.path == "依赖/my lib")
        #expect(added.isValid && added.isInitialized && !added.needsSynchronizing)
        #expect(added.state == .clean)
        #expect(added.pointer == repositories.upstreamHead)
        #expect(added.checkedOut == repositories.upstreamHead)
        #expect(try await submodules.summary(of: added) == SubmoduleSummary(changes: 0, ahead: 0, behind: 0))

        // 子模块里多一个未跟踪文件、检出上一个提交
        try Data("x\n".utf8).write(to: repositories.parentURL.appending(path: "依赖/my lib/新 文件.txt"))
        _ = try await repositories.parent.run(["-C", "依赖/my lib", "checkout", "-q", "HEAD~1"])

        list = try await submodules.list()
        let updated = try #require(list.first)
        #expect(updated.state == .updated)
        #expect(updated.pointer == repositories.upstreamHead)
        #expect(updated.checkedOut != repositories.upstreamHead)
        #expect(try await submodules.summary(of: updated) == SubmoduleSummary(changes: 1, ahead: 0, behind: 1))

        // 分离 HEAD 时没有当前分支
        let revisions = try await submodules.revisions(of: updated)
        #expect(revisions == [SubmoduleRevision(reference: "refs/heads/main", isCurrent: false)])

        try await submodules.checkout(try #require(revisions.first), in: updated)
        #expect(try await submodules.list().first?.state == .clean)
    }

    /// 相对地址按父仓库的默认远端或工作区路径换算后再比较；`.gitmodules` 的地址改了才提示同步，同步后不再提示。
    @Test("相对地址与同步")
    func relativeURLAndSynchronize() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        try await submodules.add(url: "../上游 lib", path: "lib", reusesGitDirectory: false)

        var submodule = try #require(try await submodules.list().first)
        #expect(submodule.shared?.url == "../上游 lib")
        #expect(submodule.local?.url?.hasSuffix("/上游 lib") ?? false)
        #expect(!submodule.needsSynchronizing)

        try await submodules.setURL(repositories.upstreamPath + "/", for: submodule, in: .shared)
        submodule = try #require(try await submodules.list().first)
        #expect(submodule.needsSynchronizing)

        try await submodules.synchronize([submodule])
        submodule = try #require(try await submodules.list().first)
        #expect(!submodule.needsSynchronizing)
        #expect(try await submodules.remoteURL(of: submodule) == repositories.upstreamPath + "/")
    }

    /// 去掉初始化后状态是未检出；更新时先初始化再检出指针所指的提交。
    @Test("初始化与更新")
    func initializeAndUpdate() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        try await submodules.add(url: repositories.upstreamPath, path: "lib", reusesGitDirectory: false)
        _ = try await repositories.parent.run(["commit", "-q", "-m", "添加子模块"])
        _ = try await repositories.parent.run(["submodule", "deinit", "-q", "-f", "--", "lib"])

        var submodule = try #require(try await submodules.list().first)
        #expect(submodule.state == .uninitialized)
        #expect(!submodule.isInitialized)
        #expect(submodule.checkedOut == nil)
        #expect(submodule.pointer == repositories.upstreamHead)

        try await submodules.initialize([submodule])
        submodule = try #require(try await submodules.list().first)
        #expect(submodule.isInitialized)
        #expect(submodule.state == .uninitialized)

        try await submodules.update([submodule], recursive: true)
        submodule = try #require(try await submodules.list().first)
        #expect(submodule.state == .clean)
        #expect(submodule.checkedOut == repositories.upstreamHead)
    }

    /// 有指针缺少配置、有配置缺少指针时都列出并标出原因，修复后回到完整状态。
    @Test("配置不完整与修复")
    func incompleteAndRepair() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        // 把一个克隆直接加进索引，只有指针没有 .gitmodules 的段
        _ = try await repositories.parent.run(["clone", "-q", repositories.upstreamPath, "内 嵌"])
        _ = try await repositories.parent.run(["add", "内 嵌"])

        var embedded = try #require(try await submodules.list().first)
        #expect(embedded.problem == .missingConfiguration)
        #expect(embedded.name == "内 嵌")

        try await submodules.repair(embedded)
        embedded = try #require(try await submodules.list().first)
        #expect(embedded.isValid && embedded.isInitialized)
        #expect(embedded.shared?.url == repositories.upstreamPath)
        #expect(embedded.state == .clean)

        // 去掉索引里的指针，只剩 .gitmodules 的段
        _ = try await repositories.parent.run(["rm", "-q", "--cached", "--", "内 嵌"])
        embedded = try #require(try await submodules.list().first)
        #expect(embedded.problem == .missingPointer)
        #expect(embedded.pointer == nil)

        try await submodules.repair(embedded)
        embedded = try #require(try await submodules.list().first)
        #expect(embedded.isValid)
        #expect(embedded.pointer == repositories.upstreamHead)
    }

    /// 保留工作区只删配置与指针；不保留时连目录一起删除，子模块里有改动时要求强制。
    @Test("删除")
    func delete() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        try await submodules.add(url: repositories.upstreamPath, path: "保留", reusesGitDirectory: false)
        try await submodules.add(url: repositories.upstreamPath, path: "删除", reusesGitDirectory: false)

        let list = try await submodules.list()
        let kept = try #require(list.first { $0.path == "保留" })
        let removed = try #require(list.first { $0.path == "删除" })

        try await submodules.delete(kept, keepsWorkingTree: true, force: false)
        #expect(FileManager.default.fileExists(atPath: repositories.parentURL.appending(path: "保留/a.txt").path))

        // 子模块里有未跟踪文件时不强制就不删
        try Data("x\n".utf8).write(to: repositories.parentURL.appending(path: "删除/新.txt"))
        await #expect(throws: SubmoduleError.localModifications) {
            try await submodules.delete(removed, keepsWorkingTree: false, force: false)
        }

        try await submodules.delete(removed, keepsWorkingTree: false, force: true)
        #expect(!FileManager.default.fileExists(atPath: repositories.parentURL.appending(path: "删除").path))

        // 两段配置都已删除，保留的目录变成未跟踪的仓库
        #expect(try await submodules.list().isEmpty)
        let local = try await repositories.parent.execute(
            ["config", "--local", "--get-regexp", "^submodule\\."],
            acceptedExitCodes: [0, 1]
        )
        #expect(local.exitCode == 1)
    }

    /// 移动到不存在的目录并把名称改成新路径；改名把 Git 目录搬到新名称下，子模块仍能正常使用；名称被占用时拒绝。
    @Test("移动与改名")
    func moveAndRename() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        try await submodules.add(url: repositories.upstreamPath, path: "lib", reusesGitDirectory: false)
        try await submodules.add(url: repositories.upstreamPath, path: "other", reusesGitDirectory: false)

        var lib = try #require(try await submodules.list().first { $0.path == "lib" })
        try await submodules.move(lib, to: "第三方/新 lib", renamesSubmodule: true)

        lib = try #require(try await submodules.list().first { $0.path == "第三方/新 lib" })
        #expect(lib.name == "第三方/新 lib")
        #expect(lib.state == .clean)
        #expect(lib.isInitialized)

        let gitDirectory = try await repositories.parent.run(
            ["-C", "第三方/新 lib", "rev-parse", "--path-format=absolute", "--git-dir"]
        )
        #expect(String(decoding: gitDirectory, as: UTF8.self).hasSuffix("/.git/modules/第三方/新 lib\n"))

        // .git 文件按 Git 的写法记相对路径
        let gitfile = try String(
            contentsOf: repositories.parentURL.appending(path: "第三方/新 lib/.git"),
            encoding: .utf8
        )
        #expect(gitfile == "gitdir: ../../.git/modules/第三方/新 lib\n")

        await #expect(throws: SubmoduleError.nameInUse("other")) {
            try await submodules.rename(lib, to: "other")
        }

        try await submodules.rename(lib, to: "renamed")
        lib = try #require(try await submodules.list().first { $0.path == "第三方/新 lib" })
        #expect(lib.name == "renamed")
        #expect(lib.state == .clean)
        #expect(try await submodules.summary(of: lib).changes == 0)
    }

    /// 选项写进 `.gitmodules` 或本地配置，本地优先；删除没有设置的选项不报错。
    @Test("选项")
    func options() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        try await submodules.add(url: repositories.upstreamPath, path: "lib", reusesGitDirectory: false)
        var lib = try #require(try await submodules.list().first)
        #expect(lib.fetchMode == nil && lib.ignoreMode == nil && lib.updateStrategy == nil)

        try await submodules.set(.fetchRecurseSubmodules, to: "false", for: lib, in: .shared)
        try await submodules.set(.ignore, to: "dirty", for: lib, in: .shared)
        try await submodules.set(.update, to: "rebase", for: lib, in: .local)
        try await submodules.set(.fetchRecurseSubmodules, to: "on-demand", for: lib, in: .local)

        lib = try #require(try await submodules.list().first)
        #expect(lib.fetchMode == .onDemand)
        #expect(lib.shared?.fetchRecurseSubmodules == "false")
        #expect(lib.ignoreMode == .dirty)
        #expect(lib.updateStrategy == .rebase)

        try await submodules.set(.fetchRecurseSubmodules, to: nil, for: lib, in: .local)
        try await submodules.set(.ignore, to: nil, for: lib, in: .local)

        lib = try #require(try await submodules.list().first)
        #expect(lib.fetchMode == .never)
        #expect(lib.ignoreMode == .dirty)
    }

    /// 重新添加删除过的子模块时父仓库里已有它的 Git 目录：不复用就报出，可以复用，也可以删掉后重新克隆。
    @Test("已有的 Git 目录")
    func existingGitDirectory() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        try await submodules.add(url: repositories.upstreamPath, path: "lib", reusesGitDirectory: false)
        try await submodules.delete(try #require(try await submodules.list().first), keepsWorkingTree: false, force: false)

        await #expect(throws: SubmoduleError.gitDirectoryExists(name: "lib")) {
            try await submodules.add(url: repositories.upstreamPath, path: "lib", reusesGitDirectory: false)
        }

        try await submodules.add(url: repositories.upstreamPath, path: "lib", reusesGitDirectory: true)
        try await submodules.delete(try #require(try await submodules.list().first), keepsWorkingTree: false, force: false)

        try await submodules.removeGitDirectory(named: "lib")
        try await submodules.add(url: repositories.upstreamPath, path: "lib", reusesGitDirectory: false)
        #expect(try await submodules.list().first?.state == .clean)
    }

    /// 本仓库作为子模块时读出父仓库的工作区，不是子模块时为 nil。
    @Test("父仓库")
    func superproject() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        try await RepositorySubmodules(runner: repositories.parent)
            .add(url: repositories.upstreamPath, path: "lib", reusesGitDirectory: false)

        let child = RepositorySubmodules(
            runner: temporary
                .submoduleRunner(at: repositories.parentURL.appending(path: "lib").path)
        )
        let parent = try #require(try await child.superproject())
        #expect(parent.hasSuffix("/父 仓库"))
        #expect(try await RepositorySubmodules(runner: repositories.parent).superproject() == nil)
    }
}

// MARK: - Parsing

extension RepositorySubmodulesTests {
    /// 段名可以含句点，没有值的布尔键算 true，没有段名的键不属于任何子模块，格式错误时抛出。
    @Test("解析子模块配置")
    func parseSettings() throws {
        let output = Data(
            "submodule.recurse\ntrue\0submodule.a.b.path\nlib/a.b\0submodule.a.b.url\n../a\0"
                .appending("submodule.a.b.fetchrecursesubmodules\0submodule.c.ignore\nDirty\0").utf8
        )
        let settings = try RepositorySubmodules.parseSettings(output)

        #expect(settings.map(\.name) == ["a.b", "c"])
        #expect(settings[0].settings == SubmoduleSettings(path: "lib/a.b", url: "../a", fetchRecurseSubmodules: "true"))
        #expect(settings[1].settings.ignore == "Dirty")
        #expect(SubmoduleIgnoreMode(configValue: "Dirty") == .dirty)
        #expect(try RepositorySubmodules.parseSettings(Data()).isEmpty)
        #expect(throws: RepositoryReadError.self) { try RepositorySubmodules.parseSettings(Data("core.bare\n".utf8)) }
    }

    /// 只留下模式为 160000 的指针，冲突中的指针没有提交，路径原样保留。
    @Test("解析子模块指针")
    func parseGitlinks() throws {
        let output = Data(
            "100644 aaaa 0\ta.txt\0160000 bbbb 0\t子 模块/x\0160000 cccc 2\t冲突\0160000 dddd 3\t冲突\0".utf8
        )
        let gitlinks = try RepositorySubmodules.parseGitlinks(output)

        #expect(gitlinks.count == 2)
        #expect(gitlinks["子 模块/x"] == "bbbb")
        #expect(gitlinks["冲突"] == .some(nil))
        #expect(throws: RepositoryReadError.self) { try RepositorySubmodules.parseGitlinks(Data("160000 x 0\0".utf8)) }
    }

    /// 按已知路径切分状态行：路径里的空格、换行与括号不影响切分，提交长度随对象格式变化。
    @Test("解析子模块状态")
    func parseStatus() throws {
        let sha256 = String(repeating: "a", count: 64)
        let output = Data(
            (
                "+\(sha256) 路 径 (x) (heads/main)\n-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 换\n行\n"
                    + "U0000000000000000000000000000000000000000 冲突\n"
            ).utf8
        )
        let records = try RepositorySubmodules.parseStatus(output, paths: ["路 径 (x)", "换\n行", "冲突", "路"])

        #expect(records["路 径 (x)"] == RepositorySubmodules.StatusRecord(state: .updated, commit: sha256))
        #expect(records["换\n行"]?.state == .uninitialized)
        #expect(records["冲突"]?.state == .unmerged)
        #expect(records["路"] == nil)
        #expect(throws: RepositoryReadError.self) {
            try RepositorySubmodules.parseStatus(Data("*abc lib\n".utf8), paths: ["lib"])
        }
        #expect(throws: RepositoryReadError.self) {
            try RepositorySubmodules.parseStatus(Data(" abc other\n".utf8), paths: ["lib"])
        }
    }

    /// 相对地址按 Git 的规则逐级换算：网址与路径按 “/” 去掉一级，scp 写法去到主机时以 “:” 连接。
    @Test("换算相对地址")
    func resolvedURL() {
        #expect(
            RepositorySubmodules
                .resolvedURL("../lib", base: "https://example.com/a/b/super.git") == "https://example.com/a/b/lib"
        )
        #expect(RepositorySubmodules.resolvedURL("./lib/", base: "https://example.com/a/") == "https://example.com/a/lib")
        #expect(RepositorySubmodules.resolvedURL("../../x.git", base: "git@example.com:team/repo.git") == "git@example.com:x.git")
        #expect(RepositorySubmodules.resolvedURL("../lib", base: "/srv/git/super") == "/srv/git/lib")
        #expect(RepositorySubmodules.resolvedURL("../lib", base: "super") == "lib")
        #expect(RepositorySubmodules.resolvedURL("../../lib", base: "super") == nil)
        #expect(RepositorySubmodules.resolvedURL("https://example.com/x", base: "/srv") == "https://example.com/x")
    }

    /// 在子模块里执行的 `-C <路径>` 不影响读写判断与认证用的子命令名，只有 `submodule status` 是读取。
    @Test("子模块命令的调度")
    func scheduling() {
        #expect(RepositoryOperationQueue.isReadOnly(["submodule", "status"]))
        #expect(RepositoryOperationQueue.isReadOnly(["--literal-pathspecs", "submodule", "status", "--", "lib"]))
        #expect(!RepositoryOperationQueue.isReadOnly(["submodule", "update", "--init"]))
        #expect(RepositoryOperationQueue.isReadOnly(["-C", "config", "config", "-z", "--local", "--get-regexp", "x"]))
        #expect(RepositoryOperationQueue.isReadOnly(["-C", "lib", "status", "--porcelain=v2"]))
        #expect(!RepositoryOperationQueue.isReadOnly(["-C", "lib", "checkout", "main"]))
        #expect(RepositoryOperationQueue.command(in: ["-C", "lib", "fetch", "--all"]) == "fetch")
    }
}

// MARK: - SubmoduleRepositories

/// 一个有两个提交的上游仓库与一个有一个提交的父仓库，都在同一个临时目录里。
private struct SubmoduleRepositories {
    /// 上游仓库的绝对路径。
    let upstreamPath: String

    /// 上游仓库最新提交的哈希。
    let upstreamHead: String

    /// 父仓库的位置。
    let parentURL: URL

    /// 父仓库的执行器。
    let parent: GitRunner

    /// 建出两个仓库，提交身份写进各自的本地配置。
    init(_ temporary: TemporaryRepository) async throws {
        let upstreamURL = temporary.directory.appending(path: "上游 lib")
        parentURL = temporary.directory.appending(path: "父 仓库")
        upstreamPath = upstreamURL.path

        let upstream = temporary.submoduleRunner(at: upstreamURL.path)
        parent = temporary.submoduleRunner(at: parentURL.path)

        for (runner, url) in [(upstream, upstreamURL), (parent, parentURL)] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
            _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
            _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
            _ = try await runner.run(["config", "--local", "commit.gpgSign", "false"])
        }

        for (index, content) in ["一\n", "二\n"].enumerated() {
            try Data(content.utf8).write(to: upstreamURL.appending(path: "a.txt"))
            _ = try await upstream.run(["add", "a.txt"])
            _ = try await upstream.run(["commit", "-q", "-m", "第 \(index + 1) 个提交"])
        }

        try Data("父\n".utf8).write(to: parentURL.appending(path: "README"))
        _ = try await parent.run(["add", "README"])
        _ = try await parent.run(["commit", "-q", "-m", "父仓库"])

        upstreamHead = String(decoding: try await upstream.run(["rev-parse", "HEAD"]), as: UTF8.self)
            .trimmingCharacters(in: .newlines)
    }
}

// MARK: - TemporaryRepository

extension TemporaryRepository {
    /// 允许以本机路径克隆子模块的隔离执行器：Git 默认不许子模块经 file 协议克隆。
    func submoduleRunner(at path: String) -> GitRunner {
        GitRunner(
            location: .local(path: path),
            executablePath: "/usr/bin/git",
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_PARAMETERS": nil,
                "GIT_CONFIG_COUNT": "1",
                "GIT_CONFIG_KEY_0": "protocol.file.allow",
                "GIT_CONFIG_VALUE_0": "always",
                "GIT_ATTR_NOSYSTEM": "1",
            ])
        )
    }
}
