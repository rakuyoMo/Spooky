import SpookyKit
import SwiftUI

// MARK: - CommitPageDiffView

/// 整页提交的右侧只展示当前选择文件的补丁。
struct CommitPageDiffView: View {
    /// 与左侧列表共享选择。
    let history: RepositoryHistoryState

    /// 未选择文件时保持明确的空状态。
    var body: some View {
        if let path = history.selectedPath {
            ScrollView {
                CommitFileDiffView(history: history, path: path, presentation: .standalone)
            }
            .reloadsOnDiffPreferenceChange { history.reloadDiffs() }
        } else {
            EmptyStateView(title: AppLocalization.text("detail.empty.title"), message: "", symbol: "doc")
        }
    }
}

// MARK: - CommitDetailView

/// 历史右侧的详情：单选时是提交的一体滚动详情或文件树，多选时是选中数与比较入口，比较两个版本时是比较视图。
struct CommitDetailView: View {
    /// 当前提交和文件读取状态。
    @Bindable
    var history: RepositoryHistoryState

    /// 文件右键菜单打开文件视图，并把文件恢复到工作区或导出。
    let session: RepositorySession

    /// 文件树的逐层读取状态。
    @State
    private var tree = CommitTreeState()

    /// 合并提交的 Diff 方式改变时重读变更集。
    @AppStorage(MergeDiffMode.preferenceKey)
    private var mergeMode = MergeDiffMode.firstParent.rawValue

    /// 鼠标是否在变更集详情上，决定操作按钮行是否显示。
    @State
    private var hovering = false

    /// 变更文件行所在的滚动内容有键盘焦点时，↑ ↓ 移动文件的选中。
    @FocusState
    private var filesFocused: Bool

    /// 窗口是否在前，决定文件行选中底的颜色。
    @Environment(\.appearsActive)
    private var appearsActive

    /// 换选提交时结束比较。
    var body: some View {
        content
            .onChange(of: history.selectedIDs) {
                if history === session.history { session.comparison.close() }
            }
    }

    /// 按比较、单选、多选与未选中依次选择内容。
    @ViewBuilder
    private var content: some View {
        switch session.commitDetailContent(for: history) {
        case .comparison(let comparison):
            RevisionComparisonView(state: comparison, session: session) { comparison.close() }

        case .commit(let commit):
            VStack(spacing: 0) {
                CommitDetailBar(commit: commit, showsTree: $history.showsTree)
                Divider()

                if history.showsTree {
                    CommitTreeView(tree: tree, session: session, commit: commit)
                } else {
                    ScrollView {
                        scrollContent(commit)
                    }
                    .onHover { hovering = $0 }
                }
            }
            .reloadsOnDiffPreferenceChange { history.reloadDiffs() }
            .onChange(of: mergeMode) { history.loadChanges() }
            .task(id: commit.id) {
                // 详情总是校验所选提交的签名，结果与列表共用
                if let runner = session.runner {
                    session.signatures.request(commit.id, runner: runner)
                }
            }

        case .selection:
            if history.selectedIDs.count > 1 {
                HistoryMultipleSelectionView(session: session)
            } else {
                EmptyStateView(title: AppLocalization.text("history.noSelection"), message: "", symbol: "doc.text")
            }
        }
    }

    /// 文件行选中底的颜色：滚动内容有焦点且窗口在前时是强调色。
    private var fileSelectionColor: NSColor {
        .listSelection(
            emphasized: appearsActive && filesFocused,
            key: appearsActive,
            background: .windowBackgroundColor
        )
    }

