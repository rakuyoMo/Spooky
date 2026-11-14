import AppKit
import SwiftUI

// MARK: - Commit

extension RepositoryWindowController {
    /// 提交信息含注释行时的询问：系统提示框。能删除注释时按钮依次是 Remove Comments、Keep Comments 与 Cancel，带不再询问的勾选框；
    /// 去掉注释后信息为空时只有 Keep Comments and Commit 与 Cancel。
    static func commentsAlert(empty: Bool) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = AppLocalization.text(empty ? "commit.commentsOnly" : "commit.comments")
        alert.informativeText = AppLocalization.text(empty ? "commit.commentsOnly.help" : "commit.comments.help")

        if empty {
            alert.addButton(withTitle: AppLocalization.text("commit.keepCommentsAndCommit"))
        } else {
            alert.addButton(withTitle: AppLocalization.text("commit.removeComments"))
            alert.addButton(withTitle: AppLocalization.text("commit.keepComments"))

            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = AppLocalization.text("commit.doNotAskAgain")
        }

        alert.addButton(withTitle: AppLocalization.text("action.cancel"))

        return alert
    }

    /// 注释提示框的结果对应的处理；选了 Cancel 时为 nil。
    ///
    /// - Parameters:
    ///   - empty: 去掉注释后信息是否为空。
    ///   - response: 提示框的结果，按钮依 `commentsAlert(empty:)` 的顺序。
    static func commentDecision(empty: Bool, response: NSApplication.ModalResponse) -> CommentHandling? {
        switch response {
        case .alertFirstButtonReturn:
            empty ? .keep : .remove

        case .alertSecondButtonReturn where !empty:
            .keep

        default:
            nil
        }
    }

    /// 提交信息含注释行时以系统提示框询问：可删除或保留注释，删除后为空时只能保留注释提交；窗口已有 sheet 时不叠加。
    ///
    /// 勾选 “不再询问” 后选了删除或保留时，把这次的选择存为 Editor 设置：关闭提示，删除注释的选择同时打开 “总是删除”。
    func configureCommentPrompt() {
        session.onCommentPrompt = { [weak self] empty, decide in
            guard let window = self?.window, window.attachedSheet == nil else {
                return
            }

            let alert = Self.commentsAlert(empty: empty)

            alert.beginSheetModal(for: window) { response in
                guard let decision = Self.commentDecision(empty: empty, response: response) else {
                    return
                }

                if alert.suppressionButton?.state == .on {
                    UserDefaults.standard.set(false, forKey: CommitEditorSettings.warnsCommentsKey)
                    UserDefaults.standard.set(decision == .remove, forKey: CommitEditorSettings.stripsCommentsKey)
                }

                decide(decision)
            }
        }
    }
}
