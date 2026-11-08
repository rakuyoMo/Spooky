import Foundation
import Testing

@testable import SpookyKit

// MARK: - TrackingCheckout

extension BranchManagementTests {
    /// 检出同名本地分支并改设上游：本地分支的提交不被远端分支覆盖，原来的上游换成新的；
    /// 分支在别的工作树检出时说明那个工作树、上游与 HEAD 都不动；检出被本地修改挡住时上游已改、HEAD 与本地修改不变。
    @Test("检出已有的本地分支并设置上游，工作树占用与检出失败")
    func checkoutTracking() async throws {
        let fixture = try await Self.committedRepository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        let file = fixture.directory.appendingPathComponent("a.txt")

        try Data("main\n".utf8).write(to: file)
        _ = try await runner.run(["add", "a.txt"])
        _ = try await runner.run(["commit", "-q", "-m", "main"])
        _ = try await runner.run(["remote", "add", "origin", fixture.directory.path])

        // 本地分支各有自己的提交，远端分支停在 main 上；other 原来跟踪 origin/main
        for name in ["other", "busy", "blocked"] {
            _ = try await runner.run(["switch", "-q", "-c", name, "main"])
            try Data((name + "\n").utf8).write(to: file)
            _ = try await runner.run(["commit", "-q", "-am", name])
            _ = try await runner.run(["update-ref", "refs/remotes/origin/" + name, "main"])
        }

        _ = try await runner.run(["update-ref", "refs/remotes/origin/main", "main"])
        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["branch", "-q", "--set-upstream-to=origin/main", "other"])

        // 检出并改设上游，本地提交保留
        let other = try await refs.resolve("refs/heads/other")

        try await refs.checkout("refs/heads/other", tracking: "refs/remotes/origin/other")

        #expect(try await runner.status().branch.head == "other")
        #expect(try await refs.resolve("refs/heads/other") == other)
        #expect(try await Self.reference("refs/heads/other", in: refs)?.upstream == "refs/remotes/origin/other")

        // 在别的工作树检出的分支：不写上游，HEAD 不变
        _ = try await runner.run(["switch", "-q", "main"])
        let worktree = fixture.directory.appendingPathComponent("wt").path
        _ = try await runner.run(["worktree", "add", "-q", worktree, "busy"])

        let occupied = try await #require(throws: ReferenceError.self) {
            try await refs.checkout("refs/heads/busy", tracking: "refs/remotes/origin/busy")
        }

        guard case .checkedOutInWorktree("busy", let path) = occupied else {
            Issue.record("应说明分支在别的工作树检出：\(occupied)")
            return
        }

        // 临时目录经过符号链接，比较两边解析后的路径
        let reported = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let expected = URL(fileURLWithPath: worktree).resolvingSymlinksInPath()

        #expect(reported == expected)
        #expect(try await Self.reference("refs/heads/busy", in: refs)?.upstream == nil)
        #expect(try await runner.status().branch.head == "main")

        // 本地修改挡住检出：上游已经改了，HEAD、分支的提交与本地修改都不变
        let blocked = try await refs.resolve("refs/heads/blocked")
        try Data("local\n".utf8).write(to: file)

        let failure = try await #require(throws: ReferenceError.self) {
            try await refs.checkout("refs/heads/blocked", tracking: "refs/remotes/origin/blocked")
        }

        guard case .trackingCheckoutFailed("blocked", "refs/remotes/origin/blocked", let checkout) = failure else {
            Issue.record("应说明上游已设好、检出失败：\(failure)")
            return
        }

        #expect(checkout.category == .localChanges)
        #expect(checkout.exitCode == 1)
        #expect(try await Self.reference("refs/heads/blocked", in: refs)?.upstream == "refs/remotes/origin/blocked")
        #expect(try await refs.resolve("refs/heads/blocked") == blocked)
        #expect(try await runner.status().branch.head == "main")
        #expect(try String(contentsOf: file, encoding: .utf8) == "local\n")
    }
}
