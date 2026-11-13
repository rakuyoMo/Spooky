import AppKit
import SpookyKit
import SwiftUI

// MARK: - HistoryListView

/// 历史头部与原生可复用列表，滚到底时自动读取下一页。
struct HistoryListView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 从所选提交新建分支，参数由窗口对话框收集。
    let createBranch: (String) -> Void

    /// 双击切换整页详情。
    let openCommit: () -> Void

    /// 提交图可见性跨仓库记忆。
    @AppStorage(HistoryViewSettings.showGraphKey)
    private var showGraph = true

    /// 0 为中号，1 为小号。
    @AppStorage(HistoryViewSettings.smallRowsKey)
    private var smallRows = false

    /// 只显示第一父提交。
    @AppStorage(HistoryViewSettings.firstParentKey)
    private var firstParentOnly = false

    /// 按拓扑序排序。
    @AppStorage(HistoryViewSettings.topoOrderKey)
    private var sortsByTopoOrder = false

    /// 按日期排序。
    @AppStorage(HistoryViewSettings.dateOrderKey)
    private var sortsByDate = true

    /// 日期分组方式。
    @AppStorage(HistoryViewSettings.groupingKey)
    private var grouping = HistoryGrouping.month.rawValue

    /// 提交日期的显示格式。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

    /// 与基准分支比较的开关。
    @AppStorage(RepositoryHistoryState.comparesBranchesKey)
    private var comparesBranches = false

    /// 40 pt 表头、搜索过滤面板、24 / 46 pt 列表行和持续可见的取消入口。
    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(session: session)

            header
            Divider()

            // 选中陈旧的分支时表头下方是提示条
            HistoryBranchHint(session: session)

            // 有搜索条件时表头下方是过滤面板
            if !session.history.searchConditions.isEmpty {
                HistorySearchPanel(history: session.history)
            }

            // 当前分支上有带 fixup! 等标记的提交时，提示自动压缩
            HistoryAutosquashBanner(session: session)

            // 回到的提交在当前历史里找不到时说明原因
            if let reason = session.history.lookupFailure {
                notice(reason) { session.history.lookupFailure = nil }
            }

            commitList
            loadingStatus
        }
        .frame(minWidth: 300)
        .onAppear { session.history.applyViewSettings() }
        .onChange(of: [showGraph, firstParentOnly, sortsByTopoOrder, sortsByDate]) {
            session.history.applyViewSettings()
        }
        .onChange(of: grouping) { session.history.applyViewSettings() }
        .onChange(of: comparesBranches) { session.history.loadBaseComparison() }
    }

    /// 列表下方的读取失败详情；读取中的进度与取消入口画在列表里。
    @ViewBuilder
    private var loadingStatus: some View {
        if let failure = session.history.failure {
            FailureDetailsView(failure: failure) { session.history.reloadCommits() }
                .padding(12)
        }
    }

    /// 所选引用与它的跟踪分支，以及视图设置按钮；与基准分支比较时左侧换成基准分支头。
    private var header: some View {
        HStack(spacing: 8) {
            if session.history.baseComparison != nil {
                HistoryBaseBranchHeader(history: session.history)
            } else {
                referenceTitle
            }

            Spacer(minLength: 4)

            IntegrateParentButton(session: session)

            CompareBranchesToggle(history: session.history)

            HistoryViewMenuButton()
                .fixedSize()
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(height: 40)
        .background(.bar)
    }

    /// 所选引用与它的跟踪分支，各自至少 50 pt 宽。
    private var referenceTitle: some View {
        HStack(spacing: 2) {
            Text(session.history.title)
                .lineLimit(1)
                .frame(minWidth: 50, alignment: .leading)

            // 本地分支有跟踪分支时写在后面
            if let tracking = trackingName {
                Image(systemName: "chevron.compact.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)

                Text(tracking)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .frame(minWidth: 50, alignment: .leading)
            }
        }
    }

    /// 单选的本地分支的跟踪分支名；没有时为 nil。
    private var trackingName: String? {
        let references = session.history.snapshot?.references ?? []

        guard
            let id = session.history.selectedReference,
            let local = references.first(where: { $0.id == id && $0.isLocal }),
            let upstream = local.upstream
        else { return nil }

        return references.first { $0.id == upstream }?.name ?? upstream
    }

    /// 首屏加载行、没有提交的一行或提交表格。
    ///
    /// 列表里还没有提交时：首屏读取过一会儿才在第一行显示加载行；读完且没有更多才写 No commits；
    /// 读取刚开始、被取消或失败时留空，失败详情在列表下方。
    @ViewBuilder
    private var commitList: some View {
        let history = session.history

        if history.loadingRowPhase.isVisible {
            firstLine {
                HistoryLoadingRow(title: AppLocalization.text("history.loading")) { history.cancelPage() }
            }
        } else if history.rows.isEmpty {
            firstLine {
                if history.snapshot != nil, !history.isLoading, !history.hasMore, history.failure == nil {
                    Text(AppLocalization.text("history.empty"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            HistoryCommitTable(
                session: session,
                showGraph: showGraph,
                smallRows: smallRows,
                dateFormat: dateFormat,
                createBranch: createBranch,
                openCommit: openCommit
            )
        }
    }

    /// 列表的第一行：整行居中，行高随当前档位，其下留空。
    private func firstLine(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
                .frame(maxWidth: .infinity)
                .frame(height: smallRows && showGraph ? 24 : 46)

            Spacer(minLength: 0)
        }
    }

    /// 列表上方的一行说明，可以关闭。
    private func notice(_ text: String, close: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .accessibilityHidden(true)

            Text(text)
                .lineLimit(2)

            Spacer(minLength: 0)

            Button(action: close) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(AppLocalization.text("action.close"))
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - HistoryCommitTable

/// NSTableView 提供固定行高、多选、复制和只限应用内的提交拖动。
struct HistoryCommitTable: NSViewRepresentable {
    /// 响应链上的 ⌘C 复制完整哈希；回车不进入整页详情，双击才进入。
    final class CommitTableView: NSTableView {
        /// 当前选择对应的复制动作。
        var copySelection: (() -> Void)?

        /// 列表内拖放时落点旁的动作名。
        let dropLabel = HistoryDropLabel()

        /// 文本焦点位于表格时响应系统复制菜单。
        @objc
        func copy(_: Any?) { copySelection?() }

        /// 拖动离开列表时移除落点旁的动作名。
        override func draggingExited(_ sender: (any NSDraggingInfo)?) {
            super.draggingExited(sender)

            dropLabel.hide()
        }

        /// 拖动结束时移除落点旁的动作名。
        ///
        /// NSTableView 与 NSView 都没有实现这个方法，不能调用 super：调用会在拖动结束时抛出异常，
        /// 经过列表的拖动收不了尾，拖动来源的行之后再也拖不起来。
        override func draggingEnded(_: any NSDraggingInfo) {
            dropLabel.hide()
        }

    }

    /// 表格委托把事件交给历史状态，不组装 Git 参数。
    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
        /// 当前 SwiftUI 输入。
        var parent: HistoryCommitTable

        /// 原生列表的弱引用。
        weak var table: NSTableView?

        /// 已显示的提交身份，决定是否重载。
        private var displayed: [String] = []

        /// 引用变化也需要更新徽标。
        private var snapshot: ReferenceSnapshot?

        /// 两侧归属变化时刷新相同行的进度标记。
        private var trackingMarkers: [Set<String>] = []

        /// 选中背景与引用徽标保持一致。
        private var selection = Set<String>()

        /// 列表末尾是否有续页的加载行。
        private(set) var showsLoadingRow = false

        /// 会话的选择改变后还没有滚到的选中行；刷新重载后表格恢复原有选中时不滚动。
        private var revealsSelection = false

        /// 程序恢复选区时忽略表格的中间通知，防止 reloadData 清空业务选择。
        private var isUpdating = false

        /// 建立会话绑定。
        init(_ parent: HistoryCommitTable) { self.parent = parent }

        /// 选择单独同步，行、图、行高或日期格式变化时才重新构建可见行。
        func update(_ parent: HistoryCommitTable) {
            let changedStyle =
                self.parent.showGraph != parent.showGraph
                    || self.parent.smallRows != parent.smallRows
                    || self.parent.dateFormat != parent.dateFormat
            self.parent = parent
            guard let table else { return }
            isUpdating = true
            defer { isUpdating = false }

            let history = parent.session.history
            let ids = history.rows.map(\.id)
            let markers = [history.unpushed, history.unpulled, history.parentCommits]
            let loadsMore = history.isLoading && !history.isRefreshingCommits && !history.rows.isEmpty

            if selection != history.selectedIDs {
                revealsSelection = true
            }

            if
                displayed != ids || changedStyle || snapshot != history.snapshot
                || trackingMarkers != markers || selection != history.selectedIDs
            {
                displayed = ids
                snapshot = history.snapshot
                trackingMarkers = markers
                selection = history.selectedIDs
                showsLoadingRow = loadsMore
                table.reloadData()
            } else if showsLoadingRow != loadsMore {
                // 只增删末尾的加载行：重画最后一个提交行会立即续读，取消就不起作用了
                showsLoadingRow = loadsMore

                let index = IndexSet(integer: history.rows.count)

                if loadsMore {
                    table.insertRows(at: index)
                } else {
                    table.removeRows(at: index)
                }
            }

            // 重载会清空表格的选区，这里按会话的选择恢复；只有会话的选择改变时才滚到选中行，
            // 引用变化等刷新引起的重载保持用户滚到的位置
            let indexes = IndexSet(history.rows.indices.filter { row in
                history.rows[row].commit.map { history.selectedIDs.contains($0.id) } ?? false
            })

            if table.selectedRowIndexes != indexes {
                table.selectRowIndexes(indexes, byExtendingSelection: false)

                if revealsSelection, let first = indexes.first {
                    Task { @MainActor in table.scrollRowToVisible(first) }
                }
            }

            // 选中的提交还没有读进列表时保留标记，等它出现时再滚动
            if !indexes.isEmpty {
                revealsSelection = false
            }

            // 回到历史时找到的提交滚动到列表中间并让列表获得焦点，等表格完成布局后再滚动
            if let target = history.scrollTarget, let row = history.row(of: target) {
                Task { @MainActor in
                    Self.center(row, in: table)
                    table.window?.makeFirstResponder(table)
                    history.scrollTarget = nil
                }
            }
        }

        /// 每个被拖的提交写一个载荷；侧边栏的落点据此新建分支或标签，或者摘取与反转。
        func tableView(_: NSTableView, pasteboardWriterForRow row: Int) -> (
            any NSPasteboardWriting
        )? {
            guard
                let location = parent.session.repository,
                let commit = parent.session.history.commit(atRow: row)
            else { return nil }
            let item = NSPasteboardItem()
            let payload = RepositoryDragPayload(
                repository: location,
                kind: .commit,
                reference: commit.id
            )
            RepositoryDragContext.shared.payload = payload
            guard let data = try? JSONEncoder().encode(payload) else { return nil }
            item.setData(data, forType: .init(RepositoryDragPayload.type))
            return item
        }

        /// 拖动开始时记下全部被拖的提交，按列表顺序；多选拖到工作区或 HEAD 分支时一起摘取或反转。
        func tableView(
            _: NSTableView,
            draggingSession _: NSDraggingSession,
            willBeginAt _: NSPoint,
            forRowIndexes rowIndexes: IndexSet
        ) {
            guard let location = parent.session.repository else { return }

            let history = parent.session.history
            let payloads = rowIndexes.compactMap { history.commit(atRow: $0) }.map {
                RepositoryDragPayload(repository: location, kind: .commit, reference: $0.id)
            }

            RepositoryDragContext.shared.payload = payloads.first
            RepositoryDragContext.shared.batch = payloads.count > 1 ? payloads : []
        }

        /// 列表内拖动提交：在看 HEAD 分支时可以压缩、fixup 或移到别处，落点旁显示动作名。
        func tableView(
            _ tableView: NSTableView,
            validateDrop info: any NSDraggingInfo,
            proposedRow row: Int,
            proposedDropOperation operation: NSTableView.DropOperation
        ) -> NSDragOperation {
            let action = internalDrop(info, in: tableView, row: row, operation: operation)

            (tableView as? CommitTableView)?.dropLabel.show(
                action.map { AppLocalization.text(HistoryListDrop.titleKey(of: $0)) },
                row: row,
                between: operation == .above,
                in: tableView
            )

            return action == nil ? [] : .move
        }

        /// 落下时先计划交互式变基，再请求确认。
        func tableView(
            _ tableView: NSTableView,
            acceptDrop info: any NSDraggingInfo,
            row: Int,
            dropOperation: NSTableView.DropOperation
        ) -> Bool {
            (tableView as? CommitTableView)?.dropLabel.hide()

            guard let action = internalDrop(info, in: tableView, row: row, operation: dropOperation) else {
                return false
            }

            parent.session.requestRewrite(action)
            return true
        }

        /// 菜单打开前按被点的行重建。
        func menuNeedsUpdate(_ menu: NSMenu) {
            buildMenu(menu, clickedRow: table?.clickedRow ?? -1)
        }

        /// 右键在选区内或没有被点的行时作用于选区，在选区外时只作用于被点的行，选区与详情都不变；点在分组标题上时没有菜单项。
        ///
        /// - Parameters:
        ///   - menu: 要重建的菜单。
        ///   - clickedRow: 被点的行；没有时为 -1。
        func buildMenu(_ menu: NSMenu, clickedRow clicked: Int) {
            menu.removeAllItems()
            menu.autoenablesItems = false

            let history = parent.session.history

            // 实际作用的提交只算一次，菜单标题、可用性与动作都用这一份
            let targets: [HistoryCommit]

            let clickedCommit = clicked >= 0 ? history.commit(atRow: clicked) : nil

            let clickedOutside =
                clicked >= 0
                    && !(clickedCommit.map { history.selectedIDs.contains($0.id) } ?? false)

            if clickedOutside {
                targets = clickedCommit.map { [$0] } ?? []
            } else {
                let selected = history.commits.filter { history.selectedIDs.contains($0.id) }
                targets = selected.isEmpty ? (history.selectedCommit.map { [$0] } ?? []) : selected
            }

            // 复制与定位在前，其后是检出、改写、新建与补丁各组，按列表顺序传入
            let copies = HistoryCommitMenu.copyItems(for: targets, session: parent.session)

            let actions = HistoryCommitMenu.items(
                for: targets,
                session: parent.session,
                createBranch: parent.createBranch
            )

            for item in copies + actions {
                menu.addItem(item)
            }
        }

        /// ⌘C 按列表顺序复制选中提交的完整哈希，一行一个。
        func copyHashes() {
            let history = parent.session.history
            HistoryCommitMenu.copyHashes(of: history.commits.filter { history.selectedIDs.contains($0.id) })
        }

        /// 双击进入整页提交详情，保持相同 First Parent 比较语义。
        @objc
        func doubleClick() {
            guard parent.session.history.selectedCommit != nil else { return }
            parent.openCommit()
        }

        /// 只认本列表自己拖出的提交，动作按列表内拖放的规则算出。
        private func internalDrop(
            _ info: any NSDraggingInfo,
            in tableView: NSTableView,
            row: Int,
            operation: NSTableView.DropOperation
        ) -> RewriteAction? {
            guard (info.draggingSource as? NSTableView) === tableView else { return nil }

            let dragged = RepositoryDragContext.shared.payloads.filter { $0.kind == .commit }.map(\.reference)

            return HistoryListDrop.action(
                dragged: dragged,
                row: row,
                between: operation == .above,
                alternate: NSEvent.modifierFlags.contains(.option),
                session: parent.session
            )
        }

    }

    /// 当前仓库及历史模型。
    let session: RepositorySession

    /// 当前图可见性。
    let showGraph: Bool

    /// 保存的行高档位。
    let smallRows: Bool

    /// 提交日期的显示格式。
    let dateFormat: CommitDateFormat

    /// 新建分支入口。
    let createBranch: (String) -> Void

    /// 整页详情入口。
    let openCommit: () -> Void

    /// 实际使用小号行：隐藏提交图时固定用 46 pt 的中号行，保存的档位不变，重新显示图时恢复。
    var usesSmallRows: Bool {
        smallRows && showGraph
    }

    /// 建立数据源桥接。
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 原生表格保留键盘与 VoiceOver 选择语义。
    func makeNSView(context: Context) -> NSScrollView {
        let table = CommitTableView()
        table.addTableColumn(NSTableColumn(identifier: .init("commit")))
        table.headerView = nil
        table.style = .inset
        table.intercellSpacing = .zero
        table.allowsMultipleSelection = true
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.target = context.coordinator
        table.doubleAction = #selector(Coordinator.doubleClick)
        table.copySelection = { context.coordinator.copyHashes() }
        table.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        table.setDraggingSourceOperationMask([], forLocal: false)

        // 列表内拖放提交是交互式变基
        table.registerForDraggedTypes([.init(RepositoryDragPayload.type)])
        table.setAccessibilityIdentifier("history-commits")
        let menu = NSMenu()
        menu.delegate = context.coordinator
        table.menu = menu
        context.coordinator.table = table
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = table
        return scroll
    }

    /// 数据不变时不 reload，避免进度和选择更新打断滚动。
    func updateNSView(_: NSScrollView, context: Context) {
        context.coordinator.update(self)
    }

}

// MARK: - Data Source

extension HistoryCommitTable.Coordinator {
    /// 把一行滚到列表中间。
    fileprivate static func center(_ row: Int, in table: NSTableView) {
        let rect = table.rect(ofRow: row)
        let visible = table.visibleRect
        table.scroll(NSPoint(x: visible.minX, y: max(0, rect.midY - visible.height / 2)))
    }

    /// 行数来自当前已完成的页与日期分组，续页时末尾多一行加载行。
    func numberOfRows(in _: NSTableView) -> Int {
        parent.session.history.rows.count + (showsLoadingRow ? 1 : 0)
    }

    /// 提交行与分叉点行 24 / 46 pt，“没有新提交” 行 40 / 46 pt，日期分组行 30 pt。
    func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        let rows = parent.session.history.rows

        guard rows.indices.contains(row) else {
            return parent.usesSmallRows ? 24 : 46
        }

        switch rows[row] {
        case .group: return 30
        case .noNewCommits: return parent.usesSmallRows ? 40 : 46
        case .commit, .forkPoint: return parent.usesSmallRows ? 24 : 46
        }
    }

    /// 只有提交行可以选中。
    func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
        parent.session.history.commit(atRow: row) != nil
    }

    /// ⇧ 点选一段时跳过其中的分组行。
    func tableView(_: NSTableView, selectionIndexesForProposedSelection proposed: IndexSet) -> IndexSet {
        proposed.filteredIndexSet { parent.session.history.commit(atRow: $0) != nil }
    }

    /// 行内容按需复用，最后一个提交行触发续页；续页的加载行排在最后。
    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let history = parent.session.history

        guard history.rows.indices.contains(row) else {
            guard showsLoadingRow, row == history.rows.count else {
                return nil
            }

            let view = HistoryLoadingRow(title: AppLocalization.text("history.loading")) { history.cancelPage() }
            return tableView.hostingView(view, identifier: "history-loading")
        }

        if row == history.rows.count - 1, history.hasMore {
            Task { @MainActor in history.loadNextPage() }
        }

        switch history.rows[row] {
        case .group(let start):
            // 分组行画出从上一个提交穿到下一个提交的线
            let next = history.commit(atRow: row + 1).flatMap { history.graphRows[$0.id] }
            let view = HistoryGroupRow(
                graph: parent.showGraph && next != nil ? HistoryGraphView(passingInto: next) : nil,
                title: history.grouping.title(of: start, format: parent.dateFormat)
            )

            return tableView.hostingView(view, identifier: "history-group")

        case .forkPoint(let base):
            // 分叉点行同样画出穿到分叉点提交的线
            let next = history.commit(atRow: row + 1).flatMap { history.graphRows[$0.id] }
            let view = HistoryForkPointRow(
                base: base,
                graph: parent.showGraph && next != nil ? HistoryGraphView(passingInto: next) : nil
            )

            return tableView.hostingView(view, identifier: "history-fork-point")

        case .noNewCommits(let base):
            return tableView.hostingView(HistoryNoNewCommitsRow(base: base), identifier: "history-no-new-commits")

        case .commit(let commit):
            let view = HistoryCommitRow(
                commit: commit,
                graph: parent.showGraph ? history.graphRows[commit.id] : nil,
                references: history.snapshot?.decorations(
                    of: commit.id,
                    headBranch: history.branch?.head.map { "refs/heads/" + $0 }
                ) ?? [],
                isHead: history.branch?.oid == commit.id,
                small: parent.usesSmallRows,
                dateFormat: parent.dateFormat,
                unpushed: history.unpushed.contains(commit.id),
                unpulled: history.unpulled.contains(commit.id),
                isParent: history.parentCommits.contains(commit.id),
                selected: history.selectedIDs.contains(commit.id),
                signatures: parent.session.signatures,
                runner: parent.session.runner
            )

            return tableView.hostingView(view, identifier: "history-commit")
        }
    }

    /// 单选与多选共享完整哈希，视图刷新后可以恢复选择。
    func tableViewSelectionDidChange(_: Notification) {
        guard !isUpdating, let table else { return }

        let history = parent.session.history
        history.selectedIDs = Set(table.selectedRowIndexes.compactMap { history.commit(atRow: $0)?.id })
    }

}
