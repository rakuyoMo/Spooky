import SpookyKit
import SwiftUI

// MARK: - BranchSyncMenu

/// 分支右键菜单里的推送与拉取一组；按住 ⌥ 时换成跳过对话框的快速操作。
///
/// HEAD 分支是 Push、Pull 与 Sync，快速版本以它的跟踪分支为对象，没有跟踪分支时不提供；
/// 其它本地分支是 Push 与 Push “X” To…；远端分支是 Pull，快速版本把它并入 HEAD。
struct BranchSyncMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 右键的分支。
    let reference: RepositoryReference

    /// 打开推送、拉取等参数对话框。
    let request: (RepositoryActionRequest) -> Void

    /// 按分支种类选择一组菜单项。
    var body: some View {
        if reference.isRemote {
            Button(AppLocalization.text("sync.pull")) {
                request(RepositoryActionRequest(kind: .pull, reference: reference.id))
            }
            .disabled(!session.canPull(from: reference))
            .quickAlternate(
                AppLocalization.text("sync.quickPullNamed", reference.name),
                enabled: session.canPull(from: reference)
            ) {
                session.quickPull(from: reference)
            }
        } else if reference.name == session.status?.branch.head {
            headItems
        } else {
            push

            Button(AppLocalization.text("branch.pushToMenu", reference.name)) {
                session.requestSyncDialog(.pushRevision, preselecting: reference.name)
            }
            .disabled(!session.canPushRevision)
        }
    }

    /// HEAD 分支：推送、拉取与同步，各带以跟踪分支为对象的快速版本。
    @ViewBuilder
    private var headItems: some View {
        let upstream = session.upstreamName(of: reference)

        push
            .quickAlternate(
                upstream.map { AppLocalization.text("sync.quickPushNamed", reference.name, $0) },
                enabled: session.canQuickPush(reference)
            ) {
                session.quickPush(reference)
            }

        Button(AppLocalization.text("sync.pull")) {
            request(RepositoryActionRequest(kind: .pull))
        }
        .disabled(!session.canPull)
        .quickAlternate(
            upstream.map { AppLocalization.text("sync.quickPullInto", $0, reference.name) },
            enabled: session.canPull
        ) {
            session.quickPull()
        }

        Button(AppLocalization.text("sync.syncMenu")) {
            session.requestSyncDialog(.sync)
        }
        .disabled(!session.canSync)
        .quickAlternate(
            upstream.map { AppLocalization.text("sync.quickSyncNamed", reference.name, $0) },
            enabled: session.canQuickPush(reference) && session.canSync
        ) {
            session.quickSync()
        }
    }

    /// 推送这个本地分支的对话框。
    private var push: some View {
        Button(AppLocalization.text("sync.push")) {
            request(RepositoryActionRequest(kind: .push, localBranch: reference.name))
        }
        .disabled(!session.canPush(reference))
    }
}

// MARK: - BranchIntegrationMenu

/// 分支右键菜单里的合并与变基一组；按住 ⌥ 时换成跳过对话框的快速操作。
///
/// HEAD 分支是 Merge、Rebase 与 Rebase Onto，快速版本以它的跟踪分支为对象，没有跟踪分支时不提供；
/// 其它分支是把它并入 HEAD 的 Merge 与把 HEAD 变基到它上面的 Rebase On “X”…。
struct BranchIntegrationMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 右键的分支。
    let reference: RepositoryReference

    /// 打开合并的参数对话框。
    let request: (RepositoryActionRequest) -> Void

    /// HEAD 分支与其它分支各有一组。
    var body: some View {
        if let head = session.status?.branch.head, reference.isLocal, reference.name == head {
            headItems(head)
        } else {
            otherItems
        }
    }

    /// 其它分支：并入 HEAD，或把 HEAD 变基到它上面；分离或未出生时没有快速版本。
    @ViewBuilder
    private var otherItems: some View {
        let head = session.status?.branch.head
        let canRebase = session.canRebase && session.canMerge(reference)

        Button(AppLocalization.text("sync.merge")) {
            request(RepositoryActionRequest(kind: .merge, reference: reference.id))
        }
        .disabled(!session.canMerge(reference))
        .quickAlternate(
            head.map { AppLocalization.text("sync.quickMergeInto", reference.name, $0) },
            enabled: session.canMerge(reference)
        ) {
            session.quickMerge(reference)
        }

        Button(AppLocalization.text("sync.rebaseOnNamed", reference.name)) {
            session.requestSyncDialog(.rebase, preselecting: reference.id)
        }
        .disabled(!canRebase)
        .quickAlternate(
            head.map { AppLocalization.text("sync.quickRebaseOn", $0, reference.name) },
            enabled: canRebase
        ) {
            session.quickRebase(onto: reference)
        }
    }

    /// HEAD 分支：选版本合并、选分支变基与变基到别处。
    @ViewBuilder
    private func headItems(_ head: String) -> some View {
        let upstream = session.upstreamName(of: reference)

        Button(AppLocalization.text("sync.merge")) {
            request(RepositoryActionRequest(kind: .merge))
        }
        .disabled(!session.canMerge)
        .quickAlternate(
            upstream.map { AppLocalization.text("sync.quickMergeInto", $0, head) },
            enabled: session.canMerge
        ) {
            session.quickMerge()
        }

        Button(AppLocalization.text("sync.rebaseMenu")) {
            session.requestSyncDialog(.rebase)
        }
        .disabled(!session.canRebase)
        .quickAlternate(
            upstream.map { AppLocalization.text("sync.quickRebaseOn", head, $0) },
            enabled: session.canRebase
        ) {
            session.quickRebase()
        }

        Button(AppLocalization.text("rewrite.rebaseOnto.menu")) {
            session.requestRebaseOnto()
        }
        .disabled(!session.canRewrite)
    }
}

// MARK: - Quick Alternates

extension RepositorySession {
    /// 本地分支跟踪的分支的显示名，如 `origin/main`；没有跟踪分支时为 nil。
    func upstreamName(of branch: RepositoryReference) -> String? {
        guard let upstream = branch.upstream else {
            return nil
        }

        return history.snapshot?.references.first { $0.id == upstream }?.name ?? upstream
    }

    /// 快速推送需要可推送的本地分支，且它跟踪远端上的分支。
    func canQuickPush(_ branch: RepositoryReference) -> Bool {
        guard canPush(branch), let remote = branch.upstreamRemote, remote != "." else {
            return false
        }

        return branch.upstreamBranch?.hasPrefix("refs/heads/") ?? false
    }
}

extension View {
    /// 按住 ⌥ 时把这一项换成跳过对话框的快速操作；标题为 nil 时没有备选项。
    @ViewBuilder
    func quickAlternate(_ title: String?, enabled: Bool, perform: @escaping () -> Void) -> some View {
        if let title {
            modifierKeyAlternate(.option) {
                Button(title, action: perform)
                    .disabled(!enabled)
            }
        } else {
            self
        }
    }
}