    /// 滚动区域的内容：元信息、完整信息、操作按钮行、变更集摘要与逐个文件的 Diff。
    private func scrollContent(_ commit: HistoryCommit) -> some View {
        // 焦点在这里读出：文件行是 `LazyVStack` 惰性排出的，只在行里读时，焦点变化不会让已排出的行重画
        let selectionColor = fileSelectionColor

        return LazyVStack(alignment: .leading, spacing: 0) {
            CommitMetadataView(commit: commit, signature: session.signatures.signatures[commit.id])

            Text(commit.message)
                .font(.system(size: 13))
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(20)

            // 在看 HEAD 分支时，信息下面是 Rollback 与 Revert
            if session.isViewingHead {
                CommitActionRow(session: session, commit: commit, hovering: hovering)
                    .padding(.bottom, 8)
            }

            // 提交说明与 Expand All 一行之间不画分隔线，这一行下方画一条，隔开第一个文件行
            ChangesetSummaryBar(
                changes: history.changes,
                expanded: history.allItemsExpanded,
                toggle: { history.expandAll(!history.allItemsExpanded) }
            )

            Divider()

            changeRows(selectionColor: selectionColor)
        }
        .focusable()
        .focused($filesFocused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.upArrow, .downArrow], phases: [.down, .repeat]) { press in
            moveFileSelection(press)
        }
    }

    /// 变更集的读取进度、失败、逐个文件与空状态。
    ///
    /// - Parameter selectionColor: 文件行选中底的颜色。
    @ViewBuilder
    private func changeRows(selectionColor: NSColor) -> some View {
        if history.isLoadingChanges {
            ProgressView(AppLocalization.text("history.loadingChanges"))
                .controlSize(.small)
                .padding(20)
        }

        if let failure = history.changesFailure {
            FailureDetailsView(failure: failure) { history.loadChanges() }
                .padding(20)
        }

        ForEach(history.changes) { file in
            fileSection(file, selectionColor: selectionColor)
            Divider()
        }
    }

    /// 单个变更文件，展开时才读取它的 Diff；整行都能点选。
    ///
    /// - Parameters:
    ///   - file: 变更文件。
    ///   - selectionColor: 选中时垫在文件行下面的颜色。
    private func fileSection(_ file: CommitFileChange, selectionColor: NSColor) -> some View {
        ChangesetFileRow(
            isExpanded: Binding(
                get: { history.expandedPaths.contains(file.path) },
                set: {
                    if $0 {
                        history.expandedPaths.insert(file.path)
                        history.loadDiff(file.path)
                    } else {
                        history.expandedPaths.remove(file.path)
                    }
                }
            ),
            selection: history.fileSelection.paths.contains(file.path) ? selectionColor : nil,
            select: { clickFile(file.path) }
        ) {
            CommitFileLabel(file: file)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .contextMenu {
                    if let commit = history.selectedCommit {
                        ChangesetFileMenu(session: session, path: file.path, originalPath: file.originalPath, commit: commit)
                    }
                }
                .onDrag { CommitFileDragging.provider(file, session: session) }
        } diff: {
            CommitFileDiffView(history: history, path: file.path)
        }
    }

    /// 点选一个文件行：按住 ⇧ 连续选，按住 ⌘ 切换这一行；键盘焦点随之交给变更文件所在的滚动内容。
    private func clickFile(_ path: String) {
        let modifiers = NSEvent.modifierFlags

        history.fileSelection.click(
            path,
            extending: modifiers.contains(.shift),
            toggling: modifiers.contains(.command),
            order: history.changes.map(\.path)
        )

        filesFocused = true
    }

    /// ↑ ↓ 把文件的选中移到上一行或下一行，按住 ⇧ 从锚点连续选；没有变更文件时交给别处处理。
    private func moveFileSelection(_ press: KeyPress) -> KeyPress.Result {
        guard !history.changes.isEmpty else {
            return .ignored
        }

        history.fileSelection.move(
            by: press.key == .upArrow ? -1 : 1,
            extending: press.modifiers.contains(.shift),
            order: history.changes.map(\.path)
        )

        return .handled
    }
}

// MARK: - CommitFileListView

/// 完整提交页的左侧文件列表，右侧复用同一只读补丁。
struct CommitFileListView: View {
    /// 连接横幅所属的窗口会话。
    let session: RepositorySession

    /// 与历史列表共享选择。
    @Bindable
    var history: RepositoryHistoryState

    /// 返回历史只退出详情子视图。
    let back: () -> Void

    /// 版本选择器是否打开。
    @State
    private var choosingRevision = false

    /// 提交卡片、文件数与原生选择列表。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ConnectionStatusView(session: session)

            Button(action: back) {
                Label(AppLocalization.text("history.back"), systemImage: "chevron.left")
            }
            .padding(8)

