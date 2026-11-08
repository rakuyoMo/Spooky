import Foundation
import Subprocess
import Testing

@testable import SpookyKit

// MARK: - FilePathEnvironmentTests

/// 路径环境覆盖不能扩大只读补丁的范围。
struct FilePathEnvironmentTests {
    /// 四项路径规格环境变量，测试里同时设置，其中字面与通配互相冲突。
    static let pathspecKeys = [
        "GIT_LITERAL_PATHSPECS",
        "GIT_GLOB_PATHSPECS",
        "GIT_NOGLOB_PATHSPECS",
        "GIT_ICASE_PATHSPECS",
    ]

    /// 从进程继承或由用户自定义的全量覆盖都必须被清除，提交详情与两版本比较都只读出所选文件。
    @Test("继承与自定义路径变量不影响精确补丁", arguments: [false, true])
    func pathEnvironment(custom: Bool) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        _ = try await fixture.runner.run(["commit", "--allow-empty", "-qm", "empty base"])
        let base = try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")
        let head = try await caseCommit(fixture)
        let runner = Self.pollutedRunner(path: fixture.directory.path, custom: custom)

        // 提交详情只读出小写的文件
        let history = RepositoryHistory(runner: runner)
        let file = try #require(try await history.changes(in: head).first { $0.path == "case" })
        let diff = try await history.diff(in: head, file: file)
        #expect(diff.diff?.files.count == 1)
        #expect(diff.diff?.files.first?.headers.first == "diff --git a/case b/case")

        // 两版本比较使用自己的查询缓存键，同样不能把大小写不同的文件混进补丁
        let comparison = RevisionComparison(runner: runner, base: base, target: head)
        let comparedFile = try #require(try await comparison.changes().first { $0.path == "case" })
        let compared = try await comparison.diff(of: comparedFile)
        #expect(compared.diff?.files.count == 1)
        #expect(compared.diff?.files.first?.headers.first == "diff --git a/case b/case")
    }

    /// 使用生产远端前缀执行本机 shell，验证四项环境变量的真实清理。
    @Test("SSH 命令前缀隔离路径环境")
    func remotePrefix() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let head = try await caseCommit(fixture)

        // 远端前缀之后的 Git 命令按字面路径列出提交里的文件
        let query = [
            "/usr/bin/git", "-C", fixture.directory.path, "--no-literal-pathspecs",
            "show", "--format=", "--name-only", head,
            "--", ":(top,literal)case", ":(top,exclude,literal)case/",
        ]
        let command = SSHConfiguration().environmentPrefix + query

        var environment: [Environment.Key: String?] = [
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
        ]

        for key in Self.pathspecKeys {
            environment[Environment.Key(stringLiteral: key)] = "1"
        }

        let result = try await CommandExecutor.execute(
            executable: "/bin/sh",
            processArguments: ["-c", command.map(GitRunner.shellQuoted).joined(separator: " ")],
            environment: .inherit.updating(environment)
        )

        #expect(result.exitCode == 0)
        #expect(String(decoding: result.standardOutput, as: UTF8.self) == "case\n")
    }

    /// 直接写入索引，大小写敏感的树不受本机工作区文件系统限制。
    private func caseCommit(_ fixture: TemporaryRepository) async throws -> String {
        let runner = fixture.runner
        let output = try await runner.run(["hash-object", "-w", "--stdin"], input: Data("same\n".utf8))
        let blob = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        _ = try await runner.run(
            ["update-index", "--add", "-z", "--index-info"],
            input: Data("100644 blob \(blob)\tcase\0100644 blob \(blob)\tCASE\0".utf8)
        )
        _ = try await runner.run(["commit", "-qm", "case-sensitive tree"])

        return try await RepositoryReferences(runner: runner).resolve("HEAD")
    }
}

// MARK: - Helpers

extension FilePathEnvironmentTests {
    /// 带着四项路径规格变量的执行器：变量来自进程环境，或来自登录 shell 与自定义变量。
    ///
    /// - Parameters:
    ///   - path: 仓库目录。
    ///   - custom: 为真时变量写进执行设置，否则写进继承的进程环境。
    static func pollutedRunner(path: String, custom: Bool) -> GitRunner {
        let variables = Dictionary(uniqueKeysWithValues: pathspecKeys.map { ($0, "1") })

        var inherited: [Environment.Key: String?] = [
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
        ]

        if !custom {
            for key in pathspecKeys {
                inherited[Environment.Key(stringLiteral: key)] = "1"
            }
        }

        return GitRunner(
            location: .local(path: path),
            settings: LocalExecutionSettings(
                loginShellVariables: custom ? variables : [:],
                customVariables: custom ? variables : [:]
            ),
            environment: .inherit.updating(inherited)
        )
    }
}
