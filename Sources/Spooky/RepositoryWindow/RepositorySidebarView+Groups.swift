import SpookyKit
import SwiftUI

// MARK: - Groups

extension RepositorySidebarView {
    /// Pinned 分组：只在有置顶分支时出现，里面同样按 “/” 折叠；置顶的分支在 Branches 分组里仍有一行。
    @ViewBuilder
    var pinnedBranches: some View {
        let pinned = localReferences.filter { metadata(for: $0).isPinned }

        if !pinned.isEmpty {
            Section(isExpanded: isExpanded(.pinned)) {
                SidebarRefTreeView(nodes: branchNodes(pinned, scope: "pinned"), isExpanded: isExpanded) { node in
                    if let ref = node.reference {
                        localBranchRow(ref, name: node.name, tag: Self.pinnedRowPrefix + ref.id)
                    }
                }
            } header: {
                groupHeader("sidebar.pinned", destination: .pinned)
            }
        }
    }

    /// Branches 分组：未归档的本地分支；未出生和分离 HEAD 仍有一行当前分支。
    var localBranches: some View {
        Section(isExpanded: isExpanded(.branches)) {
            if localReferences.isEmpty, !isFiltering {
                Text(AppLocalization.text("branch.empty")).foregroundStyle(.secondary)
            }

            headRow

            SidebarRefTreeView(
                nodes: branchNodes(localReferences.filter { !metadata(for: $0).isArchived }, scope: "branches"),
                isExpanded: isExpanded
            ) { node in
                if let ref = node.reference {
                    localBranchRow(ref, name: node.name, tag: ref.id)
                }
            }
        } header: {
            groupHeader("branch.group", destination: .branches)
                .contextMenu {
                    Button(AppLocalization.text("branch.create")) {
                        request(RepositoryActionRequest(kind: .create))
                    }
                    .disabled(!session.canCreateBranch)
                }
        }
    }

    /// Archived Branches 分组：按名称排列的已归档分支，同样按 “/” 折叠；没有归档分支时只有标题。
    var archivedBranches: some View {
        Section(isExpanded: isExpanded(.archived)) {
            SidebarRefTreeView(
                nodes: branchNodes(localReferences.filter { metadata(for: $0).isArchived }, scope: "archived"),
                isExpanded: isExpanded
            ) { node in
                if let ref = node.reference {
                    localBranchRow(ref, name: node.name, tag: ref.id)
                }
            }
        } header: {
            ArchivedGroupHeader(session: session) {
                groupHeader("sidebar.archived", destination: .archived)
            }
        }
    }

    /// 每个配置远端都有一个可展开的节点，下面是它的远端分支；选中远端时主视图显示它的设置。
    var remoteBranches: some View {
        Section(isExpanded: isExpanded(.remotes)) {
            if session.history.snapshot?.remotes.isEmpty != false {
                Text(AppLocalization.text("sync.noRemotes")).foregroundStyle(.secondary)
            }

            ForEach(session.history.snapshot?.remotes ?? [], id: \.sidebarID) { remote in
                DisclosureGroup(isExpanded: isExpanded(remote.sidebarID)) {
                    remoteBranchRows(remote)
                } label: {
                    remoteLabel(remote)
                        .tag(Self.remoteRowPrefix + remote.name)
                }
            }
        } header: {
            Text(AppLocalization.text("remote.group"))
        }
    }

    /// 未出生或分离 HEAD 时的当前分支行；过滤时同样按名称匹配。
    @ViewBuilder
    private var headRow: some View {
        if let branch = session.status?.branch, branch.head == nil || branch.oid == nil {
            let name = branch.head ?? AppLocalization.text("branch.detachedShort")

            if !isFiltering || SidebarRefTree.matches(name, filter: filterText) {
                SidebarBranchRow(
                    name: name,
                    symbol: "arrow.triangle.branch",
                    badge: [.head],
                    help: SidebarTooltip.head(branch: branch, host: session.repository?.host)
                )
                .tag("HEAD")
            }
        }
    }
}

// MARK: - Rows

extension RepositorySidebarView {
    /// 本地分支行：单击显示历史，双击检出，可以拖动，HEAD 分支接受合并拖放。
    ///
    /// - Parameter tag: 行的选择身份；置顶分组里的行带前缀。
    func localBranchRow(_ ref: RepositoryReference, name: String, tag: String) -> some View {
        branchRow(ref, name: name)
            .tag(tag)
            .onTapGesture(count: 2) { checkout(ref) }
            .onDrag { dragProvider(kind: .local, reference: ref.id) }
            .contextMenu { branchMenu(ref) }
            .modifier(
                RepositoryDropTarget(
                    session: session,
                    destination: ref.name == session.status?.branch.head ? .head : .localBranch,
                    request: request
                )
            )
    }

    /// 分组标题；作为落点时整行都接受拖放。
    func groupHeader(_ key: String, destination: RepositoryDropDestination) -> some View {
        Text(AppLocalization.text(key))
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(RepositoryDropTarget(session: session, destination: destination, request: request))
    }