            if let commit = history.selectedCommit {
                card(commit)

                HStack {
                    revisionButton(commit)
                    Spacer()
                    Text(ChangesetSummaryBar.fileCount(history.changes.count))
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(.bar)
            }

            fileList

            if history.isLoadingChanges {
                ProgressView(AppLocalization.text("history.loadingChanges"))
                    .controlSize(.small)
                    .padding(12)
            }
        }
        .frame(minWidth: 300)
    }

    /// 读取完成且没有失败时，空列表才显示占位行。
    var emptyMessage: String? {
        guard history.changes.isEmpty, !history.isLoadingChanges, history.changesFailure == nil else {
            return nil
        }

        return AppLocalization.text("history.noChanges")
    }

    /// 变更文件列表，右键菜单打开文件视图，并把文件恢复到工作区或导出。
    private var fileList: some View {
        List(selection: $history.selectedPath) {
            if let emptyMessage {
                Text(emptyMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(nsColor: .controlTextColor))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .listRowInsets(EdgeInsets())
            }

            ForEach(history.changes) { file in
                CommitFileLabel(file: file)
                    .tag(file.path)
                    .contextMenu {
                        if let commit = history.selectedCommit {
                            ChangesetFileMenu(session: session, path: file.path, originalPath: file.originalPath, commit: commit)
                        }
                    }
                    .onDrag { CommitFileDragging.provider(file, session: session) }
            }
        }
    }

    /// 短哈希按钮：点开版本选择器，双击其中一个提交换成它的整页详情。
    private func revisionButton(_ commit: HistoryCommit) -> some View {
        Button(commit.shortID) {
            choosingRevision = true
        }
        .buttonStyle(.accessoryBar)
        .font(.custom("Menlo", size: 13))
        .accessibilityLabel(AppLocalization.text("showFile.revision"))
        .popover(isPresented: $choosingRevision, arrowEdge: .bottom) {
            CommitSelectorView(session: session) {
                choosingRevision = false
                session.showCommit($0)
            }
        }
    }

    /// 提交卡片：48 pt 头像、可换行的标题、作者与日期一行，以及有效签名的按钮。
    private func card(_ commit: HistoryCommit) -> some View {
        HStack(alignment: .top, spacing: 8) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(commit.subject)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)

                Text(byline(commit))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            CommitSignatureButton(store: session.signatures, commit: commit.id, runner: session.runner, small: false)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
    }

    /// 作者与提交日期；提交人不是作者时写出提交人。
    private func byline(_ commit: HistoryCommit) -> String {
        let date = commit.commitDate.formatted(date: .abbreviated, time: .shortened)

        guard commit.committer != commit.author else {
            return AppLocalization.text("history.committedOn", commit.author, date)
        }

        return AppLocalization.text("history.committedWith", commit.author, commit.committer, date)
    }
}

// MARK: - CommitFileLabel

/// 文件状态与重命名路径在提交详情、整页详情、版本比较与目录的文件历史中保持一致。
struct CommitFileLabel: View {
    /// 当前文件变更。
    let file: CommitFileChange

    /// 状态只用与工作区相同的徽标表示，辅助技术读出状态全称与路径。
    var body: some View {
        HStack(spacing: 8) {
            FileChangeStatusView(code: file.status)
            Text(file.originalPath.map { $0 + " → " + file.path } ?? file.path)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if let additions = file.additions, let deletions = file.deletions {
                Text("+\(additions) −\(deletions)").foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11))
    }
}

// MARK: - CommitFileDiffView

/// 单文件历史 Diff：读取失败、读取中与已读取的补丁各有明确状态，补丁复用只读 Diff 视图。
struct CommitFileDiffView: View {
    /// 当前提交的加载状态。
    let history: RepositoryHistoryState

    /// 已选择或展开的文件路径。
    let path: String

    /// 独立文件与变更集内嵌的滚动方式。
    var presentation = DiffPresentation.embedded

    /// 失败可重试，补丁读取完成前显示进度。
    var body: some View {
        if let failure = history.diffFailures[path] {
            FailureDetailsView(failure: failure) { history.loadDiff(path) }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let result = history.diffs[path], let source = history.diffSource(path: path) {
            ReadOnlyFileDiffView(result: result, source: source, presentation: presentation) {
                history.loadDiff(path, showLarge: true)
            }
        } else {
            ChangesetDiffLoadingView()
        }
    }
}
