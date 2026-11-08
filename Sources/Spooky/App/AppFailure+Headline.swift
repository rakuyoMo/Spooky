import Foundation
import SpookyKit

// MARK: - Headline

extension AppFailure {
    /// 原因写成一整句的错误另有简短的名词短语作标题：键是原因的文案键，值是标题的文案键。
    private static let titleKeys: [String: String] = [
        "sync.error.connection": "error.command",
        "sync.error.authentication": "error.remoteConnection",
        "sync.error.timeout": "error.remoteConnection",
        "sync.error.rejected": "error.synchronization",
        "sync.error.upstream": "error.synchronization",
        "sync.error.remote": "error.remoteNotFound",
        "error.indexLocked": "error.indexLocked.title",
        "signing.error": "signing.error.title",
        "sync.error.branch": "sync.error.branch.title",
        "branch.error.diverged": "branch.error.diverged.title",
        "branch.error.current": "branch.error.current.title",
        "branch.error.remoteExists": "branch.error.remoteExists.title",
        "branch.error.checkoutCreated": "branch.error.checkoutCreated.title",
        "branch.error.inWorktree": "branch.error.inWorktree.title",
        "branch.error.checkoutTracking": "branch.error.checkoutTracking.title",
        "working.error.stale": "working.error.stale.title",
        "working.error.selection": "working.error.selection.title",
        "working.error.file": "working.error.file.title",
        "working.error.path": "working.error.path.title",
        "diff.error.whitespace": "diff.error.whitespace.title",
        "reference.error.name": "reference.error.name.title",
        "reference.error.refspec": "reference.error.refspec.title",
        "reference.error.url": "reference.error.url.title",
        "remote.error.browser": "remote.error.browser.title",
        "conflict.error.version": "conflict.error.version.title",
    ]

    /// 错误标题与原因的文案键：原因写成一整句的错误另取简短的标题，原因写在说明里；其余错误的文案键就是标题，没有原因。
    ///
    /// 被本地改动挡住时按挡住的操作取标题，删除没有合并的分支按命令里删除的分支个数取单复数。
    ///
    /// - Parameters:
    ///   - key: 错误分类得到的文案键。
    ///   - error: 要报告的错误，用来认出被挡住的操作与删除的分支个数。
    static func headline(of key: String, for error: any Error) -> (title: String, cause: String?) {
        switch key {
        case "sync.error.dirty":
            (blockedOperationTitle(of: error), key)

        case "branch.error.unmerged":
            (deletedBranchCount(in: error) > 1 ? "branch.error.deleteMultiple" : "branch.error.delete", key)

        default:
            titleKeys[key].map { ($0, key) } ?? (key, nil)
        }
    }
}

// MARK: - Private

extension AppFailure {
    /// 被本地改动挡住的操作的标题：合并与拉取、同步时的合并是 Merging Failed，变基与用变基的拉取、同步是 Rebase Failed，
    /// 检出是 Could Not Checkout Revision，其余命令是通用的 Git 失败。
    private static func blockedOperationTitle(of error: any Error) -> String {
        // 发起前的干净工作区检查没有 Git 输出，由错误自己带上被挡住的操作
        if case .dirtyWorkingCopy(let rebase) = error as? RepositorySyncError {
            return rebase ? "error.rebase" : "error.merge"
        }

        switch gitError(in: error)?.command {
        case "merge": return "error.merge"
        case "rebase": return "error.rebase"
        case "checkout", "switch": return "error.checkout"
        default: return "error.command"
        }
    }

    /// 删除分支的命令形如 `branch -d -- <名字>…`，`--` 之后的都是要删除的分支；认不出命令时算一个。
    private static func deletedBranchCount(in error: any Error) -> Int {
        guard
            let arguments = gitError(in: error)?.arguments,
            let separator = arguments.firstIndex(of: "--")
        else { return 1 }

        return arguments.count - separator - 1
    }

    /// 错误里的 Git 失败：Git 自己的失败，或强制删除的询问与未合并的分支带着的那一次删除。
    private static func gitError(in error: any Error) -> GitError? {
        if let offer = error as? ForceDeletionOffer {
            return gitError(in: offer.failure)
        }

        if case .unmergedBranches(_, let git) = error as? ReferenceError {
            return git
        }

        return error as? GitError
    }
}
