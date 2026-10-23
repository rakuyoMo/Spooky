import AppKit

// MARK: - Commit

extension RepositoryWindowController {
    /// 提交信息含注释行时的询问：可删除或保留注释，删除后为空时只能保留注释提交。
    ///
    /// 勾选 “不再询问” 时把这次的选择存为 Editor 设置：关闭提示，删除注释的选择同时打开 “总是删除”。
    func configureCommentPrompt() {
        session.onCommentPrompt = { [weak self] empty, decide in
            guard let window = self?.window, window.attachedSheet == nil else { return }

            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = AppLocalization.text(empty ? "commit.commentsOnly" : "commit.comments")
            alert.informativeText = AppLocalization.text(empty ? "commit.commentsOnly.help" : "commit.comments.help")

            if empty {
                alert.addButton(withTitle: AppLocalization.text("commit.keepCommentsAndCommit"))
            } else {
                alert.addButton(withTitle: AppLocalization.text("commit.removeComments"))
                alert.addButton(withTitle: AppLocalization.text("commit.keepComments"))
                alert.showsSuppressionButton = true
            }

            alert.addButton(withTitle: AppLocalization.text("action.cancel"))

            alert.beginSheetModal(for: window) { response in
                let decision: CommentHandling? =
                    switch response {
                    case .alertFirstButtonReturn: empty ? .keep : .remove
                    case .alertSecondButtonReturn where !empty: .keep
                    default: nil
                    }

                guard let decision else { return }

                if alert.suppressionButton?.state == .on {
                    UserDefaults.standard.set(false, forKey: CommitEditorSettings.warnsCommentsKey)
                    UserDefaults.standard.set(decision == .remove, forKey: CommitEditorSettings.stripsCommentsKey)
                }

                decide(decision)
            }
        }
    }
}
