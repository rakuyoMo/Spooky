import SpookyKit
import SwiftUI

// MARK: - WorkingCopyMenu

/// 侧边栏 Working Copy 行的右键菜单：检出、快照、推送与拉取、丢弃与重置、合并与变基、比较，以及路径与工具七组。
///
/// 各项复用已有的动作与确认，可用性取会话的规则；按住 ⌥ 的快速版本以 HEAD 和它的跟踪分支为对象，没有跟踪分支时不提供。
struct WorkingCopyMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 打开推送、拉取与合并的参数对话框。
    let request: (RepositoryActionRequest) -> Void

    /// 复制仓库路径。
    let copyPath: () -> Void

    /// 在 Finder 中显示仓库。
    let revealFinder: () -> Void

    /// 在终端中打开仓库。
    let openTerminal: () -> Void

    /// 七组之间各一条分隔线。
    var body: some View {
        checkoutMenu

        Divider()

        snapshotItem

        Divider()

        syncItems

        Divider()

        discardItems

        Divider()

        integrationItems

        Divider()

        compareMenu

        Divider()

        toolItems
    }
}

// MARK: - Groups

extension WorkingCopyMenu {
    /// Check Out 子菜单：按公共顺序列出全部本地分支，HEAD 分支打勾；分隔线后是检出任意版本。
    private var checkoutMenu: some View {
        Menu(AppLocalization.text("workspace.checkoutMenu")) {
            let head = session.headBranch?.id
            let branches = session.history.branches.filter(\.isLocal)

            ForEach(ReferenceOrder.sorted(branches, in: session.history.snapshot)) { branch in
                if branch.id == head {
                    Toggle(branch.name, isOn: .constant(true))
                } else {
                    Button(branch.name) {
                        session.checkoutBranch(branch, request: request)
                    }
                    .disabled(!session.canCheckout(branch))
                }
            }

            Divider()

            Button(AppLocalization.text("workspace.checkoutRevisionMenu")) {
                session.requestCheckout()
            }
            .disabled(!session.canCheckoutRevision)
        }
    }

    /// 创建快照，按住 ⌥ 换成不经对话框的快速快照。
    private var snapshotItem: some View {
        Button(AppLocalization.text("stash.snapshotMenu")) {
            session.requestSaveStash(snapshot: true)
        }
        .disabled(!session.canSaveStash)
        .quickAlternate(
            AppLocalization.text("stash.quickSnapshotMenu"),
            enabled: session.canSaveStash
        ) {
            session.requestSaveStash(snapshot: true, quick: true)
        }
    }

    /// 推送、推送任意版本、拉取与发布仓库；推送与拉取按住 ⌥ 换成以 HEAD 和跟踪分支为对象的快速版本。
    @ViewBuilder
    private var syncItems: some View {
        let head = session.headBranch
        let upstream = head.flatMap(session.upstreamName(of:))

        Button(AppLocalization.text("workspace.pushMenu")) {
            request(RepositoryActionRequest(kind: .push))
        }
        .disabled(!session.canPushHead)
        .quickAlternate(
            quickTitle("sync.quickPushNamed", head?.name, upstream),
            enabled: head.map(session.canQuickPush) ?? false
        ) {
            session.quickPush(head)
        }

        Button(AppLocalization.text("workspace.pushRevisionMenu")) {
            session.requestSyncDialog(.pushRevision)
        }
        .disabled(!session.canPushRevision)

        Button(AppLocalization.text("sync.pullMenu")) {
            request(RepositoryActionRequest(kind: .pull))
        }
        .disabled(!session.canPull)
        .quickAlternate(
            quickTitle("sync.quickPullInto", upstream, head?.name),
            enabled: session.canPull
        ) {
            session.quickPull()
        }

        // 发布整个仓库：新建托管仓库，推送全部本地分支与标签
        Button(AppLocalization.text("workspace.publishMenu")) {
            session.requestPullRequest(.publish)
        }
        .disabled(!session.canPublishRepository)
    }

    /// 丢弃全部本地改动与重置 HEAD 到某个版本，都先经确认或参数对话框。
    @ViewBuilder
    private var discardItems: some View {
        let entries = session.status?.entries ?? []

        Button(AppLocalization.text("working.discardAllMenu")) {
            session.discard(entries, all: true)
        }
        .disabled(!session.canDiscard(entries))

        Button(AppLocalization.text("workspace.resetMenu")) {
            session.requestReset()
        }
        .disabled(!session.canRewrite)
    }

    /// 合并、变基与应用补丁；合并与变基按住 ⌥ 换成以 HEAD 的跟踪分支为对象的快速版本。
    @ViewBuilder
    private var integrationItems: some View {
        let head = session.status?.branch.head
        let upstream = session.headBranch.flatMap(session.upstreamName(of:))

        Button(AppLocalization.text("workspace.mergeMenu")) {
            request(RepositoryActionRequest(kind: .merge))
        }
        .disabled(!session.canMerge)
        .quickAlternate(
            quickTitle("sync.quickMergeInto", upstream, head),
            enabled: session.canMerge
        ) {
            session.quickMerge()
        }

        Button(AppLocalization.text("workspace.rebaseMenu")) {
            session.requestSyncDialog(.rebase)
        }
        .disabled(!session.canRebase)
        .quickAlternate(
            quickTitle("sync.quickRebaseOn", head, upstream),
            enabled: session.canRebase
        ) {
            session.quickRebase()
        }

        Button(AppLocalization.text("files.applyPatch.menu")) {
            session.onFileRequest?(.form(.applyPatch))
        }
        .disabled(!session.canWrite)
    }

    /// Compare 子菜单：用比较工具比较整个工作区的工作区、暂存区与 HEAD 版本。
    private var compareMenu: some View {
        Menu(AppLocalization.text("externalTool.compare")) {
            let entries = session.status?.entries ?? []
            let comparisons = WorkingCopyComparison.allCases.filter { !$0.isConflictComparison }

            ForEach(comparisons, id: \.self) { comparison in
                Button(AppLocalization.text(comparison.titleKey)) {
                    session.compare(entries, comparison)
                }
                .disabled(!session.canCompare(entries, comparison))
            }
        }
    }

    /// 复制路径、在 Finder 中显示与在终端中打开。
    @ViewBuilder
    private var toolItems: some View {
        Button(AppLocalization.text("workspace.copyPathMenu"), action: copyPath)

        // 服务器仓库没有本机映射时不可用，悬停说明原因
        Button(AppLocalization.text("action.revealFinder"), action: revealFinder)
            .disabled(!session.canShowInFinder)
            .help(session.finderUnavailableTip ?? "")

        Button(AppLocalization.text("action.openTerminal"), action: openTerminal)
    }
}

// MARK: - Private

extension WorkingCopyMenu {
    /// 快速版本的标题，两个名字依次填入；HEAD 不是分支或没有跟踪分支时为 nil，不提供快速版本。
    private func quickTitle(_ key: String, _ first: String?, _ second: String?) -> String? {
        guard let first, let second else {
            return nil
        }

        return AppLocalization.text(key, first, second)
    }
}
