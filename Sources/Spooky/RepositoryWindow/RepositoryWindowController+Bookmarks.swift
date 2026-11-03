import AppKit
import SwiftUI

// MARK: - Bookmark Dialogs

extension RepositoryWindowController {
    /// 以 sheet 呈现仓库管理与仓库操作的对话框；窗口已有 sheet 时不叠加。
    ///
    /// - Parameter content: 用关闭动作构建对话框内容。
    func presentDialog(@ViewBuilder _ content: (_ close: @escaping () -> Void) -> some View) {
        guard let window, window.attachedSheet == nil else {
            return
        }

        DialogWindow.present(on: window, content: content)
    }

    /// 添加的目录不是 Git 仓库时询问是否在那里新建仓库。
    ///
    /// - Parameters:
    ///   - directory: 添加的本机目录。
    ///   - create: 用户选择新建时的动作。
    func presentNoRepositoryFound(_ directory: URL, create: @escaping () -> Void) {
        showWindow(nil)

        presentDialog { close in
            NoRepositoryFoundDialog(directory: directory, close: close, create: create)
        }
    }
}
