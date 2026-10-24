import AppKit
import SwiftUI

// MARK: - Commit

extension RepositoryWindowController {
    /// 提交信息含注释行时的询问：可删除或保留注释，删除后为空时只能保留注释提交。
    ///
    /// 勾选 “不再询问” 时把这次的选择存为 Editor 设置：关闭提示，删除注释的选择同时打开 “总是删除”。
    func configureCommentPrompt() {
        session.onCommentPrompt = { [weak self] empty, decide in
            guard let window = self?.window, window.attachedSheet == nil else { return }

            let sheet = NSWindow()
            sheet.styleMask = [.titled]
            sheet.tabbingMode = .disallowed

            let content = NSHostingController(
                rootView: CommitCommentsDialog(empty: empty) { [weak sheet] decision, doNotAskAgain in
                    if let sheet {
                        window.endSheet(sheet)
                    }

                    guard let decision else { return }

                    if doNotAskAgain {
                        UserDefaults.standard.set(false, forKey: CommitEditorSettings.warnsCommentsKey)
                        UserDefaults.standard.set(decision == .remove, forKey: CommitEditorSettings.stripsCommentsKey)
                    }

                    decide(decision)
                }
            )

            // 按钮文字较长的语言里按钮组比默认宽度宽，sheet 按内容的理想尺寸加宽。
            content.sizingOptions = .preferredContentSize
            sheet.contentViewController = content
            window.beginSheet(sheet)
        }
    }
}
