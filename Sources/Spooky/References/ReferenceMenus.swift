import AppKit
import SpookyKit
import SwiftUI

// MARK: - BranchManagementMenu

/// 分支右键菜单里的引用管理项：本地分支与远端分支各有一组。
struct BranchManagementMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 右键的分支。
    let reference: RepositoryReference

    /// 按分支种类选择一组菜单项。
    var body: some View {
        if reference.isLocal {
            LocalBranchManagementMenu(session: session, reference: reference)
        } else {
            RemoteBranchManagementMenu(session: session, reference: reference)
        }
    }
}

// MARK: - LocalBranchManagementMenu

/// 本地分支右键菜单里的引用管理项：快进、跟踪与父分支子菜单、重命名，以及从它新建标签。
private struct LocalBranchManagementMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 右键的本地分支。
    let reference: RepositoryReference

    #warning(
        "TODO: 跟踪与父分支两个子菜单的标题是推断（Tracking、Parent Branch），父分支子菜单只放 Set Parent Branch… 与 Remove Parent Branch。核实方式：右键非 HEAD 的本地分支，比对这两个子菜单的标题与条目；只影响子菜单标题与父分支子菜单的条目。"
    )

    /// 只落后于上游时才有快进；跟踪子菜单在分离 HEAD 时没有可设置的分支。
    var body: some View {
        Divider()

        if session.canFastForward(reference) {
            Button(AppLocalization.text("branch.fastForward", reference.name)) {
                session.fastForward(reference)
            }

            Divider()
        }

        Menu(AppLocalization.text("branch.tracking")) {
            BranchTrackingMenu(session: session, branch: reference)
        }
        .disabled(!session.canManage(reference))

        Menu(AppLocalization.text("branch.parent")) {
            Button(AppLocalization.text("branch.parent.setMenu")) {
                session.requestReference(.setParent(reference))
            }

            Button(AppLocalization.text("branch.parent.remove")) {
                session.removeParent(of: reference)
            }
            .disabled(session.history.snapshot?.metadata(for: reference.id).parent == nil)
        }
        .disabled(!session.canManage(reference))

        Divider()

        Button(AppLocalization.text("reference.renameMenu", reference.name)) {
            session.requestReference(.renameBranch(reference))
        }
        .disabled(!session.canManage(reference))

        Divider()

        Button(AppLocalization.text("tag.createFrom", reference.name)) {
            session.requestReference(.createTag(revision: reference.id))
        }
        .disabled(!session.canCreateTag)
    }
}

// MARK: - BranchTrackingMenu

/// 跟踪子菜单：远端分支与本地分支两组，当前上游打勾；最后一项取消跟踪，没有上游时打勾。
private struct BranchTrackingMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 要设置上游的本地分支。
    let branch: RepositoryReference

    /// 两组分支各带一个不可点的组名。
    var body: some View {
        let branches = session.history.branches

        Text(AppLocalization.text("branch.tracking.remoteBranches"))

        ForEach(branches.filter(\.isRemote)) { candidate($0) }

        Divider()

        Text(AppLocalization.text("branch.tracking.localBranches"))

        ForEach(branches.filter { $0.isLocal && $0.id != branch.id }) { candidate($0) }

        Divider()

        Toggle(
            AppLocalization.text("branch.tracking.remove"),
            isOn: Binding(get: { branch.upstream == nil }, set: { _ in session.unsetUpstream(of: branch) })
        )
    }

    /// 一个候选上游，当前上游打勾。
    private func candidate(_ upstream: RepositoryReference) -> some View {
        Toggle(
            upstream.name,
            isOn: Binding(get: { branch.upstream == upstream.id }, set: { _ in session.setUpstream(upstream, for: branch) })
        )
    }
}

// MARK: - RemoteBranchManagementMenu

