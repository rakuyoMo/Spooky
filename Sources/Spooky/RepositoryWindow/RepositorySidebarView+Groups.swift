import AppKit
import SpookyKit
import SwiftUI

// MARK: - Groups

extension RepositorySidebarView {
    /// Pinned 分组：只在有置顶分支时出现，里面同样按 “/” 折叠；置顶的分支只在这里有一行。
    @ViewBuilder
    var pinnedBranches: some View {
        let pinned = pinnedReferences

        if !pinned.isEmpty {
            sidebarSection(.pinned) {
                SidebarRefTreeView(nodes: branchNodes(pinned, scope: "pinned"), isExpanded: isExpanded) { node in
                    if let ref = node.reference {
                        localBranchRow(ref, name: node.name)
                    }
                } folder: { node in
                    folderLabel(node, destination: .branchFolder(node.path))
                }
            } header: {
                groupHeader("sidebar.pinned", destination: .pinned)
            }
        }
    }

    /// Branches 分组：没有置顶也没有归档的本地分支；未出生和分离 HEAD 仍有一行当前分支。
    var localBranches: some View {
        sidebarSection(.branches) {
            if localReferences.isEmpty, !isFiltering {
                Text(AppLocalization.text("branch.empty")).foregroundStyle(.secondary)
            }

            headRow

            SidebarRefTreeView(
                nodes: branchNodes(activeReferences, scope: "branches"),
                isExpanded: isExpanded
            ) { node in
                if let ref = node.reference {
                    localBranchRow(ref, name: node.name)
                }
            } folder: { node in
                folderLabel(node, destination: .branchFolder(node.path))
            }
        } header: {
            groupHeader("branch.group", destination: .branches)
                .contextMenu {
                    Button(AppLocalization.text("branch.createMenu")) {
                        request(RepositoryActionRequest(kind: .create))
                    }
                    .disabled(!session.canCreateBranch)
                }
        }
    }

    /// Archived Branches 分组：没有置顶的已归档分支，同样按 “/” 折叠；没有归档分支时只有标题。
    var archivedBranches: some View {
        sidebarSection(.archived) {
            SidebarRefTreeView(
                nodes: branchNodes(archivedReferences, scope: "archived"),
                isExpanded: isExpanded
            ) { node in
                if let ref = node.reference {
                    localBranchRow(ref, name: node.name)
                }
            } folder: { node in
                folderLabel(node, destination: .branchFolder(node.path))
            }
        } header: {
            ArchivedGroupHeader(session: session, request: request)
        }
    }

    /// 每个配置远端都有一个可展开的节点，下面是它的远端分支；选中远端时主视图显示它的设置。
    var remoteBranches: some View {
        sidebarSection(.remotes) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .contextMenu {
                    Button(AppLocalization.text("remote.addMenu")) {
                        session.requestReference(.addRemote)
                    }
                    .disabled(!session.canWrite)
                }
        }
    }

    /// 未出生或分离 HEAD 时的当前分支行；过滤时同样按名称匹配。
    @ViewBuilder
    private var headRow: some View {
        if let name = headRowName, let branch = session.status?.branch {
            SidebarBranchRow(
                name: name,
                symbol: "arrow.triangle.branch",
                badge: [.head],
                help: SidebarTooltip.head(branch: branch, host: session.repository?.host)
            )
            .tag("HEAD")
            .id(Self.headRowID)
        }
    }
}

// MARK: - Rows

