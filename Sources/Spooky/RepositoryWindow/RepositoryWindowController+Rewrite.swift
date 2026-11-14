import AppKit
import SpookyKit
import SwiftUI

// MARK: - Rewrite

extension RepositoryWindowController {
    /// 主菜单的检出版本；历史视图里预填选中的提交。
    @objc
    func checkoutRevision() { session.requestCheckout(selectedHistoryCommit) }

    /// 主菜单的变基到别处，移动当前分支在当前基点之后的全部提交。
    @objc
    func rebaseOnto() { session.requestRebaseOnto() }

    /// 主菜单的重置 HEAD；历史视图里预填选中的提交。
    @objc
    func resetHead() { session.requestReset(to: selectedHistoryCommit) }

    /// 改写操作的可用性；动作不属于本组时为 nil。
    func rewriteAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        switch action {
        case #selector(checkoutRevision):
            repositoryView && session.canCheckoutRevision

        case #selector(rebaseOnto), #selector(resetHead):
            repositoryView && session.canRewrite

        default:
            nil
        }
    }

    /// 改写操作的对话框与确认以 sheet 呈现；已有 sheet 时不叠加。
    ///
    /// 改信息与删除涉及已推送的提交时，先以系统提示框确认，确认后才打开对话框。
    func presentRewrite(_ request: RewriteRequest) {
        guard session.repository != nil, let window, window.attachedSheet == nil else {
            return
        }

        guard let alert = Self.pushedRewriteAlert(for: request) else {
            DialogWindow.present(on: window) { close in
                rewriteDialog(for: request, close: close)
            }
            return
        }

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn else {
                return
            }

            // 提示框可能还没从窗口上取下，AppKit 会在它结束后再挂上对话框
            DialogWindow.present(on: window) { close in
                rewriteDialog(for: request, close: close)
            }
        }
    }
}

// MARK: - Pushed Commits

extension RepositoryWindowController {
    /// 改信息与删除的范围里有已推送到上游的提交时，确认是否改写的提示框；其余请求为 nil。
    ///
    /// 范围从所选提交里最旧的一个开始，范围里有已推送的提交，所选的提交就已推送。
    /// 主按钮是动作本身（Edit Commit Message 或 Delete Revisions），另一个是 Cancel。
    static func pushedRewriteAlert(for request: RewriteRequest) -> NSAlert? {
        let warned: (plan: RewritePlan, confirmKey: String)? =
            switch request {
            case .reword(let plan):
                (plan, "rewrite.reword")

            case .confirm(let plan):
                if case .drop = plan.action { (plan, "rewrite.drop") } else { nil }

            default:
                nil
            }

        guard let warned, !warned.plan.pushed.isEmpty else {
            return nil
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppLocalization.text("rewrite.pushed.title")
        alert.informativeText = AppLocalization.text("rewrite.pushed.message")
        alert.addButton(withTitle: AppLocalization.text(warned.confirmKey))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))

        return alert
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 历史视图里选中的提交；其它视图为 nil。
    private var selectedHistoryCommit: String? {
        session.activeView == .history ? session.history.selectedCommit?.id : nil
    }

    /// 每种请求对应的对话框。
    @ViewBuilder
    private func rewriteDialog(for request: RewriteRequest, close: @escaping () -> Void) -> some View {
        switch request {
        case .revert(let commits):
            PickRevisionsDialog(session: session, kind: .revert, commits: commits, close: close)

        case .cherryPick(let commits):
            PickRevisionsDialog(session: session, kind: .cherryPick, commits: commits, close: close)

        case .reset(let revision):
            ResetDialog(session: session, revision: revision, close: close)

        case .checkout(let revision):
            CheckoutRevisionDialog(session: session, revision: revision, close: close)

        case .rebaseOnto(let commits):
            RebaseOntoDialog(session: session, commits: commits, close: close)

        case .confirm(let plan):
            RewriteConfirmationDialog(session: session, plan: plan, close: close)

        case .reword(let plan):
            RewordDialog(session: session, plan: plan, close: close)
        }
    }
}
