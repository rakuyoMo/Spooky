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
    private var sortsByDate = false

    /// 日期分组方式。
    @AppStorage(HistoryViewSettings.groupingKey)
    private var grouping = HistoryGrouping.ungrouped.rawValue

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

    /// 列表下方的读取状态：失败详情，以及读取中持续可见的取消入口。
    @ViewBuilder
    private var loadingStatus: some View {
        if let failure = session.history.failure {
            FailureDetailsView(failure: failure) { session.history.reloadCommits() }
                .padding(12)
        }

        if session.history.isLoading {
            HStack {
                ProgressView().controlSize(.small)
                Text(AppLocalization.text("history.loading"))
                Button(AppLocalization.text("action.cancel")) { session.history.cancelPage() }
            }
            .font(.system(size: 11))
            .padding(8)
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

    /// 所选引用与它的跟踪分支。
    private var referenceTitle: some View {
        HStack(spacing: 2) {
            Text(session.history.title)
                .lineLimit(1)
                .help(session.repository?.displayPath ?? "")

            // 本地分支有跟踪分支时写在后面
            if let tracking = trackingName {
                Image(systemName: "chevron.compact.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)

                Text(tracking)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
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

    /// 没有提交且不在读取时显示空状态，否则显示提交表格。
    @ViewBuilder
    private var commitList: some View {
        if session.history.rows.isEmpty, !session.history.isLoading {
            EmptyStateView(title: AppLocalization.text("history.empty"), message: "", symbol: "clock")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
private struct HistoryCommitTable: NSViewRepresentable {
    /// 响应链上的 ⌘C 复制完整哈希，回车与双击一样进入整页详情。
    final class CommitTableView: NSTableView {
        /// 当前选择对应的复制动作。
        var copySelection: (() -> Void)?

        /// 键盘打开整页提交详情的动作。
        var openSelection: (() -> Void)?

        /// 列表内拖放时落点旁的动作名。
        let dropLabel = HistoryDropLabel()

        /// 回车与小键盘 Enter 是双击的键盘入口，其它按键交给系统列表。
        override func keyDown(with event: NSEvent) {
            if
                [36, 76].contains(event.keyCode),
                event.modifierFlags.isDisjoint(with: [.command, .option, .control])
            {
                openSelection?()
                return
            }

            super.keyDown(with: event)
        }

        /// 文本焦点位于表格时响应系统复制菜单。
        @objc
        func copy(_: Any?) { copySelection?() }

        /// 拖动离开列表时移除落点旁的动作名。
        override func draggingExited(_ sender: (any NSDraggingInfo)?) {
            super.draggingExited(sender)

            dropLabel.hide()
        }

        /// 拖动结束时移除落点旁的动作名。
        override func draggingEnded(_ sender: any NSDraggingInfo) {
            super.draggingEnded(sender)

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

            if
                displayed != ids || changedStyle || snapshot != history.snapshot
                || trackingMarkers != markers || selection != history.selectedIDs
            {
                displayed = ids
                snapshot = history.snapshot
                trackingMarkers = markers
                selection = history.selectedIDs
                table.reloadData()
            }

            // 程序改变的选择滚动到可见处；用户点选时表格的选区已经一致
            let indexes = IndexSet(history.rows.indices.filter { row in
                history.rows[row].commit.map { history.selectedIDs.contains($0.id) } ?? false
            })

            if table.selectedRowIndexes != indexes {
                table.selectRowIndexes(indexes, byExtendingSelection: false)

                if let first = indexes.first {
                    Task { @MainActor in table.scrollRowToVisible(first) }
                }
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

        /// 右键在选区外时只作用于该行。
        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            guard let table else { return }
            if table.clickedRow >= 0, !table.selectedRowIndexes.contains(table.clickedRow) {
                table.selectRowIndexes(IndexSet(integer: table.clickedRow), byExtendingSelection: false)
            }
            let copy = NSMenuItem(
                title: AppLocalization.text("history.copyHash"),
                action: #selector(copyHashes),
                keyEquivalent: ""
            )
            copy.target = self
            copy.isEnabled = !parent.session.history.selectedIDs.isEmpty
            menu.addItem(copy)

            // 检出、改写、新建与补丁各组，按列表顺序传入选中的提交
            let history = parent.session.history
            let selected = history.commits.filter { history.selectedIDs.contains($0.id) }

            for item in HistoryCommitMenu.items(
                for: selected.isEmpty ? (history.selectedCommit.map { [$0] } ?? []) : selected,
                session: parent.session,
                createBranch: parent.createBranch
            ) {
                menu.addItem(item)
            }

            menu.autoenablesItems = false
        }

        /// 多选复制按照列表顺序换行连接。
        @objc
        func copyHashes() {
            let history = parent.session.history
            let hashes = history.commits.filter { history.selectedIDs.contains($0.id) }.map(\.id)
            guard !hashes.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hashes.joined(separator: "\n"), forType: .string)
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

    /// 当前行高档位。
    let smallRows: Bool

    /// 提交日期的显示格式。
    let dateFormat: CommitDateFormat

    /// 新建分支入口。
    let createBranch: (String) -> Void

    /// 整页详情入口。
    let openCommit: () -> Void

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
        table.openSelection = { context.coordinator.doubleClick() }
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

    /// 取出可复用的行视图并换上新内容。
    private static func reuse<Content: View>(
        _ content: Content,
        identifier: String,
        in tableView: NSTableView
    ) -> NSView {
        let identifier = NSUserInterfaceItemIdentifier(identifier)
        let cell =
            tableView.makeView(withIdentifier: identifier, owner: nil) as? NSHostingView<Content>
                ?? NSHostingView(rootView: content)
        cell.rootView = content
        cell.identifier = identifier
        return cell
    }

    /// 行数来自当前已完成的页与日期分组。
    func numberOfRows(in _: NSTableView) -> Int { parent.session.history.rows.count }

    /// 提交行与分叉点行 24 / 46 pt，“没有新提交” 行 40 / 46 pt，日期分组行 30 pt。
    func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        let rows = parent.session.history.rows

        guard rows.indices.contains(row) else {
            return parent.smallRows ? 24 : 46
        }

        switch rows[row] {
        case .group: return 30
        case .noNewCommits: return parent.smallRows ? 40 : 46
        case .commit, .forkPoint: return parent.smallRows ? 24 : 46
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

    /// 行内容按需复用，最后一行触发续页。
    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let history = parent.session.history

        guard history.rows.indices.contains(row) else { return nil }

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

            return Self.reuse(view, identifier: "history-group", in: tableView)

        case .forkPoint(let base):
            // 分叉点行同样画出穿到分叉点提交的线
            let next = history.commit(atRow: row + 1).flatMap { history.graphRows[$0.id] }
            let view = HistoryForkPointRow(
                base: base,
                graph: parent.showGraph && next != nil ? HistoryGraphView(passingInto: next) : nil
            )

            return Self.reuse(view, identifier: "history-fork-point", in: tableView)

        case .noNewCommits(let base):
            return Self.reuse(HistoryNoNewCommitsRow(base: base), identifier: "history-no-new-commits", in: tableView)

        case .commit(let commit):
            let view = HistoryCommitRow(
                commit: commit,
                graph: parent.showGraph ? history.graphRows[commit.id] : nil,
                references: history.snapshot?.references.filter { $0.objectID == commit.id } ?? [],
                isHead: history.branch?.oid == commit.id,
                small: parent.smallRows,
                dateFormat: parent.dateFormat,
                unpushed: history.unpushed.contains(commit.id),
                unpulled: history.unpulled.contains(commit.id),
                isParent: history.parentCommits.contains(commit.id),
                selected: history.selectedIDs.contains(commit.id),
                signatures: parent.session.signatures,
                runner: parent.session.runner
            )

            return Self.reuse(view, identifier: "history-commit", in: tableView)
        }
    }

    /// 单选与多选共享完整哈希，视图刷新后可以恢复选择。
    func tableViewSelectionDidChange(_: Notification) {
        guard !isUpdating, let table else { return }

        let history = parent.session.history
        history.selectedIDs = Set(table.selectedRowIndexes.compactMap { history.commit(atRow: $0)?.id })
    }

}

// MARK: - HistoryCommitRow

/// 提交行提供中号双行和小号单行两种布局。
private struct HistoryCommitRow: View {
    /// 选中行的文字使用系统的选中文字语义色。
    private static let selectedText = Color(nsColor: .alternateSelectedControlTextColor)

    /// 当前提交元信息。
    let commit: HistoryCommit

    /// 单行独立绘制模型。
    let graph: CommitGraphRow?

    /// 指向当前提交的完整引用。
    let references: [RepositoryReference]

    /// HEAD 作为独立蓝色徽标显示。
    let isHead: Bool

    /// 小号行高为 24 pt。
    let small: Bool

    /// 提交日期的显示格式。
    let dateFormat: CommitDateFormat

    /// 未推送提交在行尾显示上箭头。
    let unpushed: Bool

    /// 未拉取提交显示下箭头与弱化背景。
    let unpulled: Bool

    /// 与基准分支比较时，分叉点及其之下属于基准分支的提交，与未拉取的提交一样置灰。
    let isParent: Bool

    /// 被选中时文本和徽标采用选中配色。
    let selected: Bool

    /// 窗口的签名结果，开启签名校验时行末显示签名按钮。
    let signatures: CommitSignatureStore

    /// 校验签名与标签签名用的执行器。
    let runner: GitRunner?

    /// 图在最左侧，标题和元信息按固定行高排列。
    var body: some View {
        HStack(spacing: 8) {
            if let graph {
                HistoryGraphView(row: graph)
                    .frame(width: CGFloat(graph.columnCount) * 10 + 7)
                    .accessibilityHidden(true)
            }
            if small {
                smallLayout
            } else {
                mediumLayout
            }
            if unpushed || unpulled {
                Image(systemName: unpushed ? "arrow.up" : "arrow.down")
                    .font(.system(size: small ? 10 : 12))
                    .accessibilityLabel(
                        AppLocalization.text(unpushed ? "history.unpushed" : "history.unpulled")
                    )
            }
        }
        .font(.system(size: small ? 11 : 12))
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(selected ? Self.selectedText : (unpulled || isParent ? .secondary : .primary))
        .background(
            (unpulled || isParent) && !selected
                ? AppPalette.color("general_alternate_row_background_color")
                : .clear
        )
        .help(commit.id + "\n" + commit.subject)
        .accessibilityElement(children: .combine)
    }

    /// 小号单行：哈希、徽标、标题、作者与日期依次排开。
    @ViewBuilder
    private var smallLayout: some View {
        hash
        badges
        Text(commit.subject).lineLimit(1)
        Spacer(minLength: 0)

        Text(commit.author)
            .foregroundStyle(selected ? Self.selectedText : .secondary)
            .lineLimit(1)

        date
        CommitSignatureButton(store: signatures, commit: commit.id, runner: runner, small: true)
    }

    /// 中号双行：作者头像在左，右侧上行为作者、徽标与日期，下行为哈希与标题。
    @ViewBuilder
    private var mediumLayout: some View {
        InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 32)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(commit.author)
                    .foregroundStyle(selected ? Self.selectedText : .secondary)
                    .lineLimit(1)

                badges
                Spacer(minLength: 0)
                date
            }

            HStack(spacing: 8) {
                hash
                Text(commit.subject).lineLimit(1)
                Spacer(minLength: 0)
                CommitSignatureButton(store: signatures, commit: commit.id, runner: runner, small: false)
            }
        }
    }

    /// 哈希使用等宽字体，动作仍使用完整 ID。
    private var hash: some View {
        Text(commit.shortID)
            .font(.system(size: small ? 10 : 12, design: .monospaced))
            .foregroundStyle(selected ? Self.selectedText : .secondary)
    }

    /// 列表按日期格式偏好显示提交人日期，完整两种日期在详情中展示。
    private var date: some View {
        Text(dateFormat.string(from: commit.commitDate))
            .foregroundStyle(selected ? Self.selectedText : .secondary)
            .lineLimit(1)
            .layoutPriority(1)
    }

    /// 引用名标记排成一行，放不下时以 “…” 结尾；标签标记可点，弹出标签的签名。
    private var badges: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                if isHead { badge("HEAD", color: "blue") }
                ForEach(references) { ref in
                    // 只有标签标记可点，点击显示标签的签名
                    if ref.isLocal || ref.isRemote {
                        badge(ref.name, color: ref.isLocal ? "blue" : "gray")
                    } else {
                        TagBadgeButton(reference: ref.id, runner: runner) { badge(ref.name, color: "yellow") }
                    }
                }
            }
            if isHead || !references.isEmpty { badge("…", color: "gray") }
        }
        .frame(maxWidth: 300, alignment: .leading)
    }

    /// 引用徽标使用 11 pt 文本和 4 pt 圆角。
    private func badge(_ title: String, color: String) -> some View {
        Text(title)
            .font(.system(size: 11))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .foregroundStyle(AppPalette.color((selected ? "selected" : color) + "_badge_text_color"))
            .background(
                AppPalette.color((selected ? "selected" : color) + "_badge_background_color"),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }
}
