import SpookyKit
import SwiftUI

// MARK: - RevisionComparisonView

/// 两个版本的比较：40 pt 顶栏是两侧名字与 `Commits | Changeset` 切换，下面是目标独有的提交或两侧之间的改动。
struct RevisionComparisonView: View {
    /// 比较的读取状态。
    @Bindable
    var state: RevisionComparisonState

    /// 当前仓库会话，双击提交时打开它的详情。
    let session: RepositorySession

    /// 结束比较的入口；嵌在别的详情里、不能单独关闭时为空。
    var close: (() -> Void)? = nil

    /// 读取失败时在内容上方显示诊断。
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let failure = state.failure {
                FailureDetailsView(failure: failure)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if state.showsChangeset {
                ScrollView {
                    changeset
                }
                .reloadsOnDiffPreferenceChange { state.reloadDiffs() }
            } else {
                commitList
            }
        }
    }

    /// 顶栏：基准 → 目标、视图切换与关闭按钮。
    private var header: some View {
        HStack(spacing: 8) {
            Text((state.base?.title ?? "") + " → " + (state.target?.title ?? ""))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer(minLength: 8)

            Picker("", selection: $state.showsChangeset) {
                Text(AppLocalization.text("compare.commits")).tag(false)
                Text(AppLocalization.text("history.changeset")).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            .accessibilityLabel(AppLocalization.text("compare.view"))

            if let close {
                Button(action: close) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(AppLocalization.text("compare.close"))
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 40)
        .background(.bar)
    }

    /// 目标独有的提交，滚到最后一行时续载；双击打开提交详情。
    @ViewBuilder
    private var commitList: some View {
        if state.commits.isEmpty, !state.isLoadingCommits {
            EmptyStateView(title: AppLocalization.text("history.empty"), message: "", symbol: "clock")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(state.commits) { commit in
                ComparisonCommitRow(commit: commit)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { session.showCommit(commit) }
                    .onAppear {
                        if commit.id == state.commits.last?.id, state.hasMoreCommits {
                            state.loadCommits()
                        }
                    }
            }
            .listStyle(.inset)
        }
    }

    /// 改动摘要、全部展开 / 收起与逐个文件的补丁。
    private var changeset: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ChangesetSummaryBar(
                changes: state.changes,
                expanded: !state.expandedPaths.isEmpty,
                toggle: { state.expandAll(state.expandedPaths.isEmpty) }
            )

            if state.isLoadingChanges {
                ProgressView(AppLocalization.text("history.loadingChanges"))
                    .controlSize(.small)
                    .padding(20)
            }

            ForEach(state.changes) { file in
                fileSection(file)
                Divider()
            }

            if state.changes.isEmpty, !state.isLoadingChanges, state.failure == nil {
                Text(AppLocalization.text("working.noDiff"))
                    .foregroundStyle(.secondary)
                    .padding(20)
            }
        }
    }

    /// 单个文件的折叠组，展开时才读取补丁。
    private func fileSection(_ file: CommitFileChange) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { state.expandedPaths.contains(file.path) },
                set: {
                    if $0 {
                        state.expandedPaths.insert(file.path)
                        state.loadDiff(file.path)
                    } else {
                        state.expandedPaths.remove(file.path)
                    }
                }
            )
        ) {
            fileDiff(file.path)
        } label: {
            CommitFileLabel(file: file)
                .frame(height: 30)
        }
        .padding(.horizontal, 8)
    }

    /// 文件补丁的失败、读取中与已读取三种状态。
    @ViewBuilder
    private func fileDiff(_ path: String) -> some View {
        if let failure = state.diffFailures[path] {
            FailureDetailsView(failure: failure) { state.loadDiff(path) }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let result = state.diffs[path], let source = state.diffSource(path: path) {
            ReadOnlyFileDiffView(result: result, source: source) {
                state.loadDiff(path, showLarge: true)
            }
        } else {
            ProgressView(AppLocalization.text("working.loadingDiff"))
                .controlSize(.small)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - ComparisonCommitRow

/// 比较里的一个提交：头像、作者与日期，下行是短哈希与标题。
private struct ComparisonCommitRow: View {
    /// 提交元信息。
    let commit: HistoryCommit

    /// 日期与历史的提交行一样跟随 Settings → General 的日期格式。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

    /// 两行文字与 34 pt 头像。
    var body: some View {
        HStack(spacing: 8) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(commit.author)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(dateFormat.string(from: commit.commitDate))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(commit.shortID)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(commit.subject)
                        .lineLimit(1)
                }
            }
        }
        .font(.system(size: 12))
        .padding(.vertical, 4)
        .help(commit.id + "\n" + commit.subject)
        .accessibilityElement(children: .combine)
    }
}
