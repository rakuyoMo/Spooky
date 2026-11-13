import Foundation
import Testing

@testable import SpookyKit

// MARK: - ReferenceDecorationTests

/// 历史行的引用标记按 Git 完整 decoration 的顺序排列，并随引用的移动、改名与删除跟着新快照变化。
struct ReferenceDecorationTests {
    /// 同一提交上有 HEAD 所在分支、另外两个本地分支、指向分支的符号引用、两个远端的分支与 `origin/HEAD`、
    /// 轻量与附注标签各一个；排列结果与真实 `git log --decorate=full` 的 `%D` 逐项相同。
    /// 分离 HEAD，以及移动、改名、删除引用之后，重新读取的快照同样与 `%D` 相同。
    @Test("引用标记按 Git decoration 的顺序")
    func decorationOrder() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner

        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "base"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "tip"])

        // 名字的字节序与创建顺序故意不同
        for arguments in [
            ["branch", "zeta"],
            ["branch", "alpha"],
            ["tag", "v2"],
            ["tag", "-a", "v1", "-m", "v1"],
            ["update-ref", "refs/remotes/origin/main", "HEAD"],
            ["update-ref", "refs/remotes/origin/dev", "HEAD"],
            ["update-ref", "refs/remotes/upstream/main", "HEAD"],
            ["symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main"],
            ["symbolic-ref", "refs/heads/sym", "refs/heads/alpha"],
        ] {
            _ = try await runner.run(arguments)
        }

        // HEAD 在 main 上
        try await Self.expectGitOrder(runner)

        // 分离 HEAD
        _ = try await runner.run(["checkout", "-q", "--detach"])
        try await Self.expectGitOrder(runner)

        // 移动、改名与删除之后按新快照排列
        _ = try await runner.run(["checkout", "-q", "main"])

        for arguments in [
            ["branch", "-f", "zeta", "HEAD~"],
            ["branch", "-m", "alpha", "omega"],
            ["tag", "-d", "v2"],
            ["update-ref", "-d", "refs/remotes/upstream/main"],
        ] {
            _ = try await runner.run(arguments)
        }

        try await Self.expectGitOrder(runner)
    }
}

// MARK: - Steps

extension ReferenceDecorationTests {
    /// 当前 HEAD 提交的引用标记顺序与 `%D` 相同；“HEAD -> 分支” 的分支排在第一个，单独的 HEAD 不算一项。
    private static func expectGitOrder(_ runner: GitRunner) async throws {
        let head = try await output(runner, ["rev-parse", "HEAD"])
        let branch = try? await output(runner, ["symbolic-ref", "-q", "HEAD"])

        let expected = try await output(runner, ["log", "-1", "--format=%D", "--decorate=full"])
            .components(separatedBy: ", ")
            .filter { $0 != "HEAD" }
            .map { $0.replacingOccurrences(of: "HEAD -> ", with: "").replacingOccurrences(of: "tag: ", with: "") }

        let snapshot = try await RepositoryReferences(runner: runner).snapshot()
        let actual = snapshot.decorations(of: head, headBranch: branch).map(\.id)

        #expect(actual == expected)
    }

    /// 命令的标准输出，去掉末尾换行。
    private static func output(_ runner: GitRunner, _ arguments: [String]) async throws -> String {
        String(decoding: try await runner.run(arguments), as: UTF8.self)
            .trimmingCharacters(in: .newlines)
    }
}
