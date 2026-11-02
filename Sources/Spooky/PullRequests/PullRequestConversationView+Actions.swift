import AppKit
import SpookyKit

// MARK: - Actions

extension PullRequestConversationView.Coordinator {
    /// 右键菜单按作用的行现拼，不改变选区；作用的行全是提交时才有菜单。
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        guard let outline else { return }

        let nodes = affectedNodes(clickedRow: outline.clickedRow)

        let commits = nodes.compactMap { node -> HistoryCommit? in
            guard case .commit(let commit) = node.item else { return nil }
            return commit
        }

        guard !commits.isEmpty, commits.count == nodes.count else { return }

        for item in commitMenuItems(commits) {
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

    /// 作用的第一行是提交时回到历史打开它；其余的行不做事。
    private func open(_ nodes: [PullRequestConversationView.Node]) {
        guard case .commit(let commit) = nodes.first?.item else { return }

        parent.session.showCommit(commit)
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
