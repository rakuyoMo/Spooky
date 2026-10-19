import Foundation
import Testing

@testable import SpookyKit

/// 工作区打开与边界分支的真实 Git 验证。
struct LocalRepositoryTests {
    /// 空仓库必须能打开，并保留尚未出生的分支名。
    @Test("空仓库、未出生分支与无上游")
    func emptyRepository() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        try await temporary.initialize()

        let repository = try await temporary.runner.openLocalRepository()
        let status = try await temporary.runner.status()

        #expect(
            URL(fileURLWithPath: repository.path).resolvingSymlinksInPath()
                == temporary.directory.resolvingSymlinksInPath()
        )
        #expect(status.branch.head == "main")
        #expect(status.branch.oid == nil)
        #expect(status.branch.upstream == nil)
        #expect(status.branch.ahead == 0)
        #expect(status.branch.behind == 0)
        #expect(status.entries.isEmpty)
    }

    /// 子目录与符号链接必须归一到同一仓库，路径中的换行和空格不能被截断。
    @Test("根路径归一与特殊字符")
    func canonicalRoot() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let root = temporary.directory.appendingPathComponent("根目录\n末尾 ")
        let subdirectory = root.appendingPathComponent("子目录")
        let alias = temporary.directory.appendingPathComponent("alias")
        try FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: true)
        _ = try await temporary.runner(at: root.path).run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: subdirectory)

        let opened = try await temporary.runner(at: alias.path).openLocalRepository()
        let direct = try await temporary.runner(at: root.path).openLocalRepository()
        #expect(opened == direct)
        #expect(opened.path.hasSuffix("/根目录\n末尾 "))
    }

    /// 分离 HEAD 仍然能读取状态，哈希长度由仓库格式决定。
    @Test("已提交分支、分离 HEAD 和动态哈希长度", arguments: ["sha1", "sha256"])
    func detachedHead(objectFormat: String) async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        try await temporary.initialize(objectFormat: objectFormat)

        _ = try await temporary.runner.run(["commit", "--allow-empty", "-q", "-m", "initial"])
        let attached = try await temporary.runner.status()
        #expect(attached.branch.head == "main")
        #expect(attached.branch.oid != nil)
        #expect(attached.branch.upstream == nil)

        _ = try await temporary.runner.run(["checkout", "-q", "--detach", "HEAD"])
        let detached = try await temporary.runner.status()
        #expect(detached.branch.head == nil)
        #expect(detached.branch.oid == attached.branch.oid)
        #expect(detached.branch.oid?.count == (objectFormat == "sha1" ? 40 : 64))
        #expect(detached.entries.isEmpty)
    }

    /// 上游计数取自 porcelain 分支头，不解析面向人的提示文字。
    @Test("本机上游的领先落后计数")
    func aheadAndBehind() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        try await temporary.initialize()

        _ = try await temporary.runner.run(["commit", "--allow-empty", "-q", "-m", "base"])
        _ = try await temporary.runner.run(["branch", "upstream"])
        _ = try await temporary.runner.run(["branch", "--set-upstream-to=upstream", "main"])
        _ = try await temporary.runner.run(["commit", "--allow-empty", "-q", "-m", "main advance"])
        _ = try await temporary.runner.run(["checkout", "-q", "upstream"])
        _ = try await temporary.runner.run(["commit", "--allow-empty", "-q", "-m", "upstream advance"])
        _ = try await temporary.runner.run(["checkout", "-q", "main"])

        let status = try await temporary.runner.status()
        #expect(status.branch.upstream == "upstream")
        #expect(status.branch.ahead == 1)
        #expect(status.branch.behind == 1)
    }

    /// 非仓库、缺失路径和裸仓库分别报错，stderr 保留用于恢复判断。
    @Test("打开失败保留原始错误")
    func invalidLocations() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let notRepository = await #expect(throws: GitError.self) {
            try await temporary.runner.openLocalRepository()
        }
        #expect(notRepository?.category == .notRepository)
        #expect(notRepository?.exitCode == 128)
        #expect(notRepository?.message.contains("not a git repository") == true)

        let missing = await #expect(throws: GitError.self) {
            try await temporary.runner(at: temporary.directory.appending(path: "missing").path)
                .openLocalRepository()
        }
        #expect(missing?.category == .pathUnavailable)
        #expect(missing?.message.contains("cannot change to") == true)

        _ = try await temporary.runner.run(["-c", "init.templateDir=", "init", "--bare", "-q"])
        let bare = await #expect(throws: GitError.self) {
            try await temporary.runner.openLocalRepository()
        }
        #expect(bare?.category == .notWorkingTree)
        #expect(bare?.message.isEmpty == false)
    }

    /// 版本不足在路径验证之前报出，保留版本 stdout 与 stderr。
    @Test("低版本 Git 先于路径错误")
    func minimumVersionBeforePath() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let executable = temporary.directory.appending(path: "version-git")
        try Data("#!/bin/sh\nprintf 'git version 2.40.9 (Apple Git-100)\\n'\nprintf 'version diagnostic\\n' >&2\n".utf8)
            .write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let error = await #expect(throws: RepositoryOpenError.self) {
            try await temporary.runner(at: "/missing-\(UUID())", executable: executable.path)
                .openLocalRepository()
        }

        guard case .unsupportedGitVersion(let result) = error else {
            Issue.record("应先报告 Git 版本不足")
            return
        }

        #expect(result.arguments == ["--version"])
        #expect(String(decoding: result.standardOutput, as: UTF8.self).contains("2.40.9"))
        #expect(String(decoding: result.standardError, as: UTF8.self) == "version diagnostic\n")
    }

    /// Apple 后缀、两位次版本与格式错误不会误判最低版本。
    @Test("Git 版本解析与数值比较")
    func versionParsing() throws {
        let supported = try #require(GitVersion(output: Data("git version 2.41.0 (Apple Git-200)\n".utf8)))
        let old = try #require(GitVersion(output: Data("git version 2.9.9\n".utf8)))
        #expect(supported == .minimum)
        #expect(old < .minimum)
        #expect(GitVersion(output: Data("2.99.0".utf8)) == nil)
        #expect(GitVersion(output: Data("git version 2.41.0bad".utf8)) == nil)
    }
}
