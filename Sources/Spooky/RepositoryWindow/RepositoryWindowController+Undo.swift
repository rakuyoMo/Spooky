import AppKit

// MARK: - Undo

extension RepositoryWindowController {
    /// Edit 菜单的撤销对象：编辑文字时撤销文字，其余时候撤销本仓库的写操作；仓库管理界面没有可撤销的写操作。
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        if window.firstResponder is NSText || showsManager {
            return textUndoManager
        }

        return repositoryUndoManager
    }
}
