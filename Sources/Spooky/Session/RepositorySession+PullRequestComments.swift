import Foundation
import SpookyKit

// MARK: - Comment Availability

extension RepositorySession {
    /// 能回复评论：有可用的账号，且托管服务支持回复；任何人的评论都能回复。
    var canReplyToComments: Bool {
        discussionAccount?.instance.service.supportsCommentReplies ?? false
    }

    /// 能修改或删除这条评论：评论的作者是当前账号，且内容不为空。
    ///
    /// 这一组规则由右键菜单、评论上的动作条、双击与回车共用。
    func canModify(_ comment: PullRequestComment) -> Bool {
        guard let account = discussionAccount, !comment.body.isEmpty else {
            return false
        }

        return Self.isAccount(account, comment.author)
    }

    /// 能修改请求的描述：请求的作者是当前账号。
    func canEditDescription(of request: PullRequest) -> Bool {
        guard let account = discussionAccount else {
            return false
        }

        return Self.isAccount(account, request.author)
    }
}

// MARK: - Comment Actions

extension RepositorySession {
    /// 修改一条评论。
    func editComment(_ comment: PullRequestComment, body: String, on request: PullRequest) -> Bool {
        performHosting(title: pullRequestText("editComment.title")) { client in
            try await client.editComment(comment.id, body: body, on: request.id)
            return nil
        }
    }

    /// 回复一条评论。
    func replyToComment(_ comment: PullRequestComment, body: String, on request: PullRequest) -> Bool {
        performHosting(title: pullRequestText("replyComment.title")) { client in
            try await client.replyToComment(comment.id, body: body, on: request.id)
            return nil
        }
    }

    /// 删除一条评论。
    func deleteComment(_ comment: PullRequestComment, on request: PullRequest) -> Bool {
        let service = AccountsSettingsView.serviceTitle(request.id.instance)

        return performHosting(title: pullRequestText("deleteComment.title", service)) { client in
            try await client.deleteComment(comment.id, on: request.id)
            return nil
        }
    }

    /// 只修改描述。
    func updateDescription(_ body: String, of request: PullRequest) -> Bool {
        performHosting(title: pullRequestText("editDescription.title")) { client in
            try await client.updateDescription(body, of: request.id)
            return nil
        }
    }
}

// MARK: - Private

extension RepositorySession {
    /// 讨论里写操作所用的账号：选中远端对应的账号，有接口客户端且不需要重新认证；否则为 nil。
    private var discussionAccount: HostingAccount? {
        guard
            let account = pullRequests.account,
            pullRequests.client != nil,
            let current = pullRequests.accounts.items.first(where: { $0.id == account.id }),
            !current.needsReauthentication
        else {
            return nil
        }

        return account
    }

    /// 托管用户就是这个账号：用户名不分大小写相同。
    private static func isAccount(_ account: HostingAccount, _ user: HostingUser) -> Bool {
        user.username.caseInsensitiveCompare(account.username) == .orderedSame
    }
}
