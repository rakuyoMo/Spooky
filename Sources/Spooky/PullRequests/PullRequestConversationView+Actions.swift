import AppKit
import SpookyKit

// MARK: - Actions

extension PullRequestConversationView.Coordinator {
    /// 右键菜单按作用的行现拼，不改变选区：作用的行全是提交，或恰好是一条评论或描述时才有菜单。
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        guard let outline else { return }

        let nodes = affectedNodes(clickedRow: outline.clickedRow)

        let commits = nodes.compactMap { node -> HistoryCommit? in
            guard case .commit(let commit) = node.item else { return nil }
            return commit
        }

        let items: [NSMenuItem] =
            switch nodes.first?.item {
            case .comment(let comment) where nodes.count == 1: commentMenuItems(comment)
            case .description where nodes.count == 1: descriptionMenuItems()
            case _ where !commits.isEmpty && commits.count == nodes.count: commitMenuItems(commits)
            default: []
            }

        for item in items {
            menu.addItem(item)
        }
    }

    /// 双击打开作用的第一行。
    @objc
    func doubleClicked(_ sender: NSOutlineView) {
        open(affectedNodes(clickedRow: sender.clickedRow))
    }

    /// 回车打开所选的第一行。
    func openSelection() {
        open(affectedNodes(clickedRow: -1))
    }
}

// MARK: - Private

extension PullRequestConversationView.Coordinator {
    /// 完整哈希按列表顺序以换行连接，写进剪贴板。
    private static func copyHashes(of commits: [HistoryCommit]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(commits.map(\.id).joined(separator: "\n"), forType: .string)
    }

    /// 所点的行在选区内时是整个选区，在选区外时只有这一行；没有所点的行时是选区。按列表顺序排列。
    private func affectedNodes(clickedRow: Int) -> [PullRequestConversationView.Node] {
        guard let outline else { return [] }

        let rows =
            clickedRow >= 0 && !outline.selectedRowIndexes.contains(clickedRow)
                ? IndexSet(integer: clickedRow)
                : outline.selectedRowIndexes

        return rows.compactMap { outline.item(atRow: $0) as? PullRequestConversationView.Node }
    }

    /// 作用的第一行：提交回到历史打开它，评论与描述在能修改时打开修改的对话框、否则提示音；其余的行不做事。
    private func open(_ nodes: [PullRequestConversationView.Node]) {
        let session = parent.session
        let request = parent.request

        switch nodes.first?.item {
        case .commit(let commit):
            session.showCommit(commit)

        case .comment(let comment):
            guard session.canModify(comment) else {
                NSSound.beep()
                return
            }

            session.requestPullRequest(.editComment(request, comment))

        case .description:
            guard session.canEditDescription(of: request) else {
                NSSound.beep()
                return
            }

            session.requestPullRequest(.editDescription(request))

        default:
            break
        }
    }

    /// 描述：只有修改描述，自己的请求才启用。
    private func descriptionMenuItems() -> [NSMenuItem] {
        let session = parent.session
        let request = parent.request

        let edit = FileViewAction(
            title: AppLocalization.text("pullRequests.editDescription.menu"),
            enabled: session.canEditDescription(of: request)
        ) {
            session.requestPullRequest(.editDescription(request))
        }

        return [FileViewMenuItem(edit)]
    }

    /// 一条评论：修改、托管服务支持时的回复、分隔线与删除；菜单项总在，按能否修改与回复启用。
    private func commentMenuItems(_ comment: PullRequestComment) -> [NSMenuItem] {
        let session = parent.session
        let request = parent.request
        let canModify = session.canModify(comment)

        let edit = FileViewAction(
            title: AppLocalization.text("pullRequests.editComment.menu"),
            enabled: canModify
        ) {
            session.requestPullRequest(.editComment(request, comment))
        }

        let reply = FileViewAction(
            title: AppLocalization.text("pullRequests.replyComment.menu"),
            enabled: session.canReplyToComments
        ) {
            session.requestPullRequest(.replyToComment(request, comment))
        }

        let delete = FileViewAction(
            title: AppLocalization.text("pullRequests.deleteComment.menu"),
            enabled: canModify
        ) {
            session.requestPullRequest(.deleteComment(request, comment))
        }

        let replies = request.id.instance.service.supportsCommentReplies ? [FileViewMenuItem(reply)] : []

        return [FileViewMenuItem(edit)] + replies + [.separator(), FileViewMenuItem(delete)]
    }

    /// 一个提交：复制哈希、分隔线与打开提交；几个提交：只有复制全部哈希。
    private func commitMenuItems(_ commits: [HistoryCommit]) -> [NSMenuItem] {
        guard commits.count == 1, let commit = commits.first else {
            let copy = FileViewAction(title: AppLocalization.text("pullRequests.copyCommitHashes", commits.count)) {
                Self.copyHashes(of: commits)
            }

            return [FileViewMenuItem(copy)]
        }

        let session = parent.session

        let copy = FileViewAction(title: AppLocalization.text("pullRequests.copyCommitHash")) {
            Self.copyHashes(of: [commit])
        }

        let show = FileViewAction(title: AppLocalization.text("pullRequests.showCommit", commit.shortID)) {
            session.showCommit(commit)
        }

        return [FileViewMenuItem(copy), .separator(), FileViewMenuItem(show)]
    }
}
