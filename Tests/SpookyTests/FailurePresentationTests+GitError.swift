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

        let locked = AppFailure(
            error: Self.gitError(.indexLocked, ["add", "--", "a.txt"]),
            opening: false,
            location: nil
        )

        #expect(
            locked.message == AppLocalization.text(
                "failure.reason",
                AppLocalization.text("error.indexLocked"),
                AppLocalization.text("error.refreshHelp")
            )
        )

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
