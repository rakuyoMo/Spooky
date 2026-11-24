import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - FailurePresentationTests + GitError

/// Git 错误的标题、说明与原文：按命令取的标题看失败的命令，写成整句的原因放在说明里，原文先 stderr 后 stdout。
extension FailurePresentationTests {
    /// 删除没有合并的分支时，删一个分支是单数的标题、删两个是复数，强制删除的询问带着的失败同样如此；
    /// 本地改动挡住时按挡住的操作取标题，合并、变基、检出各有标题，其余命令用通用的标题，发起前的检查由错误带上操作。
    @Test("按命令取的标题：未合并分支的单复数与被本地改动挡住的操作")
    func commandTitles() {
        let single = Self.gitError(.branchNotMerged, ["branch", "-d", "--", "topic"])
        let multiple = Self.gitError(.branchNotMerged, ["branch", "-d", "--", "topic", "other"])

        // 删除未合并的分支
        let unmerged: [(any Error, String)] = [
            (single, "branch.error.delete"),
            (multiple, "branch.error.deleteMultiple"),
            (
                ReferenceError.unmergedBranches(["refs/heads/topic", "refs/heads/other"], multiple),
                "branch.error.deleteMultiple"
            ),
            (
                ForceDeletionOffer(
                    branches: ["refs/heads/topic"],
                    deletingUpstream: false,
                    failure: .unmergedBranches(["refs/heads/topic"], single)
                ),
                "branch.error.delete"
            ),
        ]

        // 被本地改动挡住
        let blocked: [(any Error, String)] = [
            (
                Self.gitError(.localChanges, ["-c", "merge.autoStash=false", "merge", "--no-edit", "main"]),
                "error.merge"
            ),
            (Self.gitError(.localChanges, ["rebase", "main"]), "error.rebase"),
            (Self.gitError(.localChanges, ["checkout", "--detach", "main"]), "error.checkout"),
            (Self.gitError(.localChanges, ["switch", "--", "main"]), "error.checkout"),
            (Self.gitError(.localChanges, ["cherry-pick", "main"]), "error.command"),
            (RepositorySyncError.dirtyWorkingCopy(rebase: false), "error.merge"),
            (RepositorySyncError.dirtyWorkingCopy(rebase: true), "error.rebase"),
        ]

        for (error, title) in unmerged + blocked {
            let failure = AppFailure(error: error, opening: false, location: nil, writing: true)

            #expect(failure.title == AppLocalization.text(title), "\(error)")
        }

        for (error, _) in blocked {
            let failure = AppFailure(error: error, opening: false, location: nil, writing: true)

            #expect(failure.message.hasPrefix(AppLocalization.text("sync.error.dirty")), "\(error)")
        }
    }

    /// 写成整句的原因排在说明最前，恢复说明接在同一段，标题已经说清的错误只有恢复说明；
    /// 分支名带着不合法的原因时，恢复说明换成这条原因，Git 的原文写进详情；
    /// 原文先 stderr、再 stdout，不写退出码，两者都为空且没有诊断时写 “(No error message given)”。
    @Test("说明先写原因，原文先 stderr 后 stdout")
    func messageAndDetails() {
        // 原因与恢复说明
        let invalid = AppFailure(error: ReferenceError.invalidName("a b"), opening: false, location: nil)

        #expect(invalid.title == AppLocalization.text("reference.error.name.title"))

        #expect(
            invalid.message == AppLocalization.text(
                "failure.reason",
                AppLocalization.text("reference.error.name"),
                AppLocalization.text("reference.error.name.help")
            )
        )

        let rejection = GitCommandResult(
            arguments: ["check-ref-format", "--branch", "a/.b"],
            standardOutput: Data(),
            standardError: Data("fatal: 'a/.b' is not a valid branch name\n".utf8),
            terminationStatus: .exited(128),
            isCancelled: false
        )

        let reason = AppFailure(
            error: ReferenceError.invalidName("a/.b", problem: .component, output: rejection),
            opening: false,
            location: nil
        )

