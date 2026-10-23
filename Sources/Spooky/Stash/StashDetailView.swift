import SpookyKit
import SwiftUI

// MARK: - StashDetailView

/// 储藏视图右栏：单选时显示元信息、操作按钮、变更文件与懒加载 Diff，多选时只提供删除。
struct StashDetailView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 单选、多选与未选三种状态。
    var body: some View {
        let stashes = session.stashes

        if let stash = stashes.selectedStash {
            VStack(spacing: 0) {
                HStack {
                    Text(String(stash.id.prefix(8))).font(.system(size: 13, design: .monospaced))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(.bar)

                Divider()

                ScrollView {
                    scrollContent(stash)
                }
            }
        } else if stashes.selectedIDs.count > 1 {
            VStack(spacing: 20) {
                EmptyStateView(
                    title: AppLocalization.text("stash.multiple", stashes.selectedIDs.count),
                    message: "",
                    symbol: "tray.2"
                )

                Button(AppLocalization.text("stash.deleteButton")) {
                    session.deleteStashes(stashes.selectedStashes)
                }
                .disabled(!session.canDelete(stashes.selectedStashes))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyStateView(title: AppLocalization.text("stash.noSelection"), message: "", symbol: "tray")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Layout

extension StashDetailView {
    /// 全部展开或收起的按钮与变更文件数。
    private var changesBar: some View {
        let stashes = session.stashes

        return HStack {
            Button(AppLocalization.text(stashes.expandedPaths.isEmpty ? "history.expandAll" : "history.collapseAll")) {
                stashes.expandAll(stashes.expandedPaths.isEmpty)
            }
            .disabled(stashes.changes.isEmpty)

            Spacer()

            Text(AppLocalization.text("history.changes", stashes.changes.count))
        }
        .font(.system(size: 11))
        .padding(.horizontal, 8)
        .frame(height: 32)
    }

    /// 滚动区域：元信息、说明、操作按钮、变更文件栏与逐个文件的 Diff。
    private func scrollContent(_ stash: StashEntry) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            metadata(stash)

            Text(stash.title)
                .font(.system(size: 13))
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(20)

            HStack(spacing: 8) {
                Button(AppLocalization.text("stash.applyButton")) { session.requestApplyStash(stash) }
                    .disabled(!session.canApply(stash))

                Button(AppLocalization.text("stash.deleteButton")) { session.deleteStashes([stash]) }
                    .disabled(!session.canDelete([stash]))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            changesBar
            changeList(stash)
        }
    }

    /// 来源分支、基准提交、日期与储藏哈希，值可以复制。
    private func metadata(_ stash: StashEntry) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
            row("stash.basedOn", stash.branch ?? "—")
            row("stash.baseCommit", stash.base)
            row("stash.date", stash.date.formatted(date: .abbreviated, time: .standard))
            row("stash.hash", stash.id)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .font(.system(size: 12))
    }

    /// 变更文件的读取状态与逐个文件的折叠组。
    @ViewBuilder
    private func changeList(_ stash: StashEntry) -> some View {
        let stashes = session.stashes

        if stashes.isLoadingChanges {
            ProgressView(AppLocalization.text("history.loadingChanges"))
                .controlSize(.small)
                .padding(20)
        }

        if let failure = stashes.changesFailure {
            FailureDetailsView(failure: failure) { stashes.loadChanges() }
                .padding(20)
        }

        ForEach(stashes.changes) { change in
            fileSection(change, in: stash)
            Divider()
        }

        if stashes.changes.isEmpty, !stashes.isLoadingChanges, stashes.changesFailure == nil {
            Text(AppLocalization.text("working.noDiff"))
                .foregroundStyle(.secondary)
                .padding(20)
        }
    }

    /// 单个文件的折叠组，展开时才读取 Diff；文件行可以拖到工作区，只应用这个文件。
    private func fileSection(_ change: StashFileChange, in stash: StashEntry) -> some View {
        let stashes = session.stashes

        return DisclosureGroup(
            isExpanded: Binding(
                get: { stashes.expandedPaths.contains(change.id) },
                set: {
                    if $0 {
                        stashes.expandedPaths.insert(change.id)
                        stashes.loadDiff(change.id)
                    } else {
                        stashes.expandedPaths.remove(change.id)
                    }
                }
            )
        ) {
            StashFileDiffView(stashes: stashes, path: change.id)
        } label: {
            StashFileLabel(change: change)
                .frame(height: 30)
                .onDrag { dragProvider(change, in: stash) }
        }
        .padding(.horizontal, 8)
    }

    /// 标签与值两列对齐，长哈希允许换行。
    private func row(_ key: String, _ value: String) -> some View {
        GridRow(alignment: .top) {
            Text(AppLocalization.text(key)).foregroundStyle(.tertiary)
            Text(value).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }

    /// 储藏文件的拖动载荷：储藏哈希与文件路径。
    private func dragProvider(_ change: StashFileChange, in stash: StashEntry) -> NSItemProvider {
        guard let repository = session.repository else {
            return NSItemProvider()
        }

        return RepositoryDragPayload(
            repository: repository,
            kind: .stashFile,
            reference: stash.id,
            path: change.id
        )
        .provider()
    }
}

// MARK: - StashFileLabel

/// 文件状态、路径与增删行数；随 “包含未跟踪文件” 保存的文件另有标注。
private struct StashFileLabel: View {
    /// 当前文件变更。
    let change: StashFileChange

    /// 状态字母和路径都支持辅助功能读取。
    var body: some View {
        HStack(spacing: 8) {
            Text(change.file.status).frame(width: 24)
            Image(systemName: "doc").accessibilityHidden(true)

            Text(change.file.originalPath.map { $0 + " → " + change.file.path } ?? change.file.path)
                .lineLimit(1)
                .truncationMode(.middle)

            if change.isUntracked {
                Text(AppLocalization.text("stash.untracked")).foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let additions = change.file.additions, let deletions = change.file.deletions {
                Text("+\(additions) −\(deletions)").foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11))
        .help(change.file.path)
    }
}

// MARK: - StashFileDiffView

/// 单文件的只读补丁，沿用工作区的块渲染、字体与主题。
private struct StashFileDiffView: View {
    /// 当前储藏的读取状态。
    let stashes: RepositoryStashState

    /// 展开的文件路径。
    let path: String

    /// 内置主题随系统外观切换。
    @Environment(\.colorScheme)
    private var colorScheme

    /// 补丁、二进制、超限和失败各自有明确状态。
    var body: some View {
        let theme = TextTheme.current(dark: colorScheme == .dark)

        VStack(alignment: .leading, spacing: 0) {
            if let failure = stashes.diffFailures[path] {
                FailureDetailsView(failure: failure) { stashes.loadDiff(path) }
                    .padding(20)
            } else if let result = stashes.diffs[path] {
                if let diff = result.diff {
                    ForEach(diff.files) { file in
                        fileDiff(file, theme: theme)
                    }
                } else {
                    Text(AppLocalization.text("working.largeDiff", (result.byteCount + 999) / 1000))
                        .padding(12)

                    Button(AppLocalization.text("working.showDiff")) {
                        stashes.loadDiff(path, showLarge: true)
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
        .background(theme.colors["background"]?.color ?? .clear)
    }

    /// 补丁头、二进制提示与只读的块。
    @ViewBuilder
    private func fileDiff(_ file: DiffFile, theme: TextTheme) -> some View {
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
}
