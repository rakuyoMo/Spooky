import AppKit
import SpookyKit
import SwiftUI

// MARK: - Worktrees

extension RepositoryWindowController {
    /// Repository › Add New Worktree… 与侧边栏的添加入口。
    @objc
    func addWorktree() {
        presentWorktreeRequest(.add(revision: nil))
    }

    /// 工作树动作的可用性；动作不属于本组时为 nil。
    func worktreeAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        switch action {
        case #selector(addWorktree):
            repositoryView && session.canWrite

        default:
            nil
        }
    }

    /// 工作树视图：所选工作树的详情。
    func makeWorktreeDetailView() -> NSViewController {
        let controller = NSHostingController(rootView: WorktreeDetailView(session: session))
        controller.sizingOptions = [.minSize]
        return controller
    }

    /// 在本窗口、新标签或新窗口打开另一个仓库；验证与窗口复用规则和打开其它仓库相同。
    func openRepository(at location: RepositoryLocation, in target: RepositoryOpenTarget) {
        switch target {
        case .currentWindow:
            coordinator?.openRepository(at: location, from: self, inNewWindow: false)

        case .newTab:
            coordinator?.openRepositoryInNewTab(at: location, after: self)

        case .newWindow:
            coordinator?.openRepository(at: location, from: self, inNewWindow: true)
        }
    }

    /// 呈现工作树的对话框；对话框在写操作开始后才关闭。
    func presentWorktreeRequest(_ request: WorktreeRequest) {
        guard session.repository != nil, session.canWrite else {
            return
        }

        presentDialog { close in
            switch request {
            case .add(let revision):
                AddWorktreeDialog(session: session, revision: revision, close: close)

            case .move(let worktree):
                WorktreePathDialog(session: session, worktree: worktree, target: .move, close: close)

            case .repair(let worktree):
                WorktreePathDialog(session: session, worktree: worktree, target: .repair, close: close)

            case .remove(let worktree):
                RemoveWorktreeDialog(session: session, worktree: worktree, close: close)
            }
        }
    }
}
