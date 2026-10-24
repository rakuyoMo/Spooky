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
                CommitFileDiffView(history: history, path: path)
            }
            .reloadsOnDiffPreferenceChange { history.reloadDiffs() }
        } else {
            EmptyStateView(title: AppLocalization.text("detail.empty.title"), message: "", symbol: "doc")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// 显示文件树；否则显示变更集。切换提交时保持。
    @State
    private var showsTree = false

    /// 文件树的逐层读取状态。
    @State
    private var tree = CommitTreeState()

    /// 合并提交的 Diff 方式改变时重读变更集。
    @AppStorage(MergeDiffMode.preferenceKey)
    private var mergeMode = MergeDiffMode.firstParent.rawValue

    /// 鼠标是否在变更集详情上，决定操作按钮行是否显示。
    @State
    private var hovering = false

    /// 换选提交时结束比较。
    var body: some View {
        content
            .onChange(of: history.selectedIDs) { session.comparison.close() }
    }

    /// 按比较、单选、多选与未选中依次选择内容。
    @ViewBuilder
    private var content: some View {
        if session.comparison.isActive {
            RevisionComparisonView(state: session.comparison, session: session) {
                session.comparison.close()
            }
        } else if let commit = history.selectedCommit {
            VStack(spacing: 0) {
                CommitDetailBar(commit: commit, showsTree: $showsTree)
                Divider()

                if showsTree {
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
        } else if history.selectedIDs.count > 1 {
            HistoryMultipleSelectionView(session: session)
        } else {
            EmptyStateView(title: AppLocalization.text("history.noSelection"), message: "", symbol: "doc.text")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 变更集的读取进度、失败、逐个文件与空状态。
    @ViewBuilder
    private var changeRows: some View {
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
            fileSection(file)
            Divider()
        }

        if
            history.changes.isEmpty,
            !history.isLoadingChanges,
            history.changesFailure == nil
        {
            Text(AppLocalization.text("working.noDiff"))
                .foregroundStyle(.secondary)
                .padding(20)
        }
    }

    /// 滚动区域的内容：元信息、完整信息、操作按钮行、变更集摘要与逐个文件的 Diff。
    private func scrollContent(_ commit: HistoryCommit) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
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

            Divider()

            ChangesetSummaryBar(
                changes: history.changes,
                expanded: !history.expandedPaths.isEmpty,
                toggle: { history.expandAll(history.expandedPaths.isEmpty) }
            )

            changeRows
        }
    }

    /// 单个变更文件的折叠组，展开时才读取它的 Diff。
    private func fileSection(_ file: CommitFileChange) -> some View {
        DisclosureGroup(
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
            )
        ) {
            CommitFileDiffView(history: history, path: file.path)
        } label: {
            CommitFileLabel(file: file)
                .frame(height: 30)
                .contextMenu {
                    if let commit = history.selectedCommit {
                        ChangesetFileMenu(session: session, path: file.path, commit: commit)
                    }
                }
        }
        .padding(.horizontal, 8)
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
                    Text(commit.shortID).font(.system(size: 13, design: .monospaced))
                    Spacer()
                    Text(AppLocalization.text("history.changes", history.changes.count))
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
            } else if history.changes.isEmpty, history.changesFailure == nil {
                Text(AppLocalization.text("working.noDiff"))
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
        .frame(minWidth: 300)
    }

    /// 变更文件列表，右键菜单打开文件视图，并把文件恢复到工作区或导出。
    private var fileList: some View {
        List(history.changes, selection: $history.selectedPath) { file in
            CommitFileLabel(file: file)
                .tag(file.path)
                .contextMenu {
                    if let commit = history.selectedCommit {
                        ChangesetFileMenu(session: session, path: file.path, commit: commit)
                    }
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

/// 文件状态与重命名路径在提交详情、整页详情与版本比较中保持一致。
struct CommitFileLabel: View {
    /// 当前文件变更。
    let file: CommitFileChange

    /// 状态字母和路径都支持辅助功能读取。
    var body: some View {
        HStack(spacing: 8) {
            Text(file.status).frame(width: 24)
            Image(systemName: "doc").accessibilityHidden(true)
            Text(file.originalPath.map { $0 + " → " + file.path } ?? file.path)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if let additions = file.additions, let deletions = file.deletions {
                Text("+\(additions) −\(deletions)").foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11))
        .help(file.path)
    }
}

// MARK: - CommitFileDiffView

/// 单文件历史 Diff：读取失败、读取中与已读取的补丁各有明确状态，补丁复用只读 Diff 视图。
struct CommitFileDiffView: View {
    /// 当前提交的加载状态。
    let history: RepositoryHistoryState

    /// 已选择或展开的文件路径。
    let path: String

    /// 失败可重试，补丁读取完成前显示进度。
    var body: some View {
        if let failure = history.diffFailures[path] {
            FailureDetailsView(failure: failure) { history.loadDiff(path) }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let result = history.diffs[path], let source = history.diffSource(path: path) {
            ReadOnlyFileDiffView(result: result, source: source) {
                history.loadDiff(path, showLarge: true)
            }
        } else {
            ProgressView(AppLocalization.text("working.loadingDiff"))
                .controlSize(.small)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