extension RepositorySidebarView {
    /// 本地分支行：单击显示历史，双击检出，可以拖动，HEAD 分支接受合并拖放。
    ///
    /// 每个本地分支只在一个分组里有一行，行的选择身份就是完整引用名；置顶与取消置顶后选中的仍是这一行。
    func localBranchRow(_ ref: RepositoryReference, name: String) -> some View {
        branchRow(ref, name: name)
            .tag(ref.id)
            .onTapGesture(count: 2) { doubleClick(ref) }
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

    /// 双击本地分支、远端分支或标签的行；按住 ⌘ 时，已在别的工作树检出的分支在新标签页打开那个工作树。
    func doubleClick(_ ref: RepositoryReference) {
        let target: RepositoryOpenTarget = NSEvent.modifierFlags.contains(.command) ? .newTab : .currentWindow
        session.doubleClick(ref, in: target)
    }

    /// 可以收起的分组：标题行高 20 pt，文字距侧边栏左缘 19 pt。
    ///
    /// - Parameters:
    ///   - group: 分组，决定展开状态。
    ///   - content: 分组里的行。
    ///   - header: 分组标题。
    func sidebarSection(
        _ group: SidebarGroup,
        @ViewBuilder content: () -> some View,
        @ViewBuilder header: () -> some View
    ) -> some View {
        Section(isExpanded: isExpanded(group), content: content) {
            // 列表给标题留出的左边距是 14 pt，再让出 5 pt
            header()
                .padding(.leading, 5)
        }
    }

    /// 分组标题；作为落点时整行都接受拖放。
    func groupHeader(_ key: String, destination: RepositoryDropDestination) -> some View {
        Text(AppLocalization.text(key))
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(RepositoryDropTarget(session: session, destination: destination, request: request))
    }

    /// 按 “/” 折叠出的文件夹行；作为落点接受拖入改名、新建分支或标签。本地分支与标签的文件夹有右键菜单，远端分支的文件夹没有。
    @ViewBuilder
    func folderLabel(_ node: SidebarRefNode, destination: RepositoryDropDestination) -> some View {
        let label = SidebarFolderLabel(name: node.name)
            .modifier(RepositoryDropTarget(session: session, destination: destination, request: request))

        switch destination {
        case .branchFolder, .tagFolder:
            label.contextMenu { folderMenu(destination) }

        default:
            label
        }
    }

    /// 文件夹的右键菜单只有一项新建，名称预填文件夹路径与结尾的 “/”：分支文件夹从 HEAD 新建分支，标签文件夹在 HEAD 上新建标签。
    @ViewBuilder
    func folderMenu(_ destination: RepositoryDropDestination) -> some View {
        switch destination {
        case .branchFolder(let path):
            Button(AppLocalization.text("branch.createMenu")) {
                request(RepositoryActionRequest(kind: .create, name: path + "/"))
            }
            .disabled(!session.canCreateBranch)

        case .tagFolder(let path):
            Button(AppLocalization.text("tag.createMenu")) {
                session.requestReference(.createTag(revision: nil, name: path + "/"))
            }
            .disabled(!session.canCreateTag)

        default:
            EmptyView()
        }
    }

    /// 胶囊徽标的各段：HEAD、超前、落后，有才显示。
    func badge(_ ref: RepositoryReference) -> [SidebarBadgeSegment] {
        var segments: [SidebarBadgeSegment] = []

        if ref.name == session.status?.branch.head {
            segments.append(.head)
        }

        if let counts = session.history.divergence[ref.id] {
            if counts.ahead > 0 { segments.append(.ahead(counts.ahead)) }
            if counts.behind > 0 { segments.append(.behind(counts.behind)) }
        }

        return segments
    }

    /// 按视图设置筛过的陈旧与跟踪错误。
    func branchStatus(_ ref: RepositoryReference) -> SidebarBranchStatus {
        let months =
            SidebarPreferences.isValid(staleInterval, for: SidebarPreferences.staleIntervalKey)
                ? staleInterval
                : SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey)

        return SidebarBranchStatus(
            condition: session.history.conditions[ref.id],
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

    /// Pinned 分组里的分支：置顶的本地分支，已归档的也在这里。
    var pinnedReferences: [RepositoryReference] {
        localReferences.filter { metadata(for: $0).isPinned }
    }

    /// Branches 分组里的分支：没有置顶也没有归档的本地分支。
    var activeReferences: [RepositoryReference] {
        localReferences.filter { reference in
            let flags = metadata(for: reference)
            return !flags.isPinned && !flags.isArchived
        }
    }

    /// Archived Branches 分组里的分支：没有置顶的已归档分支。
    var archivedReferences: [RepositoryReference] {
        localReferences.filter { reference in
            let flags = metadata(for: reference)
            return !flags.isPinned && flags.isArchived
        }
    }

    /// 当前分支行显示的名字：未出生时是分支名，分离 HEAD 时是当前提交的 8 位短哈希；
    /// 不是未出生或分离 HEAD，或者被过滤掉时为 nil，不显示这一行。
    var headRowName: String? {
        guard
            let branch = session.status?.branch,
            branch.head == nil || branch.oid == nil,
            let name = branch.head ?? branch.oid.map({ String($0.prefix(8)) })
        else {
            return nil
        }

        guard !isFiltering || SidebarRefTree.matches(name, filter: filterText) else {
            return nil
        }

        return name
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

    /// 换仓库时回到默认的展开状态，清空过滤文字。
    func resetViewState() {
        collapsedGroups = [.tags]
        expandedNodes = [.remote("origin")]
        filterText = ""
    }

    /// 换了仓库重建列表后，原来有键盘焦点的话把焦点还给新的列表。
    ///
    /// 旧列表移出窗口时焦点随之丢失，`listFocused` 却仍是 true；先置为 false，下一轮再设回 true，焦点才会落到新的列表上。
    func restoreListFocus() {
        guard listFocused else {
            return
        }

        listFocused = false

        Task { @MainActor in
            listFocused = true
        }
    }
}

// MARK: - RepositoryRemote

extension RepositoryRemote {
    /// 远端在侧边栏里的节点身份；与选择用的字符串不同类型，远端行不会被当成可选中的引用。
    var sidebarID: SidebarNodeID {
        .remote(name)
    }
}
