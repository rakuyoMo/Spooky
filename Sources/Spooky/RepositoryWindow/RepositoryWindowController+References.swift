import AppKit
import SpookyKit
import SwiftUI

// MARK: - References

extension RepositoryWindowController {
    /// 主菜单的新建标签入口，默认从历史里选中的提交或当前分支开始。
    @objc
    func createTag() {
        let revision = session.activeView == .history ? session.history.selectedCommit?.id : nil
        presentReferenceRequest(.createTag(revision: revision))
    }

    /// 主菜单的发布标签入口。
    @objc
    func publishTag() {
        presentReferenceRequest(.publishTag(nil))
    }

    /// 主菜单的添加远端入口。
    @objc
    func addRemote() {
        presentReferenceRequest(.addRemote)
    }

    /// 引用管理动作的可用性；动作不属于本组时为 nil。
    func referenceAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        switch action {
        case #selector(createTag):
            repositoryView && session.canCreateTag

        case #selector(publishTag):
            repositoryView && session.canPublishTag

        case #selector(addRemote):
            repositoryView && session.canWrite

        default:
            nil
        }
    }

    /// 呈现引用管理的对话框或询问；对话框在写操作开始后才关闭。
    func presentReferenceRequest(_ request: ReferenceRequest) {
        guard let window, session.repository != nil else {
            return
        }

        // 失败后的询问与错误 sheet 一样排队显示，不能因为别的 sheet 而丢掉
        if case .forceDelete(let offer, let failure) = request {
            askForceDeletion(offer, failure: failure, in: window)
            return
        }

        guard window.attachedSheet == nil, session.canWrite else {
            return
        }

        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed

        let close = { [weak sheet] in
            if let sheet { window.endSheet(sheet) }
        }

        sheet.contentViewController = NSHostingController(rootView: dialog(for: request, close: close))
        window.beginSheet(sheet)
    }

    /// 远端视图：所选远端的设置与远端分支。
    func makeRemoteDetailView() -> NSViewController {
        let controller = NSHostingController(rootView: RemoteDetailView(session: session))
        controller.sizingOptions = [.minSize]
        return controller
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 按请求选择对话框。
    private func dialog(for request: ReferenceRequest, close: @escaping () -> Void) -> AnyView {
        switch request {
        case .renameBranch(let reference):
            AnyView(RenameReferenceDialog(session: session, target: .branch(reference), close: close))

        case .renameRemote(let remote):
            AnyView(RenameReferenceDialog(session: session, target: .remote(remote), close: close))

        case .deleteBranches(let references):
            AnyView(DeleteReferencesDialog(session: session, target: .branches(references), close: close))

        case .deleteRemoteBranches(let references):
            AnyView(DeleteReferencesDialog(session: session, target: .remoteBranches(references), close: close))

        case .deleteTags(let names):
            AnyView(DeleteReferencesDialog(session: session, target: .tags(names), close: close))

        case .deleteRemotes(let names):
            AnyView(DeleteReferencesDialog(session: session, target: .remotes(names), close: close))

        case .setParent(let reference):
            AnyView(SetParentBranchDialog(session: session, branch: reference, close: close))

        case .createTag(let revision):
            AnyView(CreateTagDialog(session: session, revision: revision, close: close))

        case .publishTag(let tag, let remote):
            AnyView(PublishTagDialog(session: session, tag: tag, preselectedRemote: remote, close: close))

        case .addRemote:
            AnyView(AddRemoteDialog(session: session, close: close))

        case .editURL(let remote, let push):
            AnyView(RemoteValueDialog(session: session, target: .url(remote: remote, push: push), close: close))

        case .refspec(let remote, let push, let original):
            AnyView(RemoteValueDialog(
                session: session,
                target: .refspec(remote: remote, push: push, original: original),
                close: close
            ))

        case .forceDelete:
            AnyView(EmptyView())
        }
    }

    /// 未合并分支的普通删除失败后询问是否强制删除：说明写出这些分支，附上 Git 原文。
    private func askForceDeletion(_ offer: ForceDeletionOffer, failure: AppFailure, in window: NSWindow) {
        let names = offer.branches.map { String($0.dropFirst("refs/heads/".count)) }
        let repository = session.repository

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = failure.title
        alert.informativeText = AppLocalization.text("branch.forceDelete.ask", names.joined(separator: ", "))
            + "\n\n" + failure.context
        alert.addButton(withTitle: AppLocalization.text("branch.forceDelete.submit"))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))
        alert.buttons.first?.hasDestructiveAction = true

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 140))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.isRichText = false
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.textColor = .secondaryLabelColor
        text.textContainerInset = NSSize(width: 8, height: 8)
        text.autoresizingMask = [.width]
        text.string = failure.details
        text.setAccessibilityLabel(AppLocalization.text("error.details"))
        scroll.documentView = text
        alert.accessoryView = scroll

        // 询问结束后才开始强制删除，进度与失败由仓库视图承接
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn, session.repository == repository else {
                return
            }

            session.deleteBranches(offer.branches, force: true, deletingUpstream: offer.deletingUpstream)
        }
    }
}