        #expect(
            reason.message == AppLocalization.text(
                "failure.reason",
                AppLocalization.text("reference.error.name"),
                AppLocalization.text("reference.name.component")
            )
        )

        #expect(reason.details.contains("is not a valid branch name"))

        // 新分支建好、检出失败时标题与说明写明已创建，原文是检出的输出
        let checkout = AppFailure(
            error: ReferenceError.createdBranchCheckoutFailed("topic", Self.gitError(.localChanges, ["switch", "topic"])),
            opening: false,
            location: nil,
            writing: true
        )

        #expect(checkout.title == AppLocalization.text("branch.error.checkoutCreated.title"))
        #expect(checkout.message.hasPrefix(AppLocalization.text("branch.error.checkoutCreated")))

        let locked = AppFailure(
            error: Self.gitError(.indexLocked, ["add", "--", "a.txt"]),
            opening: false,
            location: nil
        )

        // 认不出锁文件的路径时写仓库里的相对位置，同样不接恢复说明
        #expect(locked.message == AppLocalization.text("error.indexLocked", ".git/index.lock"))

        let generic = AppFailure(
            error: Self.gitError(.commandFailed, ["status"]),
            opening: false,
            location: nil,
            writing: true
        )

        #expect(generic.message == AppLocalization.text("error.writeHelp"))

        // Git 原文
        let error = GitError(
            result: GitCommandResult(
                arguments: ["push"],
                standardOutput: Data("standard output\n".utf8),
                standardError: Data("standard error\n".utf8),
                terminationStatus: .exited(128),
                isCancelled: false
            ),
            category: .commandFailed,
            diagnostic: nil
        )

        let details = AppFailure(error: error, opening: false, location: nil).details
        let silent = AppFailure(error: Self.gitError(.commandFailed, ["push"]), opening: false, location: nil)

        #expect(details == "standard error\n\nstandard output\n")
        #expect(!details.contains("128"))
        #expect(silent.details == AppLocalization.text("error.noOutput"))
    }
}

// MARK: - Index Lock

extension FailurePresentationTests {
    /// 索引被锁时说明只有一句，写出 Git 报出的锁文件路径，写操作也不接通用的恢复说明；类别与仓库位置两行照旧。
    @Test("索引被锁的说明")
    func indexLocked() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)

        // 另一个 Git 进程留下的锁文件挡住暂存
        try Data().write(to: directory.appending(path: ".git/index.lock"))
        try Data("one\n".utf8).write(to: directory.appending(path: "a.txt"))

        let thrown = await #expect(throws: GitError.self) {
            try await runner.run(["add", "--", "a.txt"])
        }

        let error = try #require(thrown)
        let failure = AppFailure(error: error, opening: false, location: location, writing: true)

        // Git 报出的是解析过符号链接的绝对路径，临时目录在 /var 下时是 /private/var
        let resolved = try #require(realpath(directory.path, nil))
        defer { free(resolved) }

        let lockFile = String(cString: resolved) + "/.git/index.lock"

        #expect(error.category == .indexLocked)
        #expect(failure.title == AppLocalization.text("error.indexLocked.title"))
        #expect(failure.message == AppLocalization.text("error.indexLocked", lockFile))

        #expect(
            failure.context == [
                AppLocalization.text("failure.category", AppLocalization.text("failure.kind.git")),
                AppLocalization.text("failure.location", location.displayPath),
            ]
            .joined(separator: "\n")
        )
    }
}

// MARK: - LFS

extension FailurePresentationTests {
    /// Git 执行 LFS 过滤器时找不到 git-lfs：标题是 Git LFS 不可用，属于环境问题，写操作也不接通用的恢复说明；
    /// 修复方向按仓库位置取，本机仓库指向 设置 → 环境，服务器仓库指向服务器上非交互 SSH 会话的 PATH。
    @Test("找不到 git-lfs 时按仓库位置给出修复方向")
    func lfsUnavailable() {
        let error = Self.gitError(.lfsUnavailable, ["switch", "--", "main"])
        let local = AppFailure(
            error: error,
            opening: false,
            location: .local(path: "/tmp/仓 库"),
            writing: true
        )

        let server = AppFailure(
            error: error,
            opening: false,
            location: .remote(host: "spooky-test", path: "/tmp/仓 库"),
            writing: true
        )

        #expect(local.title == AppLocalization.text("hostError.lfsUnavailable"))
        #expect(local.kind == .environment)
        #expect(local.message == AppLocalization.text("lfs.unavailable.local"))
        #expect(server.message == AppLocalization.text("lfs.unavailable.remote"))
    }
}

// MARK: - Helpers

extension FailurePresentationTests {
    /// 以退出码 1 结束、没有输出的 Git 失败。
    static func gitError(_ category: GitError.Category, _ arguments: [String]) -> GitError {
        let result = GitCommandResult(
            arguments: arguments,
            standardOutput: Data(),
            standardError: Data(),
            terminationStatus: .exited(1),
            isCancelled: false
        )

        return GitError(result: result, category: category, diagnostic: nil)
    }
}
