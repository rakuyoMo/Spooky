import AppKit

// MARK: - RepositoryUndoManager

/// 仓库窗口交给 Edit 菜单的撤销管理器：撤销与重做的是本仓库的写操作，栈按仓库共用。
///
/// 菜单项的标题与可用性都由窗口向它询问；有记录却不能执行时，标题写明原因。
@MainActor
final class RepositoryUndoManager: UndoManager {
    /// 提供撤销栈、可用性与执行入口的窗口会话。
    private weak var session: RepositorySession?

    /// 最近的操作此刻能否撤销。
    override var canUndo: Bool {
        if case .available = state(redo: false) { true } else { false }
    }

    /// 最近撤销的操作此刻能否重做。
    override var canRedo: Bool {
        if case .available = state(redo: true) { true } else { false }
    }

    /// 撤销栈顶的操作名称；不能撤销的上一个操作同样给出名称。
    override var undoActionName: String {
        name(of: state(redo: false))
    }

    /// 重做栈顶的操作名称。
    override var redoActionName: String {
        name(of: state(redo: true))
    }

    /// “Undo <操作名>”；不能执行时写明原因。
    override var undoMenuItemTitle: String {
        title(for: state(redo: false), redo: false)
    }

    /// “Redo <操作名>”；不能执行时写明原因。
    override var redoMenuItemTitle: String {
        title(for: state(redo: true), redo: true)
    }

    /// 创建窗口的撤销管理器。
    ///
    /// - Parameter session: 窗口会话；撤销与重做经它的写队列执行。
    init(session: RepositorySession) {
        self.session = session
        super.init()
    }

    /// Edit → Undo 与 ⌘Z。
    override func undo() {
        session?.undoLastOperation()
    }

    /// Edit → Redo 与 ⇧⌘Z。
    override func redo() {
        session?.redoLastOperation()
    }
}

// MARK: - Private

extension RepositoryUndoManager {
    /// 会话给出的菜单状态；窗口已关闭时没有可撤销的操作。
    private func state(redo: Bool) -> UndoMenuState {
        session?.undoMenuState(redo: redo) ?? .empty
    }

    /// 状态里的操作名称。
    private func name(of state: UndoMenuState) -> String {
        switch state {
        case .empty: ""
        case .irreversible(let name), .available(let name), .blocked(let name, _): name
        }
    }

    /// 菜单标题：能执行时由系统生成 “Undo <操作名>”，不能撤销的操作与暂不能执行的记录各有说明。
    private func title(for state: UndoMenuState, redo: Bool) -> String {
        switch state {
        case .empty:
            AppLocalization.text(redo ? "menu.redo" : "menu.undo")

        case .available(let name):
            redo ? redoMenuTitle(forUndoActionName: name) : undoMenuTitle(forUndoActionName: name)

        case .irreversible(let name):
            AppLocalization.text("undo.cannotUndo", name)

        case .blocked(let name, let reason):
            AppLocalization.text(
                "undo.unavailable",
                AppLocalization.text(redo ? "undo.cannotRedo" : "undo.cannotUndo", name),
                AppLocalization.text(reason)
            )
        }
    }
}