    /// 胶囊徽标的各段：HEAD、Merged、超前、落后，有才显示。
    func badge(_ ref: RepositoryReference, status: SidebarBranchStatus) -> [SidebarBadgeSegment] {
        var segments: [SidebarBadgeSegment] = []

        if ref.name == session.status?.branch.head {
            segments.append(.head)
        }

        if status.isFullyMerged {
            segments.append(.merged)
        }

        if let counts = session.history.divergence[ref.id] {
            if counts.ahead > 0 { segments.append(.ahead(counts.ahead)) }
            if counts.behind > 0 { segments.append(.behind(counts.behind)) }
        }

        return segments
    }

    /// 按视图设置筛过的完全合并、陈旧与跟踪错误。
    func branchStatus(_ ref: RepositoryReference) -> SidebarBranchStatus {
        let months =
            SidebarPreferences.isValid(staleInterval, for: SidebarPreferences.staleIntervalKey)
                ? staleInterval
                : SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey)

        return SidebarBranchStatus(
            condition: session.history.conditions[ref.id],
            showsMerged: showsMergedBadge,
            staleMonths: showsStaleInfo ? months : nil
        )
    }

    /// 远端的默认分支只取本地符号引用，不猜测 main 或 master。
    func isDefaultBranch(_ ref: RepositoryReference) -> Bool {
        guard let snapshot = session.history.snapshot, let remote = snapshot.remote(for: ref) else {
            return false
        }

        return snapshot.defaultBranch(for: remote) == ref.id
    }
}

// MARK: - Tree

extension RepositorySidebarView {
    /// 过滤框有文字时，所有分组与文件夹都展开。
    var isFiltering: Bool { !filterText.isEmpty }

    /// 全部本地分支，按引用名排列。
    var localReferences: [RepositoryReference] {
        session.history.branches.filter(\.isLocal)
    }

    /// 行身份换成完整引用名：置顶分组里的行去掉前缀。
    static func reference(forRow row: String) -> String {
        row.hasPrefix(pinnedRowPrefix) ? String(row.dropFirst(pinnedRowPrefix.count)) : row
    }

    /// 分组的展开状态；过滤时固定展开，清空后回到原来的状态。
    func isExpanded(_ group: SidebarGroup) -> Binding<Bool> {
        Binding(
            get: { isFiltering || !collapsedGroups.contains(group) },
            set: { expanded in
                guard !isFiltering else { return }

                if expanded {
                    collapsedGroups.remove(group)
                } else {
                    collapsedGroups.insert(group)
                }
            }
        )
    }

    /// 远端与文件夹的展开状态；过滤时固定展开，清空后回到原来的状态。
    func isExpanded(_ node: SidebarNodeID) -> Binding<Bool> {
        Binding(
            get: { isFiltering || expandedNodes.contains(node) },
            set: { expanded in
                guard !isFiltering else { return }

                if expanded {
                    expandedNodes.insert(node)
                } else {
                    expandedNodes.remove(node)
                }
            }
        )
    }

    /// 本地分支的附加信息；没有记录时是默认值。
    func metadata(for ref: RepositoryReference) -> BranchMetadata {
        session.history.snapshot?.metadata(for: ref.id) ?? BranchMetadata()
    }

    /// 一组本地分支经过滤后的树。
    func branchNodes(_ branches: [RepositoryReference], scope: String) -> [SidebarRefNode] {
        SidebarRefTree.nodes(
            for: SidebarRefTree.branchEntries(branches, filter: filterText),
            grouped: groupsRefs,
            foldersFirst: groupedRefsOnTop,
            scope: scope
        )
    }

    /// 一个远端的远端分支树。
    func remoteBranchNodes(_ remote: RepositoryRemote) -> [SidebarRefNode] {
        guard let snapshot = session.history.snapshot else {
            return []
        }

        let limit =
            SidebarPreferences.isValid(newestRemoteBranches, for: SidebarPreferences.newestRemoteBranchesKey)
                ? newestRemoteBranches
                : 0

        let entries = SidebarRefTree.remoteEntries(
            of: remote,
            in: snapshot,
            filter: filterText,
            limit: limit,
            including: session.history.selectedReferences
        )

        return SidebarRefTree.nodes(
            for: entries,
            grouped: groupsRefs,
            foldersFirst: groupedRefsOnTop,
            scope: remote.sidebarID.value
        )
    }

    /// 换仓库时回到默认的展开状态，清空过滤文字与点选记录。
    func resetViewState() {
        collapsedGroups = [.tags]
        expandedNodes = [.remote("origin")]
        filterText = ""
        rowSelection = []
    }
}

// MARK: - RepositoryRemote

extension RepositoryRemote {
    /// 远端在侧边栏里的节点身份；与选择用的字符串不同类型，远端行不会被当成可选中的引用。
    var sidebarID: SidebarNodeID {
        .remote(name)
    }
}
