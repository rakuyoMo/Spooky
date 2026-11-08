import AppKit
import SpookyKit
import SwiftUI

// MARK: - Branch Menu

extension RepositorySidebarView {
    /// 分支的右键菜单：点在全是本地分支的多选里时作用于整个选区，否则按本地分支与远端分支各一组。
    ///
    /// 各项都作用于被点击的分支或所选的这组分支，不借用 HEAD 或旧的选区。
    @ViewBuilder
    func branchMenu(_ ref: RepositoryReference) -> some View {
        let selected = session.history.branches.filter { session.history.selectedReferences.contains($0.id) }

        if selected.count > 1, selected.contains(where: { $0.id == ref.id }), selected.allSatisfy(\.isLocal) {
            multipleBranchItems(selected)
        } else if ref.isLocal {
            localBranchMenu(ref)
        } else {
            remoteBranchMenu(ref)
        }
    }

    /// 多个本地分支：置顶、归档与删除各一组，删除的标题写出分支个数。
    @ViewBuilder
    private func multipleBranchItems(_ selected: [RepositoryReference]) -> some View {
        pinMenuItems(selected)

        Divider()

        archiveMenuItems(selected)

        Divider()

        Button(AppLocalization.text("branch.deleteMenu.multiple", selected.count)) {
            delete(selected)
        }
        .disabled(!session.canDelete(selected))
    }

    /// 本地分支：检出与工作树（HEAD 分支没有这一组）；置顶；同步、发布与推送；新建分支与请求；
    /// HEAD 分支的合并与变基、父分支两项；归档；删除与引用管理；最后是导出、比较与在历史中显示。
    @ViewBuilder
    private func localBranchMenu(_ ref: RepositoryReference) -> some View {
        if ref.name != session.status?.branch.head {
            // 已在别的工作树检出的分支不能在这里检出，换成那个工作树的打开与删除
            if session.worktrees.branchWorktrees[ref.id] == nil {
                Button(AppLocalization.text("branch.checkoutNamed", ref.name)) {
                    session.checkoutBranch(ref, request: request)
                }
                .disabled(!session.canCheckout(ref))
            }

            BranchWorktreeMenuItems(session: session, branch: ref)

            Divider()
        }

        pinMenuItems([ref])

        Divider()

        // 拉取、推送与安全强推，之后另起一组发布与推送到别处；按住 ⌥ 换成快速操作
        BranchSyncMenu(session: session, reference: ref, request: request)

        Divider()

        createBranchItem(ref)

        // 已有打开着的请求时换成显示它
        PullRequestBranchMenuItem(session: session, reference: ref)

        // HEAD 分支的合并与变基，按住 ⌥ 换成快速操作
        BranchIntegrationMenu(session: session, reference: ref, request: request)

        // HEAD 分支设了父分支时可以并入父分支或变基到父分支上
        ParentBranchMenuItems(session: session, reference: ref, request: request)

        Divider()

        archiveMenuItems([ref])

        Divider()

        Button(AppLocalization.text("reference.deleteMenu", ref.name)) {
            delete([ref])
        }
        .disabled(!session.canDelete([ref]))

        BranchManagementMenu(session: session, reference: ref)

        revisionItems(ref)
    }

    /// 远端分支：拉取排第一；跟踪、新建分支与请求；重命名与删除；最后是导出、比较与在历史中显示。
    @ViewBuilder
    private func remoteBranchMenu(_ ref: RepositoryReference) -> some View {
        // 按住 ⌥ 换成把它快速并入 HEAD
        BranchSyncMenu(session: session, reference: ref, request: request)

        Divider()

        Button(AppLocalization.text("branch.trackMenu", ref.name)) {
            request(RepositoryActionRequest(kind: .track, reference: ref.id))
        }
        .disabled(!session.canTrack(ref))

        createBranchItem(ref)

        // 已有打开着的请求时换成显示它
        PullRequestBranchMenuItem(session: session, reference: ref)

        BranchManagementMenu(session: session, reference: ref)

        revisionItems(ref)
    }

    /// 从被点击的分支新建分支。
    private func createBranchItem(_ ref: RepositoryReference) -> some View {
        Button(AppLocalization.text("branch.createFromMenu", ref.name)) {
            request(RepositoryActionRequest(kind: .create, reference: ref.id))
        }
        .disabled(!session.canCreateBranchFromReference)
    }

    /// 菜单末尾两组：从分支导出文件、与其它版本比较；在历史中显示与复制名字。
    @ViewBuilder
    private func revisionItems(_ ref: RepositoryReference) -> some View {
        Divider()

        Button(AppLocalization.text("export.menuFrom", ref.name)) {
            session.onRevisionRequest?(.export(revision: ref.name, paths: [], archive: false))
        }

        Button(AppLocalization.text("branch.compareMenu", ref.name)) {
            session.onRevisionRequest?(.compare(base: ref.name))
        }

        Divider()

        Button(AppLocalization.text("tag.reveal")) {
            session.revealInHistory(ref.objectID)
        }

        Button(AppLocalization.text(ref.isLocal ? "branch.copyName" : "branch.copyRemoteNameMenu")) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(ref.name, forType: .string)
        }
    }

    /// 删除前在对话框里确认，可选同时删除跟踪的远端分支与强制删除。
    private func delete(_ references: [RepositoryReference]) {
        session.requestReference(.deleteBranches(references))
    }
}
