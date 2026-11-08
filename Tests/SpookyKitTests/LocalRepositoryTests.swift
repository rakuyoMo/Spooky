import Foundation
import Testing
import TestSupport

@testable import SpookyKit

/// 工作区打开与边界分支的真实 Git 验证。
struct LocalRepositoryTests {
    /// 空仓库必须能打开并保留尚未出生的分支名；上游计数取自 porcelain 分支头，不解析面向人的提示文字；
    /// 分离 HEAD 仍然能读取状态，哈希长度由仓库格式决定。
    @Test("空仓库、上游的领先落后、分离 HEAD 与哈希长度")
    func branchStates() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        try await temporary.initialize()

        // 空仓库：未出生的分支、没有上游
        let repository = try await temporary.runner.openLocalRepository()
        let empty = try await temporary.runner.status()

        #expect(
            URL(fileURLWithPath: repository.path).resolvingSymlinksInPath()
                == temporary.directory.resolvingSymlinksInPath()
        )

        #expect(empty.branch.head == "main")
        #expect(empty.branch.oid == nil)
        #expect(empty.branch.upstream == nil)
        #expect(empty.branch.ahead == 0 && empty.branch.behind == 0)
        #expect(empty.entries.isEmpty)

        // 本机上游与 main 各前进一个提交
        for arguments in [
            ["commit", "--allow-empty", "-q", "-m", "base"],
            ["branch", "upstream"],
            ["branch", "--set-upstream-to=upstream", "main"],
            ["commit", "--allow-empty", "-q", "-m", "main advance"],
            ["checkout", "-q", "upstream"],
            ["commit", "--allow-empty", "-q", "-m", "upstream advance"],
            ["checkout", "-q", "main"],
        ] {
            _ = try await temporary.runner.run(arguments)
        }

        let attached = try await temporary.runner.status()

        #expect(attached.branch.upstream == "upstream")
        #expect(attached.branch.ahead == 1 && attached.branch.behind == 1)

        // 分离 HEAD
        _ = try await temporary.runner.run(["checkout", "-q", "--detach", "HEAD"])

        let detached = try await temporary.runner.status()

        #expect(detached.branch.head == nil)
        #expect(detached.branch.oid == attached.branch.oid)
        #expect(detached.branch.oid?.count == 40)
        #expect(detached.entries.isEmpty)

        // SHA-256 仓库的哈希长度
        let sha256 = try TemporaryRepository()
        defer { sha256.remove() }

        try await sha256.initialize(objectFormat: "sha256")
        _ = try await sha256.runner.run(["commit", "--allow-empty", "-q", "-m", "initial"])
        _ = try await sha256.runner.run(["checkout", "-q", "--detach", "HEAD"])

        let long = try await sha256.runner.status()

        #expect(long.branch.head == nil)
        #expect(long.branch.oid?.count == 64)
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
        try await RepositoryTemplate.create(at: root)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: subdirectory)

        let opened = try await temporary.runner(at: alias.path).openLocalRepository()
        let direct = try await temporary.runner(at: root.path).openLocalRepository()

        #expect(opened == direct)
        #expect(opened.path.hasSuffix("/根目录\n末尾 "))
    }

    /// 非仓库、缺失路径和裸仓库分别报错，stderr 保留用于恢复判断；版本不足在路径验证之前报出，保留版本 stdout 与 stderr；
    /// Apple 后缀、两位次版本与格式错误不会误判最低版本。
    @Test("打开失败保留原始错误，Git 版本先于路径检查")
    func openFailures() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        // 非仓库
        let notRepository = await #expect(throws: GitError.self) {
            try await temporary.runner.openLocalRepository()
        }

        #expect(notRepository?.category == .notRepository)
        #expect(notRepository?.exitCode == 128)
        #expect(notRepository?.message.contains("not a git repository") ?? false)

        // 缺失路径
        let missing = await #expect(throws: GitError.self) {
            try await temporary.runner(at: temporary.directory.appending(path: "missing").path)
                .openLocalRepository()
        }

        #expect(missing?.category == .pathUnavailable)
        #expect(missing?.exitCode == 128)
        #expect(missing?.message.contains("cannot change to") ?? false)

        // 低版本 Git 指向不存在的路径时，先报告版本不足
        let executable = temporary.directory.appending(path: "version-git")

        try Data("#!/bin/sh\nprintf 'git version 2.40.9 (Apple Git-100)\\n'\nprintf 'version diagnostic\\n' >&2\n".utf8)
            .write(to: executable)

        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let unsupported = await #expect(throws: RepositoryOpenError.self) {
            try await temporary.runner(at: "/missing-\(UUID())", executable: executable.path)
                .openLocalRepository()
        }

        guard case .unsupportedGitVersion(let result) = unsupported else {
            Issue.record("应先报告 Git 版本不足")
            return
        }

        #expect(result.arguments == ["--version"])
        #expect(String(decoding: result.standardOutput, as: UTF8.self).contains("2.40.9"))
        #expect(String(decoding: result.standardError, as: UTF8.self) == "version diagnostic\n")

        // 版本解析
        let supported = try #require(GitVersion(output: Data("git version 2.41.0 (Apple Git-200)\n".utf8)))
        let old = try #require(GitVersion(output: Data("git version 2.9.9\n".utf8)))

        #expect(supported == .minimum)
        #expect(old < .minimum)
        #expect(GitVersion(output: Data("2.99.0".utf8)) == nil)
        #expect(GitVersion(output: Data("git version 2.41.0bad".utf8)) == nil)

        // 裸仓库
        _ = try await temporary.runner.run(["-c", "init.templateDir=", "init", "--bare", "-q"])

        let bare = await #expect(throws: GitError.self) {
            try await temporary.runner.openLocalRepository()
        }

        #expect(bare?.category == .notWorkingTree)
        #expect(!(bare?.message.isEmpty ?? true))
    }
}
