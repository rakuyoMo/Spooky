import AppKit
import SpookyKit
import SwiftUI

// MARK: - BranchMenu

/// 分支的右键菜单，侧边栏与分支整理共用：一个本地分支或远端分支各有一份完整菜单，多个本地分支只有置顶、归档与删除。
struct BranchMenu: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 菜单作用的分支：一个，或同一选区里的多个本地分支。
    let references: [RepositoryReference]

    /// 参数表单入口。
    let request: (RepositoryActionRequest) -> Void

    /// 置顶或取消置顶写入之前的回调；侧边栏用它展开分支要去的分组。
    var willSetPinned: (Bool, [RepositoryReference]) -> Void = { _, _ in }

    /// 按分支的个数与种类选菜单。
    var body: some View {
        if references.count > 1 {
            multipleBranchItems(references)
        } else if let reference = references.first {
            if reference.isLocal {
                localBranchMenu(reference)
            } else {
                remoteBranchMenu(reference)
            }
        }
    }
}

// MARK: - Private

extension BranchMenu {
    /// 置顶菜单项：一个分支时写出名字；多个分支时全部未置顶给 Pin、全部已置顶给 Unpin，混合时不给。
    @ViewBuilder
    private func pinMenuItems(_ branches: [RepositoryReference]) -> some View {
        let pinned = branches.map { metadata($0).isPinned }

        if !pinned.contains(true) {
            Button(flagTitle(branches, single: "branch.pinNamed", multiple: "branch.pinMultiple")) {
                setPinned(true, branches)
            }
            .disabled(!session.canSetPinned(branches))
        } else if !pinned.contains(false) {
            Button(flagTitle(branches, single: "branch.unpinNamed", multiple: "branch.unpinMultiple")) {
                setPinned(false, branches)
            }
            .disabled(!session.canSetPinned(branches))
        }
    }

    /// 归档菜单项：规则与置顶相同；一个分支时其下还有 “自动归档时跳过” 勾选项。
    @ViewBuilder
    private func archiveMenuItems(_ branches: [RepositoryReference]) -> some View {
        let archived = branches.map { metadata($0).isArchived }

        if !archived.contains(true) {
            Button(flagTitle(branches, single: "branch.archiveNamed", multiple: "branch.archiveMultiple")) {
                session.setArchived(true, branches: branches)
            }
            .disabled(!session.canSetArchived(branches))
        } else if !archived.contains(false) {
            Button(flagTitle(branches, single: "branch.unarchiveNamed", multiple: "branch.unarchiveMultiple")) {
                session.setArchived(false, branches: branches)
            }
            .disabled(!session.canSetArchived(branches))
        }

        if branches.count == 1, let branch = branches.first {
            BranchArchiveOptions(session: session, branch: branch, metadata: metadata(branch))
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

    /// 本地分支：检出与工作树（HEAD 分支没有这一组）；置顶；同步；发布与推送；跟踪的上游与父分支；
    /// HEAD 分支的合并与变基；归档；重命名与删除；新建分支、标签与请求；最后是导出、比较与在历史中显示。
    @ViewBuilder
    private func localBranchMenu(_ ref: RepositoryReference) -> some View {
        let isHead = ref.name == session.status?.branch.head

        if !isHead {
            // 已在别的工作树检出的分支不能在这里检出，换成那个工作树的打开与删除
            if session.worktrees.branchWorktrees[ref.id] == nil {
                Button(AppLocalization.text("branch.checkoutNamed", ref.name)) {
                    session.checkoutBranch(ref)
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

        BranchUpstreamMenus(session: session, reference: ref)

        if isHead {
            Divider()

            // 合并与变基，按住 ⌥ 换成快速操作；设了父分支时还可以并入父分支或变基到父分支上
            BranchIntegrationMenu(session: session, reference: ref, request: request)

            ParentBranchMenuItems(session: session, reference: ref, request: request)
        }

        Divider()

        archiveMenuItems([ref])

        Divider()

        Button(AppLocalization.text("reference.renameMenu", ref.name)) {
            session.requestReference(.renameBranch(ref))
        }
        .disabled(!session.canManage(ref))

        Button(AppLocalization.text("reference.deleteMenu", ref.name)) {
            delete([ref])
        }
        .disabled(!session.canDelete([ref]))

        Divider()

        createBranchItem(ref)

        Button(AppLocalization.text("tag.createFrom", ref.name)) {
            session.requestReference(.createTag(revision: ref.id))
        }
        .disabled(!session.canCreateTag)

        // 已有打开着的请求时换成显示它
        PullRequestBranchMenuItem(session: session, reference: ref)

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

        RemoteBranchManagementMenu(session: session, reference: ref)

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

    /// 一个分支的标题带名字，多个分支的标题带个数。
    private func flagTitle(_ branches: [RepositoryReference], single: String, multiple: String) -> String {
        guard branches.count > 1 else {
            return AppLocalization.text(single, branches.first?.name ?? "")
        }

        return AppLocalization.text(multiple, branches.count)
    }

    /// 先交给回调，再写入置顶。
    private func setPinned(_ pinned: Bool, _ branches: [RepositoryReference]) {
        willSetPinned(pinned, branches)
        session.setPinned(pinned, branches: branches)
    }

    /// 本地分支的附加信息；没有记录时是默认值。
    private func metadata(_ reference: RepositoryReference) -> BranchMetadata {
        session.history.snapshot?.metadata(for: reference.id) ?? BranchMetadata()
    }
}
