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

        // 失败后的询问与错误 sheet 一样排队显示，不能因为别的 sheet 而丢掉；询问结束后才开始强制删除
        if case .forceDelete(let offer, let failure) = request {
            DialogWindow.present(on: window) { close in
                Self.forceDeleteBranchesPrompt(offer, failure: failure, in: session, close: close)
            }

            return
        }

        guard session.canWrite else {
            return
        }

        presentDialog { close in
            dialog(for: request, close: close)
        }
    }

    /// 远端视图：所选远端的设置与远端分支。
    func makeRemoteDetailView() -> NSViewController {
        let controller = NSHostingController(rootView: RemoteDetailView(session: session))
        controller.sizingOptions = [.minSize]
        return controller
    }
}

// MARK: - Prompts

extension RepositoryWindowController {
    /// 未合并分支的普通删除失败后询问是否强制删除：标题按分支个数取单复数，说明写出这些分支与仓库。
    ///
    /// - Parameters:
    ///   - offer: 要强制删除的分支。
    ///   - failure: 普通删除的失败，说明里写出它的仓库。
    ///   - session: 确认后在它的仓库里强制删除，进度与失败由仓库视图承接；仓库已切换时不执行。
    ///   - close: 关闭询问。
    static func forceDeleteBranchesPrompt(
        _ offer: ForceDeletionOffer,
        failure: AppFailure,
        in session: RepositorySession,
        close: @escaping () -> Void
    ) -> ConfirmationDialog {
        let names = offer.branches.map { String($0.dropFirst("refs/heads/".count)) }
        let repository = session.repository

        return ConfirmationDialog(
            title: AppLocalization.text(
                names.count == 1 ? "branch.error.delete" : "branch.error.deleteMultiple"
            ),
            message: AppLocalization.text("branch.forceDelete.ask", names.joined(separator: ", "))
                + "\n\n" + failure.context,
            submitTitle: AppLocalization.text("branch.forceDelete.submit"),
            close: close
        ) { [weak session] _ in
            guard let session, session.repository == repository else {
                return
            }

            session.deleteBranches(offer.branches, force: true, deletingUpstream: offer.deletingUpstream)
        }
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

        case .createTag(let revision, let name):
            AnyView(CreateTagDialog(session: session, revision: revision, initialName: name, close: close))

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
}
