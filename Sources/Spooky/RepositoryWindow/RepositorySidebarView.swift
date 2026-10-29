import AppKit
import SpookyKit
import SwiftUI

// MARK: - RepositorySidebarView

/// Workspace、置顶、分支、归档、标签、远端、子模块与工作树各分组，加上活动区与底栏，共用仓库窗口侧边栏。
struct RepositorySidebarView: View {
    /// 侧边栏的分组；分组标题都可以收起。
    enum SidebarGroup: Hashable {
        /// 工作区、历史与储藏入口。
        case workspace

        /// 置顶分支，只在有置顶分支时出现。
        case pinned

        /// 未归档的本地分支。
        case branches

        /// 已归档的本地分支。
        case archived

        /// 标签，默认收起。
        case tags

        /// 远端与远端分支。
        case remotes

        /// 子模块。
        case submodules

        /// 本窗口仓库之外的工作树。
        case worktrees
    }

    /// 置顶分组里的行身份前缀：同一分支在 Branches 分组里还有一行，两行各自高亮。
    static let pinnedRowPrefix = "pinned:"

    /// 远端行的身份前缀：选中远端时主视图显示它的设置。
    static let remoteRowPrefix = "remote:"

    /// 当前窗口会话。
    @Bindable
    var session: RepositorySession

    /// 主视图切换后替换右侧分栏。
    let selectionChanged: () -> Void

    /// 终端入口。
    let openTerminal: () -> Void

    /// 本机 Finder 入口。
    let revealFinder: () -> Void

    /// 复制带主机前缀的路径。
    let copyPath: () -> Void

    /// 多个入口共享同一操作对话框。
    let request: (RepositoryActionRequest) -> Void

    /// 打开全局活动窗口。
    let showActivity: () -> Void

    /// 底栏视图设置菜单写入的偏好；分组与徽标的 `@AppStorage` 读环境里的 `defaultAppStorage`，换用独立偏好域时两处一起换。
    var defaults = UserDefaults.standard

    /// Stashes 入口显示储藏个数。
    @AppStorage(SidebarPreferences.showStashCountKey)
    var showsStashCount = SidebarPreferences.defaultFlag(SidebarPreferences.showStashCountKey)

    /// Workspace 分组显示 Reflog 入口。
    @AppStorage(SidebarPreferences.showReflogKey)
    var showsReflog = SidebarPreferences.defaultFlag(SidebarPreferences.showReflogKey)

    /// 引用按 “/” 折叠成文件夹。
    @AppStorage(SidebarPreferences.groupRefsKey)
    var groupsRefs = SidebarPreferences.defaultFlag(SidebarPreferences.groupRefsKey)

    /// 文件夹排在引用前面。
    @AppStorage(SidebarPreferences.groupedRefsOnTopKey)
    var groupedRefsOnTop = SidebarPreferences.defaultFlag(SidebarPreferences.groupedRefsOnTopKey)

    /// 显示陈旧注记。
    @AppStorage(SidebarPreferences.showStaleInfoKey)
    var showsStaleInfo = SidebarPreferences.defaultFlag(SidebarPreferences.showStaleInfoKey)

