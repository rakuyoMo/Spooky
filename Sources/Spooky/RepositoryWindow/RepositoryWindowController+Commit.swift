import AppKit
import SwiftUI

// MARK: - Commit

extension RepositoryWindowController {
    /// 提交信息含注释行时的询问：可删除或保留注释，删除后为空时只能保留注释提交。
    ///
    /// 勾选 “不再询问” 时把这次的选择存为 Editor 设置：关闭提示，删除注释的选择同时打开 “总是删除”。
    func configureCommentPrompt() {
        session.onCommentPrompt = { [weak self] empty, decide in
            self?.presentDialog { close in
                CommitCommentsDialog(empty: empty, close: close) { decision, doNotAskAgain in
                    if doNotAskAgain {
                        UserDefaults.standard.set(false, forKey: CommitEditorSettings.warnsCommentsKey)
                        UserDefaults.standard.set(decision == .remove, forKey: CommitEditorSettings.stripsCommentsKey)
                    }

                    decide(decision)
                }
            }
        }
    }
}
