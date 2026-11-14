import SpookyKit
import SwiftUI

// MARK: - StashDetailView

/// 储藏视图右栏：单选时与提交详情同一版式，显示储藏提交的元信息、操作条、说明与变更集或文件树；多选时只提供删除。
struct StashDetailView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 显示储藏提交的文件树；否则显示变更集。
    @State
    private var showsTree = false

    /// 文件树的逐层读取状态。
    @State
    private var tree = CommitTreeState()

    /// 鼠标是否在变更集详情上，决定操作条是否显示。
    @State
    private var hovering = false

    /// 单选、多选与未选三种状态。
    var body: some View {
        let stashes = session.stashes

        if let stash = stashes.selectedStash {
            detail(stash)
        } else if stashes.selectedIDs.count > 1 {
            EmptyStateView(
                title: AppLocalization.text("stash.multiple", stashes.selectedIDs.count),
                message: "",
                symbol: "tray.2"
            ) {
                EmptyStateButton(AppLocalization.text("stash.deleteButton")) {
                    session.deleteStashes(stashes.selectedStashes)
                }
                .disabled(!session.canDelete(stashes.selectedStashes))
            }
        } else {
            EmptyStateView(title: AppLocalization.text("stash.noSelection"), message: "", symbol: "tray")
        }
    }
}

// MARK: - Layout

extension StashDetailView {
    /// 单选的详情：储藏提交与变更文件读出后显示头部与内容，此前是读取进度或可重试的失败。
    @ViewBuilder
    private func detail(_ stash: StashEntry) -> some View {
        let stashes = session.stashes

        if let commit = stashes.commit {
            VStack(spacing: 0) {
                CommitDetailBar(commit: commit, showsTree: $showsTree)
                Divider()

                if showsTree {
                    CommitTreeView(tree: tree, session: session, commit: commit)
                } else {
                    ScrollView {
                        scrollContent(stash, commit: commit)
                    }
                    .onHover { hovering = $0 }
                    .reloadsOnDiffPreferenceChange { stashes.reloadDiffs() }
                }
            }
        } else if let failure = stashes.changesFailure {
            FailureDetailsView(failure: failure) { stashes.loadChanges() }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 滚动区域：元信息、压在分隔线上的操作条、说明原文、变更集摘要与逐个文件的 Diff，左右边距与提交详情相同。
    ///
    /// - Parameters:
    ///   - stash: 详情显示的储藏。
    ///   - commit: 储藏提交的元信息。
    private func scrollContent(_ stash: StashEntry, commit: HistoryCommit) -> some View {
        let stashes = session.stashes
        let inset = CommitDetailView.contentInset

        return LazyVStack(alignment: .leading, spacing: 0) {
            CommitMetadataView(
                commit: commit,
                signature: nil,
                references: [.stash(objectID: stash.id)],
                isHead: false,
                runner: session.runner
            )

            ZStack {
                Divider()

                CommitActionRow(session: session, stash: stash, hovering: hovering)
                    .padding(.horizontal, inset)
            }

            // 说明写 Git 存下的原文，包括 “On <分支>: ” 前缀
            Text(commit.message)
                .font(.system(size: 13))
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(.horizontal, 3)
                .padding(.vertical, 8)
                .padding(.trailing, 20)
                .padding(.horizontal, inset)

            ChangesetSummaryBar(
                changes: stashes.changes.map(\.file),
                expanded: stashes.allItemsExpanded,
                toggle: { stashes.expandAll(!stashes.allItemsExpanded) }
            )
            .padding(.horizontal, inset)

            Divider()
                .padding(.horizontal, inset)

            changeRows(stash)
        }
    }

    /// 逐个变更文件，每行下面一条分隔线，放在与头部相同的左右边距里。
    ///
    /// - Parameter stash: 详情显示的储藏。
    private func changeRows(_ stash: StashEntry) -> some View {
        ForEach(session.stashes.changes) { change in
            VStack(spacing: 0) {
                fileSection(change, in: stash)
                Divider()
            }
            .padding(.horizontal, CommitDetailView.contentInset)
        }
    }

    /// 单个文件，展开时才读取 Diff；文件行可以拖到工作区，只应用这个文件；右键用比较工具比较它与储藏的基准。
    private func fileSection(_ change: StashFileChange, in stash: StashEntry) -> some View {
        let stashes = session.stashes

        return ChangesetFileRow(
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
            ),
            drag: { dragProvider(change, in: stash) }
        ) {
            CommitFileLabel(file: change.file)
        } menu: {
            Button(
                AppLocalization.text(
                    "externalTool.openDiffAt",
                    RepositorySession.fileName(change.file.path),
                    String(stash.id.prefix(8))
                )
            ) {
                session.openDiffTool(for: stash, changes: [change])
            }
        } diff: {
            StashFileDiffView(stashes: stashes, path: change.id)
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

// MARK: - StashFileDiffView

/// 单文件的只读补丁：读取失败、读取中与已读取的补丁各有明确状态，补丁复用只读 Diff 视图。
private struct StashFileDiffView: View {
    /// 当前储藏的读取状态。
    let stashes: RepositoryStashState

    /// 展开的文件路径。
    let path: String

    /// 失败可重试，补丁读取完成前显示进度。
    var body: some View {
        if let failure = stashes.diffFailures[path] {
            FailureDetailsView(failure: failure) { stashes.loadDiff(path) }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let result = stashes.diffs[path], let source = stashes.diffSource(path: path) {
            ReadOnlyFileDiffView(result: result, source: source) {
                stashes.loadDiff(path, showLarge: true)
            }
        } else {
            ChangesetDiffLoadingView()
        }
    }
}
