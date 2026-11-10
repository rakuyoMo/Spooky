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

    /// 远端行的身份前缀：选中远端时主视图显示它的设置。
    static let remoteRowPrefix = "remote:"

    /// 当前窗口会话。
    @Bindable
    var session: RepositorySession

    /// 主视图切换后替换右侧分栏。
    let selectionChanged: () -> Void

    /// 终端入口。
    let openTerminal: () -> Void

    /// Finder 入口；服务器仓库打开它在这台 Mac 上的挂载位置。
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

    /// 正在显示签名弹窗的标签的完整引用名。
    @State
    var signatureTag: String?

    /// 各远端的设置，按远端名索引，供远端行的悬停提示写出获取与推送地址；远端的设置变化后重新读取。
    @State
    var remoteConfigurations: [String: RemoteConfiguration] = [:]

    /// 列表有键盘焦点。
    @FocusState
    var listFocused: Bool

    /// 分组顺序固定：Workspace、Pinned、Branches、Archived Branches、Tags、Remotes、Submodules、Worktrees。
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                // 列表按仓库区分身份，换了仓库就整个重建：列表显示过可展开的行（远端、文件夹）后，
                // 行首一直留着展开箭头的位置，换成没有这类行的仓库也不收回；重建后与新开窗口的排版相同
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
                .environment(\.defaultMinListHeaderHeight, 20)
                .focused($listFocused)
                .onDeleteCommand(perform: deleteCommand)
                .id(session.repository)
                .onChange(of: session.history.revealRequests) {
                    revealSelectedReferences(with: proxy)
                }
            }

            // 刚归档的分支数与撤销
            ArchiveNoticeView(session: session)

            // 本仓库进行中与刚结束的远程操作
            SidebarActivityView(session: session, showActivity: showActivity)

            // 新版本第一次启动时的新功能卡片
            WhatsNewCard(state: .shared)

            bottomBar
        }
        .onChange(of: session.repository) {
            resetViewState()
            restoreListFocus()
        }

        // 筛选的引用被删除或在获取时修剪后，选中原位置上接替它的行
        .onChange(of: selectionState) { old, _ in
            reselectVanishedRows(from: old)
        }

        // 远端的设置随引用一起读出摘要，摘要变化时重新读取远端行提示里的地址
        .task(id: session.history.snapshot?.remoteSettingsDigests) {
            await loadRemoteConfigurations()
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
                Button(AppLocalization.text("branch.createMenu")) {
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
    var selectedItems: Set<String> {
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

        // 每个引用只有一行，行的选择身份就是完整引用名
        return references.isEmpty ? ["history"] : references
    }

    /// 选择存入会话，快捷键与点击保持一致。
    var selection: Binding<Set<String>> {
        Binding(
            get: { selectedItems },
            set: { value in
                guard !value.isEmpty else { return }

                let added = value.subtracting(selectedItems)

                // 远端、子模块与工作树的行各自换成设置视图，不参与引用的多选
                guard !selectSettingsRow(in: added) else { return }

                session.history.showsCommitPage = false

                if let view = Self.workspaceView(added: added, value: value) {
                    session.activeView = view

                    // 请求视图第一次显示时读取
                    if view == .pullRequests, !session.pullRequests.isLoaded {
                        session.reloadPullRequests()
                    }
                } else {
                    // 远端、子模块与工作树的行不是引用，从多选里去掉
                    let references = value
                        .subtracting(Self.workspaceRows.map(\.row) + ["history"])
                        .filter { row in
                            ![Self.remoteRowPrefix, Self.submoduleRowPrefix, Self.worktreeRowPrefix]
                                .contains { row.hasPrefix($0) }
                        }

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
            session.showRemote(String(remote.dropFirst(Self.remoteRowPrefix.count)))
            return true
        }

        if let submodule = added.first(where: { $0.hasPrefix(Self.submoduleRowPrefix) }) {
            session.showSubmodule(String(submodule.dropFirst(Self.submoduleRowPrefix.count)))
            return true
        }

        if let worktree = added.first(where: { $0.hasPrefix(Self.worktreeRowPrefix) }) {
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
                    .onTapGesture(count: 2) { doubleClick(ref) }
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

    /// 远端名称行：悬停提示写出名称与获取、推送地址；右键获取或清理，按住 ⌥ 换成快速获取；
    /// 接受本地分支拖入以发布分支、标签拖入以发布标签。
    func remoteLabel(_ remote: RepositoryRemote) -> some View {
        Label(remote.name, systemImage: "network")
            .help(
                SidebarTooltip.remote(
                    remote.name,
                    configuration: remoteConfigurations[remote.name],
                    host: session.repository?.host
                )
            )
            .contextMenu {
                Button(AppLocalization.text("remote.fetchMenu", remote.name)) {
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
    /// 读出各远端的设置；读取失败或仓库已断开时清空，提示只写远端名。
    private func loadRemoteConfigurations() async {
        guard let runner = session.runner else {
            remoteConfigurations = [:]
            return
        }

        let configurations = try? await RepositoryRemotes(runner: runner).configurations()

        // 读取期间换了仓库或设置又变了时，这次的结果交给新的读取覆盖
        guard !Task.isCancelled else {
            return
        }

        remoteConfigurations = Dictionary(
            (configurations ?? []).map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
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
