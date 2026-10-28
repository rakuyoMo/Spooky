import SpookyKit
import SwiftUI

// MARK: - CommitSelectorView

/// 整页提交详情的版本选择器：上面是搜索框，下面是从 HEAD 起的提交列表。
///
/// 打开时高亮 HEAD；单击与回车只移动高亮，双击一行才换到那个提交。
struct CommitSelectorView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 双击选定一个提交。
    let select: (HistoryCommit) -> Void

    /// 提交列表的读取状态。
    @State
    private var state = CommitSelectorState()

    /// 搜索框的内容。
    @State
    private var query = ""

    /// 480 × 272：距上、左、右 20 pt 的搜索框，下面 8 pt 是贴满宽度的列表。
    var body: some View {
        VStack(spacing: 8) {
            TextField(AppLocalization.text("showFile.searchRevisions"), text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(height: 24)
                .padding([.top, .horizontal], 20)

            list
                .frame(height: 220)
        }
        .frame(width: 480, height: 272)
        .onAppear { state.open(runner: session.runner, head: session.status?.branch.oid) }
        .onDisappear { state.close() }
        .onChange(of: query) { state.search(query) }
    }

    /// 提交列表；读取失败时显示诊断与重试。
    @ViewBuilder
    private var list: some View {
        if let failure = state.failure {
            FailureDetailsView(failure: failure) { state.reload() }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            List(state.commits, selection: $state.highlightedID) { commit in
                CommitSelectorRow(commit: commit)
                    .tag(commit.id)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { select(commit) }
                    .onAppear { loadMoreIfLast(commit) }
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .overlay {
                if state.isLoading, state.commits.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    /// 列表显示到最后一行时续载下一页。
    private func loadMoreIfLast(_ commit: HistoryCommit) {
        if commit.id == state.commits.last?.id {
            state.loadNextPage()
        }
    }
}

// MARK: - CommitSelectorRow

/// 版本选择器的一行：32 pt 头像，右边上行是作者与日期，下行是短哈希与标题。
private struct CommitSelectorRow: View {
    /// 这一行的提交。
    let commit: HistoryCommit

    /// 提交日期的显示格式。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

    /// 38 pt 高的两行布局，文字都是 11 pt。
    var body: some View {
        HStack(spacing: 6) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(commit.author)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(dateFormat.string(from: commit.commitDate))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text(commit.shortID)
                        .font(.custom("Menlo", size: 11))
                        .foregroundStyle(.secondary)

                    Text(commit.subject)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .font(.system(size: 11))
        }
        .frame(height: 38)
        .accessibilityElement(children: .combine)
    }
}
