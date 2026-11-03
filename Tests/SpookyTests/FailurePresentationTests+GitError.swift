import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - FailurePresentationTests + GitError

/// Git 错误的标题、说明与原文：标题是简短的名词短语，写成整句的原因放在说明里，原文先 stderr 后 stdout。
extension FailurePresentationTests {
    /// 每一类 Git 失败与发起前的同步检查都有对应的标题；连接中断与其余的 Git 失败用通用的标题。
    @Test("Git 错误的标题")
    func gitErrorTitles() {
        let cases: [(GitError.Category, String)] = [
            (.connectionUnavailable, "error.command"),
            (.commandFailed, "error.command"),
            (.authenticationFailed, "error.remoteConnection"),
            (.connectionTimedOut, "error.remoteConnection"),
            (.pushRejected, "error.synchronization"),
            (.noUpstream, "error.synchronization"),
            (.remoteNotFound, "error.remoteNotFound"),
            (.indexLocked, "error.indexLocked.title"),
            (.signingFailed, "signing.error.title"),
        ]

        for (category, title) in cases {
            let error = Self.gitError(category, ["push", "origin"])
            let failure = AppFailure(error: error, opening: false, location: nil)

            #expect(failure.title == AppLocalization.text(title), "\(category)")
        }

        let syncCases: [(RepositorySyncError, String)] = [
            (.missingUpstream, "error.synchronization"),
            (.missingRemote, "error.remoteNotFound"),
            (.requiresBranch, "sync.error.branch.title"),
        ]

        for (error, title) in syncCases {
            let failure = AppFailure(error: error, opening: false, location: nil)
            #expect(failure.title == AppLocalization.text(title), "\(error)")
        }
    }

    /// 删除没有合并的分支时，命令里删一个分支是 Could Not Delete Branch，删两个是复数；强制删除的询问带着的失败同样如此。
    @Test("删除未合并分支的单复数")
    func unmergedBranchTitles() {
        let single = Self.gitError(.branchNotMerged, ["branch", "-d", "--", "topic"])
        let multiple = Self.gitError(.branchNotMerged, ["branch", "-d", "--", "topic", "other"])

        let errors: [any Error] = [
            single,
            multiple,
            ReferenceError.unmergedBranches(["refs/heads/topic", "refs/heads/other"], multiple),
            ForceDeletionOffer(
                branches: ["refs/heads/topic"],
                deletingUpstream: false,
                failure: .unmergedBranches(["refs/heads/topic"], single)
            ),
        ]

        let titles = errors.map { AppFailure(error: $0, opening: false, location: nil, writing: true).title }

        #expect(
            titles == [
                "branch.error.delete",
                "branch.error.deleteMultiple",
                "branch.error.deleteMultiple",
                "branch.error.delete",
            ]
            .map { AppLocalization.text($0) }
        )
    }

    /// 本地改动挡住时按挡住的操作取标题：合并、变基、检出各有标题，其余命令用通用的标题；发起前的检查由错误带上操作。
    @Test("被本地改动挡住的标题")
    func blockedByLocalChangesTitles() {
        let cases: [(any Error, String)] = [
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

        for (error, title) in cases {
            let failure = AppFailure(error: error, opening: false, location: nil, writing: true)

            #expect(failure.title == AppLocalization.text(title), "\(error)")
            #expect(failure.message.hasPrefix(AppLocalization.text("sync.error.dirty")))
        }
    }

    /// 写成整句的原因排在说明最前，恢复说明接在同一段；标题已经说清的错误只有恢复说明。
    @Test("说明先写原因再写恢复说明")
    func causeLeadsMessage() {
        let invalid = AppFailure(error: ReferenceError.invalidName("a b"), opening: false, location: nil)

        #expect(invalid.title == AppLocalization.text("reference.error.name.title"))
        #expect(invalid.message == AppLocalization.text(
            "failure.reason",
            AppLocalization.text("reference.error.name"),
            AppLocalization.text("reference.error.name.help")
        ))

        let locked = AppFailure(
            error: Self.gitError(.indexLocked, ["add", "--", "a.txt"]),
            opening: false,
            location: nil
        )

        #expect(locked.message == AppLocalization.text(
            "failure.reason",
            AppLocalization.text("error.indexLocked"),
            AppLocalization.text("error.refreshHelp")
        ))

        let generic = AppFailure(
            error: Self.gitError(.commandFailed, ["status"]),
            opening: false,
            location: nil,
            writing: true
        )

        #expect(generic.message == AppLocalization.text("error.writeHelp"))
    }

    /// 原文先 stderr、再 stdout，不写退出码；两者都为空且没有诊断时写 “(No error message given)”。
    @Test("Git 原文")
    func gitErrorDetails() {
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
        let silent = Self.gitError(.commandFailed, ["push"])
        let empty = AppFailure(error: silent, opening: false, location: nil).details

        #expect(details == "standard error\n\nstandard output\n")
        #expect(!details.contains("128"))
        #expect(empty == AppLocalization.text("error.noOutput"))
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