/// 远端分支右键菜单里的引用管理项：重命名与删除；多选的都是远端分支时删除全部所选。
private struct RemoteBranchManagementMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 右键的远端分支。
    let reference: RepositoryReference

    /// 重命名只针对右键的分支，删除覆盖多选。
    var body: some View {
        let selected = session.history.branches.filter { session.history.selectedReferences.contains($0.id) }
        let targets = selected.count > 1 && selected.contains(reference) && selected.allSatisfy(\.isRemote)
            ? selected
            : [reference]

        Divider()

        Button(AppLocalization.text("reference.renameMenu", reference.name)) {
            session.requestReference(.renameBranch(reference))
        }
        .disabled(targets.count > 1 || !session.canManage(reference))

        Button(
            targets.count > 1
                ? AppLocalization.text("branch.deleteRemoteMenu.multiple", targets.count)
                : AppLocalization.text("reference.deleteMenu", reference.name)
        ) {
            session.requestReference(.deleteRemoteBranches(targets))
        }
        .disabled(!session.canDeleteRemoteBranches(targets))
    }
}

// MARK: - RemoteManagementMenu

/// 远端右键菜单里的引用管理项：推送全部标签、修改连接地址、删除、重命名与在浏览器中打开。
struct RemoteManagementMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 右键的远端名。
    let remote: String

    /// 各组之间以分隔线隔开。
    var body: some View {
        Divider()

        Button(AppLocalization.text("tag.pushAll", remote)) {
            session.pushAllTags(to: remote)
        }
        .disabled(!session.canWrite || session.tags.isEmpty)

        Divider()

        Button(AppLocalization.text("remote.editConnection")) {
            session.requestReference(.editURL(remote: remote, push: false))
        }
        .disabled(!session.canWrite)

        Divider()

        Button(AppLocalization.text("reference.deleteMenu", remote)) {
            session.requestReference(.deleteRemotes([remote]))
        }
        .disabled(!session.canWrite)

        Button(AppLocalization.text("reference.renameMenu", remote)) {
            session.requestReference(.renameRemote(remote))
        }
        .disabled(!session.canWrite)

        Divider()

        Button(AppLocalization.text("remote.viewInBrowser", remote)) {
            session.openRemoteInBrowser(remote)
        }
    }
}

// MARK: - TagManagementMenu

/// 标签右键菜单里的引用管理项：发布、推送到指定位置与删除；多选的都是标签时删除全部所选。
struct TagManagementMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 右键的标签。
    let reference: RepositoryReference

    /// 推送到指定位置的入口；由推送对话框提供。
    let pushTo: (RepositoryReference) -> Void

    /// 发布与推送一组，删除单独一组。
    var body: some View {
        let selected = session.tags.filter { session.history.selectedReferences.contains($0.id) }
        let targets = selected.count > 1 && selected.contains(reference) ? selected : [reference]

        Button(AppLocalization.text("tag.publishMenu", reference.name)) {
            session.requestReference(.publishTag(reference.name))
        }
        .disabled(!session.canPublishTag)

        Button(AppLocalization.text("tag.pushToMenu", reference.name)) {
            pushTo(reference)
        }
        .disabled(!session.canWrite || session.history.snapshot?.remotes.isEmpty != false)

        Divider()

        Button(
            targets.count > 1
                ? AppLocalization.text("tag.deleteMenu.multiple", targets.count)
                : AppLocalization.text("reference.deleteMenu", reference.name)
        ) {
            session.requestReference(.deleteTags(targets.map(\.name)))
        }
        .disabled(!session.canWrite)
    }
}

// MARK: - AddReferenceMenu

/// 侧边栏底栏 “+” 菜单里的引用管理项：新建标签与添加远端。
struct AddReferenceMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 新建标签在新建分支之后，添加远端单独一组。
    var body: some View {
        Button(AppLocalization.text("tag.createMenu")) {
            session.requestReference(.createTag(revision: nil))
        }
        .disabled(!session.canCreateTag)

        Divider()

        Button(AppLocalization.text("remote.addMenu")) {
            session.requestReference(.addRemote)
        }
        .disabled(!session.canWrite)
    }
}