    /// 陈旧阈值的月数，原样读出，使用前校验。
    @AppStorage(SidebarPreferences.staleIntervalKey)
    var staleInterval = SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey)

    /// 每个远端显示的远端分支个数，0 表示全部。
    @AppStorage(SidebarPreferences.newestRemoteBranchesKey)
    var newestRemoteBranches = SidebarPreferences.defaultNumber(SidebarPreferences.newestRemoteBranchesKey)

    /// 标签的排列顺序。
    @AppStorage(SidebarPreferences.tagOrderKey)
    var tagOrder = SidebarPreferences.defaultNumber(SidebarPreferences.tagOrderKey)

    /// 显示的标签个数，0 表示全部。
    @AppStorage(SidebarPreferences.newestTagsKey)
    var newestTags = SidebarPreferences.defaultNumber(SidebarPreferences.newestTagsKey)

    /// 收起的分组；Tags 默认收起。
    @State
    var collapsedGroups: Set<SidebarGroup> = [.tags]

    /// 展开的远端与文件夹；默认只展开名为 origin 的远端。
    @State
    var expandedNodes: Set<SidebarNodeID> = [.remote("origin")]

    /// 底栏过滤框的文字。
    @State
    var filterText = ""

    /// 上一次点选的行身份，用来区分置顶分组与 Branches 分组里的同一分支。
    @State
    var rowSelection: Set<String> = []

    /// 正在显示签名弹窗的标签的完整引用名。
    @State
    var signatureTag: String?

    /// 分组顺序固定：Workspace、Pinned、Branches、Archived Branches、Tags、Remotes、Submodules、Worktrees。
    var body: some View {
        VStack(spacing: 0) {
            List(selection: selection) {
                workspace
                pinnedBranches
                localBranches
                archivedBranches
                tags
                remoteBranches
                submoduleGroup
                worktreeGroup
            }
            .listStyle(.sidebar)

            // 刚归档的分支数与撤销
            ArchiveNoticeView(session: session)

            activityRows
            Divider()
            bottomBar
        }
        .onChange(of: session.repository) {
            resetViewState()
        }
    }

    /// Workspace 分组：工作区、历史、储藏、请求、分支整理，视图设置打开 Show Reflog 时的 Reflog，以及仓库设置。
    private var workspace: some View {
        Section(isExpanded: isExpanded(.workspace)) {
            workingCopy
                .tag("workingCopy")
                .modifier(
                    RepositoryDropTarget(session: session, destination: .head, request: request)
                )
            Label(AppLocalization.text("history.title"), systemImage: "clock").tag("history")

            // 工作区文件拖到这里保存部分储藏
            stashes
                .tag("stashes")
                .modifier(StashesDropTarget(session: session))

            // 选中远端对应 GitLab 时叫 Merge Requests
            Label(session.pullRequestText("title"), systemImage: "arrow.triangle.merge")
                .tag("pullRequests")

            Label(AppLocalization.text("review.title"), systemImage: "arrow.triangle.pull")
                .tag("branchesReview")

            // 视图设置打开 Show Reflog 时才显示
            if showsReflog {
                Label(AppLocalization.text("reflog.title"), systemImage: "clock.arrow.circlepath")
                    .tag("reflog")
            }

            Label(AppLocalization.text("repositorySettings.title"), systemImage: "gearshape")
                .tag("settings")
        } header: {
            Text(AppLocalization.text("workspace.group"))
        }
    }

    /// 工作区保留改动数及已有文件操作入口。
    private var workingCopy: some View {
        HStack {
            Label(AppLocalization.text("workspace.title"), systemImage: "folder")
            Spacer(minLength: 4)
            if session.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(AppLocalization.text("loading.status"))
            } else if let status = session.status {
                Text(status.entries.count.formatted())
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppPalette.color("sidebarBadgeBackgroundColor"), in: Capsule())
                    .accessibilityLabel(AppLocalization.text("workspace.changed", status.entries.count))
            }
        }
        .contextMenu {
            Button(AppLocalization.text("sync.pull")) { request(RepositoryActionRequest(kind: .pull)) }
                .disabled(!session.canPull)
            Button(AppLocalization.text("sync.push")) { request(RepositoryActionRequest(kind: .push)) }
                .disabled(!session.canPush)
            Button(AppLocalization.text("sync.publish")) { request(RepositoryActionRequest(kind: .publish)) }
                .disabled(!session.canPublish)
            Button(AppLocalization.text("sync.merge")) { request(RepositoryActionRequest(kind: .merge)) }
                .disabled(!session.canMerge)
            Divider()
            Button(AppLocalization.text("working.discardAll")) {
                session.discard(session.status?.entries ?? [])
            }
            .disabled(!session.canDiscard(session.status?.entries ?? []))
            Divider()
            Button(AppLocalization.text("action.openTerminal"), action: openTerminal)
            Button(AppLocalization.text("action.revealFinder"), action: revealFinder)
                .disabled(session.repository?.localURL == nil)
            Button(AppLocalization.text("action.copyPath"), action: copyPath)
        }
    }

    /// 储藏入口；视图设置打开时带储藏个数，样式与工作区的改动数相同。
    private var stashes: some View {
        HStack {
            Label(AppLocalization.text("stash.title"), systemImage: "tray.full")
            Spacer(minLength: 4)

            if showsStashCount, session.stashes.isLoaded {
                Text(session.stashes.entries.count.formatted())
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppPalette.color("sidebarBadgeBackgroundColor"), in: Capsule())
                    .accessibilityLabel(AppLocalization.text("stash.count", session.stashes.entries.count))
            }
        }
    }

    /// 本仓库本次运行里最近三个远程操作，显示持续进度和取消，点击打开完整日志；从本机读回的记录不列。
    private var activityRows: some View {
        let items = RepositoryActivities.shared.items.filter { activity in
            activity.kind == .remote
                && !activity.isRestored
                && activity.repository == session.repository
        }

        return VStack(spacing: 0) {
            ForEach(Array(items.prefix(3))) { activity in
                HStack {
                    Button(action: showActivity) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.title).font(.system(size: 11, weight: .semibold))
                            Text(AppLocalization.text(activity.state)).font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            if activity.cancel != nil { ProgressView().controlSize(.mini) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    if let cancel = activity.cancel {
                        Button(action: cancel) { Image(systemName: "stop.circle") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(AppLocalization.text("action.cancel"))
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 65)
                Divider()
            }
        }
    }

    /// 侧边栏底栏：左侧过滤框，右侧新建分支菜单与视图设置按钮。
    private var bottomBar: some View {
        HStack(spacing: 4) {
            SidebarFilterField(text: $filterText)

            Spacer(minLength: 8)

            // 自动归档关闭且有建议归档的分支时显示
            ArchiveFooterButton(session: session)

            Menu {
                Button(AppLocalization.text("branch.create")) {
                    request(RepositoryActionRequest(kind: .create))
                }
                .disabled(!session.canCreateBranch)
                AddReferenceMenu(session: session)
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(AppLocalization.text("reference.addMenu"))

            SidebarViewSettingsButton(defaults: defaults)
                .frame(width: 22, height: 20)
        }
        .padding(.horizontal, 4)
        .frame(height: 40)
    }
}

// MARK: - Selection

extension RepositorySidebarView {
    /// 系统列表和菜单导航使用同一组选择身份。
    private var selectedItems: Set<String> {
        if session.activeView == .workingCopy { return ["workingCopy"] }
        if session.activeView == .stashes { return ["stashes"] }
        if session.activeView == .pullRequests { return ["pullRequests"] }
        if session.activeView == .branchesReview { return ["branchesReview"] }
        if session.activeView == .reflog { return ["reflog"] }
        if session.activeView == .settings { return ["settings"] }

        // 远端设置对应侧边栏里那个远端的行，子模块视图对应那个子模块的行
        if session.activeView == .remote {
            return session.selectedRemote.map { [Self.remoteRowPrefix + $0] } ?? []
        }

        if session.activeView == .submodule {
            return session.submodules.selectedPath.map { [Self.submoduleRowPrefix + $0] } ?? []
        }

        if session.activeView == .worktree {
            return session.worktrees.selectedPath.map { [Self.worktreeRowPrefix + $0] } ?? []
        }

        // 文件视图不对应侧边栏的任何一项，点 Working Copy 或 History 都能离开
        if [.fileHistory, .fileContent].contains(session.activeView) { return [] }

        let references = session.history.selectedReferences

        if references.isEmpty { return ["history"] }

        // 选择来自点选时沿用点中的行；从菜单或其它视图改变选择时用分支在主分组里的行
        return Set(rowSelection.map(Self.reference(forRow:))) == references ? rowSelection : references
    }

    /// 选择存入会话，快捷键与点击保持一致。
    private var selection: Binding<Set<String>> {
        Binding(
            get: { selectedItems },
            set: { value in
                guard !value.isEmpty else { return }

                let added = value.subtracting(selectedItems)

                // 远端、子模块与工作树的行各自换成设置视图，不参与引用的多选
                guard !selectSettingsRow(in: added) else { return }

                rowSelection = value
                session.history.showsCommitPage = false

                if let view = Self.workspaceView(added: added, value: value) {
                    session.activeView = view

                    // 请求视图第一次显示时读取
                    if view == .pullRequests, !session.pullRequests.isLoaded {
                        session.reloadPullRequests()
                    }
                } else {
                    // 置顶分组里的行换回分支的完整引用名
                    let references = value
                        .subtracting(Self.workspaceRows.map(\.row) + ["history"])
                        .filter { row in
                            ![Self.remoteRowPrefix, Self.submoduleRowPrefix, Self.worktreeRowPrefix]
                                .contains { row.hasPrefix($0) }
                        }
                        .map(Self.reference(forRow:))

                    session.activeView = .history
                    session.history.selectedReferences =
                        added.contains("history") || value == ["history"] ? [] : Set(references)
                }

                selectionChanged()
            }
        )
    }

    /// 选中远端、子模块或工作树的行：主视图换成远端的设置、子模块的状态与配置或工作树的详情；返回是否已处理。
    private func selectSettingsRow(in added: Set<String>) -> Bool {
        if let remote = added.first(where: { $0.hasPrefix(Self.remoteRowPrefix) }) {
            rowSelection = [remote]
            session.showRemote(String(remote.dropFirst(Self.remoteRowPrefix.count)))
            return true
        }

        if let submodule = added.first(where: { $0.hasPrefix(Self.submoduleRowPrefix) }) {
            rowSelection = [submodule]
            session.showSubmodule(String(submodule.dropFirst(Self.submoduleRowPrefix.count)))
            return true
        }

        if let worktree = added.first(where: { $0.hasPrefix(Self.worktreeRowPrefix) }) {
            rowSelection = [worktree]
            session.showWorktree(String(worktree.dropFirst(Self.worktreeRowPrefix.count)))
            return true
        }

        return false
    }
}

// MARK: - Rows

extension RepositorySidebarView {
    /// 一个远端下的远端分支行：双击检出，接受本地分支拖入以推送。
    @ViewBuilder
    func remoteBranchRows(_ remote: RepositoryRemote) -> some View {
        let nodes = remoteBranchNodes(remote)

        if nodes.isEmpty, !isFiltering {
            Text(AppLocalization.text("branch.empty")).foregroundStyle(.secondary)
        }

        SidebarRefTreeView(nodes: nodes, isExpanded: isExpanded) { node in
            if let ref = node.reference {
                branchRow(ref, name: node.name)
                    .tag(ref.id)
                    .onTapGesture(count: 2) {
                        session.checkoutBranch(ref, request: request)
                    }
                    .onDrag { dragProvider(kind: .remote, reference: ref.id) }
                    .contextMenu { branchMenu(ref) }
                    .modifier(
                        RepositoryDropTarget(
                            session: session,
                            destination: .remoteBranch(remote.name, ref.id),
                            request: request
                        )
                    )
            }
        } folder: { node in
            folderLabel(node, destination: .remoteBranchFolder(remote.name, node.path))
        }
    }

    /// 远端名称行：右键获取或清理，按住 ⌥ 换成快速获取；接受本地分支拖入以发布分支、标签拖入以发布标签。
    func remoteLabel(_ remote: RepositoryRemote) -> some View {
        Label(remote.name, systemImage: "network")
            .contextMenu {
                Button(AppLocalization.text("sync.fetch")) {
                    request(RepositoryActionRequest(kind: .fetch, remote: remote.name))
                }
                .disabled(!session.canFetch)
                .quickAlternate(AppLocalization.text("sync.quickFetchNamed", remote.name), enabled: session.canFetch) {
                    session.quickFetch(remote: remote.name)
                }

                Button(AppLocalization.text("sync.prune")) {
                    request(
                        RepositoryActionRequest(kind: .fetch, remote: remote.name, prune: true)
                    )
                }
                .disabled(!session.canFetch)
                RemoteManagementMenu(session: session, remote: remote.name)
            }
            .modifier(
                RepositoryDropTarget(
                    session: session,
                    destination: .remote(remote.name),
                    request: request
                )
            )
    }

    /// 本地分支带胶囊徽标、陈旧与跟踪错误注记和逐行的悬停提示；远端分支只带默认分支标记。
    func branchRow(_ ref: RepositoryReference, name: String) -> SidebarBranchRow {
        let host = session.repository?.host

        guard ref.isLocal else {
            return SidebarBranchRow(
                name: name,
                symbol: "network",
                isDefault: isDefaultBranch(ref),
                help: SidebarTooltip.remoteBranch(ref, host: host)
            )
        }

        let metadata = session.history.snapshot?.metadata(for: ref.id) ?? BranchMetadata()
        let status = branchStatus(ref)

        // 已在别的工作树检出的分支换成工作树图标
        let symbol =
            session.worktrees.branchWorktrees[ref.id] != nil
                ? "rectangle.on.rectangle"
                : (metadata.isArchived ? "archivebox" : "arrow.triangle.branch")

        return SidebarBranchRow(
            name: name,
            symbol: symbol,
            badge: badge(ref),
            status: status,
            help: SidebarTooltip.branch(
                ref,
                host: host,
                divergence: session.history.divergence[ref.id],
                metadata: metadata,
                status: status
            )
        )
    }

    /// 分支菜单只包含已经实现的动作。
    @ViewBuilder
    func branchMenu(_ ref: RepositoryReference) -> some View {
        let selected = session.history.branches.filter { session.history.selectedReferences.contains($0.id) }
        if selected.count > 1, selected.contains(where: { $0.id == ref.id }), selected.allSatisfy(\.isLocal) {
            pinMenuItems(selected)
            Divider()
            archiveMenuItems(selected)
            Divider()
            Button(AppLocalization.text("branch.deleteMultiple")) { delete(selected) }
                .disabled(!session.canDelete(selected))
        } else {
            if ref.isLocal {
                // 已在别的工作树检出的分支不能在这里检出，换成那个工作树的打开与删除
                if session.worktrees.branchWorktrees[ref.id] == nil {
                    Button(AppLocalization.text("branch.checkout")) { session.checkoutBranch(ref, request: request) }
                        .disabled(!session.canCheckout(ref))
                }

                BranchWorktreeMenuItems(session: session, branch: ref)
                Divider()
                pinMenuItems([ref])
                Divider()
                Button(AppLocalization.text("sync.publish")) {
                    request(RepositoryActionRequest(kind: .publish, localBranch: ref.name))
                }
                .disabled(!session.canPush(ref))

                // 推送、拉取与同步，按住 ⌥ 换成快速操作
                BranchSyncMenu(session: session, reference: ref, request: request)
            } else {
                Button(AppLocalization.text("branch.track")) {
                    request(RepositoryActionRequest(kind: .track, reference: ref.id))
                }
                .disabled(!session.canTrack(ref))

                BranchSyncMenu(session: session, reference: ref, request: request)
            }
            Button(AppLocalization.text("branch.create")) {
                request(RepositoryActionRequest(kind: .create, reference: ref.id))
            }
            .disabled(!session.canCreateBranchFromReference)

            // 已有打开着的请求时换成显示它
            PullRequestBranchMenuItem(session: session, reference: ref)

            // 合并与变基，按住 ⌥ 换成快速操作
            BranchIntegrationMenu(session: session, reference: ref, request: request)

            // HEAD 分支设了父分支时可以并入父分支或变基到父分支上
            ParentBranchMenuItems(session: session, reference: ref, request: request)
            if ref.isLocal {
                Divider()
                archiveMenuItems([ref])
                Divider()
                Button(AppLocalization.text("branch.delete")) { delete([ref]) }
                    .disabled(!session.canDelete([ref]))
            }
            BranchManagementMenu(session: session, reference: ref)
            Divider()
            Button(AppLocalization.text("branch.copyName")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ref.name, forType: .string)
            }
        }
    }

    /// 拖动开始时仓库仍在显示才提供载荷；仓库刚关闭时返回空的拖动内容。
    func dragProvider(kind: RepositoryDragPayload.Kind, reference: String) -> NSItemProvider {
        guard let repository = session.repository else {
            return NSItemProvider()
        }

        return RepositoryDragPayload(repository: repository, kind: kind, reference: reference).provider()
    }
}

// MARK: - Actions

extension RepositorySidebarView {
    /// 删除前在对话框里确认，可选同时删除跟踪的远端分支与强制删除。
    private func delete(_ references: [RepositoryReference]) {
        session.requestReference(.deleteBranches(references))
    }
}

// MARK: - Workspace Rows

extension RepositorySidebarView {
    /// Workspace 分组里换主视图的行与对应的视图，按判断的先后排列；History 另行处理。
    fileprivate static let workspaceRows: [(row: String, view: RepositoryView)] = [
        ("workingCopy", .workingCopy),
        ("stashes", .stashes),
        ("pullRequests", .pullRequests),
        ("branchesReview", .branchesReview),
        ("reflog", .reflog),
        ("settings", .settings),
    ]

    /// 新选中的 Workspace 行对应的视图；选的是 History 或引用时为 nil。
    fileprivate static func workspaceView(added: Set<String>, value: Set<String>) -> RepositoryView? {
        workspaceRows.first { added.contains($0.row) || value == [$0.row] }?.view
    }
}
