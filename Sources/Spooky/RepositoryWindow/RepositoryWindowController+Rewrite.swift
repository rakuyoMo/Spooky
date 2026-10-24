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
    func presentRewrite(_ request: RewriteRequest) {
        guard let window, window.attachedSheet == nil, session.repository != nil else { return }

        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed

        let close = { [weak sheet] in
            if let sheet { window.endSheet(sheet) }
        }

        sheet.contentViewController = NSHostingController(rootView: rewriteDialog(for: request, close: close))
        window.beginSheet(sheet)
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
