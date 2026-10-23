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
        } else {
            EmptyStateView(title: AppLocalization.text("detail.empty.title"), message: "", symbol: "doc")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - CommitDetailView

/// 历史右侧的一体滚动详情：元信息、完整信息、变更文件与懒加载 Diff。
struct CommitDetailView: View {
    /// 当前提交和文件读取状态。
    @Bindable
    var history: RepositoryHistoryState

    /// 头部和所有文件共享同一个滚动区域。
    var body: some View {
        if let commit = history.selectedCommit {
            VStack(spacing: 0) {
                HStack {
                    Text(commit.shortID).font(.system(size: 13, design: .monospaced))
                    Spacer()
                    if commit.parents.count > 1 { Text(AppLocalization.text("history.firstParent")) }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(.bar)
                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        CommitMetadataView(commit: commit)
                        Text(commit.message)
                            .font(.system(size: 13))
                            .lineSpacing(3)
                            .textSelection(.enabled)
                            .padding(20)
                        Divider()

                        HStack {
                            Button(
                                AppLocalization.text(
                                    history.expandedPaths.isEmpty
                                        ? "history.expandAll"
                                        : "history.collapseAll"
                                )
                            ) {
                                history.expandAll(history.expandedPaths.isEmpty)
                            }
                            .disabled(history.changes.isEmpty)
                            Spacer()
                            Text(AppLocalization.text("history.changes", history.changes.count))
                        }
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .frame(height: 32)

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
                            }
                            .padding(.horizontal, 8)
                            Divider()
                        }
                        if history.changes.isEmpty, !history.isLoadingChanges, history.changesFailure == nil {
                            Text(AppLocalization.text("working.noDiff"))
                                .foregroundStyle(.secondary)
                                .padding(20)
                        }
                    }
                }
            }
        } else {
            EmptyStateView(
                title: AppLocalization.text(
                    history.selectedIDs.isEmpty ? "history.noSelection" : "history.multiple"
                ),
                message: "",
                symbol: "doc.text"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
                Text(commit.subject).font(.system(size: 13)).padding(.horizontal, 12)
                Text(commit.author).font(.system(size: 11)).foregroundStyle(.secondary).padding(12)
                HStack {
                    Text(commit.shortID).font(.system(size: 13, design: .monospaced))
                    Spacer()
                    Text(AppLocalization.text("history.changes", history.changes.count))
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(.bar)
            }
            List(history.changes, selection: $history.selectedPath) { file in
                CommitFileLabel(file: file).tag(file.path)
            }
            if history.isLoadingChanges {
                ProgressView(AppLocalization.text("history.loadingChanges"))
                    .controlSize(.small)
                    .padding(12)
            }
        }
        .frame(minWidth: 300)
    }
}

// MARK: - CommitFileLabel

/// 文件状态与重命名路径在两种提交详情中保持一致。
private struct CommitFileLabel: View {
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

// MARK: - CommitMetadataView

/// 完整元信息展开后包含树与父哈希，不触发额外 Git 查询。
private struct CommitMetadataView: View {
    /// 已从列表读取的提交记录。
    let commit: HistoryCommit

    /// 摘要和全部信息之间切换。
    @State
    private var expanded = false

    /// 标签与值两列对齐，值可以复制。
    var body: some View {
        HStack(alignment: .top) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                row("history.author", commit.author + " <" + commit.authorEmail + ">")
                row("history.commitDate", commit.commitDate.formatted(date: .abbreviated, time: .standard))
                row("history.hash", commit.id)
                if expanded {
                    row(
                        "history.authorDate",
                        commit.authorDate.formatted(date: .abbreviated, time: .standard)
                    )
                    row("history.committer", commit.committer + " <" + commit.committerEmail + ">")
                    row("history.treeHash", commit.tree)
                    row("history.parents", commit.parents.joined(separator: "\n"))
                }
            }
            Spacer(minLength: 4)
            Button {
                expanded.toggle()
            } label: {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(AppLocalization.text("history.metadata"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .font(.system(size: 12))
    }

    /// 每项标签统一使用弱化色，长哈希允许换行。
    private func row(_ key: String, _ value: String) -> some View {
        GridRow(alignment: .top) {
            Text(AppLocalization.text(key)).foregroundStyle(.tertiary)
            Text(value).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }
}

// MARK: - CommitFileDiffView

/// 单文件历史 Diff 复用工作区的块渲染、字体和主题，不提供写操作。
struct CommitFileDiffView: View {
    /// 当前提交的加载状态。
    let history: RepositoryHistoryState

    /// 已选择或展开的文件路径。
    let path: String

    /// 内置主题随系统外观切换。
    @Environment(\.colorScheme)
    private var colorScheme

    /// 补丁、二进制、超限和失败各自有明确状态。
    var body: some View {
        let theme = BuiltinTheme.current(dark: colorScheme == .dark)
        VStack(alignment: .leading, spacing: 0) {
            if let failure = history.diffFailures[path] {
                FailureDetailsView(failure: failure) { history.loadDiff(path) }
                    .padding(20)
            } else if let result = history.diffs[path] {
                if let diff = result.diff {
                    ForEach(diff.files) { file in
                        Text(file.headers.joined(separator: "\n"))
                            .font(.custom(theme.fontName, size: theme.fontSize))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(12)
                        if file.isBinary { Text(AppLocalization.text("working.binary")).padding(20) }
                        ForEach(file.hunks) { hunk in
                            DiffHunkView(
                                hunk: hunk,
                                theme: theme,
                                staged: false,
                                enabled: false,
                                readOnly: true
                            ) { _, _ in }
                        }
                    }
                } else {
                    Text(AppLocalization.text("working.largeDiff", (result.byteCount + 999) / 1000))
                        .padding(12)
                    Button(AppLocalization.text("working.showDiff")) {
                        history.loadDiff(path, showLarge: true)
                    }
                    .padding(12)
                }
            } else {
                ProgressView(AppLocalization.text("working.loadingDiff"))
                    .controlSize(.small)
                    .padding(20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors["background"]!.color)
    }
}
