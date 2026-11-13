import SpookyKit
import SwiftUI

// MARK: - CommitFileListView

/// 整页提交详情的左栏：40 pt 工具条（版本选择与文件数）在上，68 pt 提交卡片在下，再下面是变更文件列表；右栏复用同一只读补丁。
///
/// 返回历史由 View › Back、⌘[ 与工具栏承担，左栏里没有返回按钮。
struct CommitFileListView: View {
    /// 连接横幅所属的窗口会话。
    let session: RepositorySession

    /// 与历史列表共享选择。
    @Bindable
    var history: RepositoryHistoryState

    /// 版本选择器是否打开。
    @State
    private var choosingRevision = false

    /// 工具条、提交卡片与原生选择列表。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ConnectionStatusView(session: session)

            if let commit = history.selectedCommit {
                toolbar(commit)

                card(commit)
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

    /// 工具条上的文件数，按真实的变更文件计数；读取中与没有变更文件时不显示。
    var fileCount: String? {
        guard !history.isLoadingChanges, !history.changes.isEmpty else {
            return nil
        }

        return ChangesetSummaryBar.fileCount(history.changes.count)
    }

    /// 变更文件列表：右键菜单作用于被点的文件，双击打开这个提交里的那个版本。
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
                CommitPageFileRow(file: file)
                    .tag(file.path)
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    .onDrag { CommitFileDragging.provider(file, session: session) }
            }
        }
        .contextMenu(forSelectionType: String.self) { paths in
            let files = history.changes.filter { paths.contains($0.path) }

            if let commit = history.selectedCommit, !files.isEmpty {
                ChangesetFileMenu(session: session, files: files, commit: commit)
            }
        } primaryAction: { paths in
            openFiles(paths)
        }
    }

    /// 卡片上排的作者与提交人一行：两人的姓名与邮箱都相同时只写作者，否则写出两人；日期固定为短日期、不带时间。
    ///
    /// - Parameters:
    ///   - commit: 详情显示的提交。
    ///   - locale: 日期所用的语言区域，测试固定。
    ///   - timeZone: 日期所用的时区，测试固定。
    static func byline(
        _ commit: HistoryCommit,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .short
        formatter.timeStyle = .none

        let date = formatter.string(from: commit.commitDate)

        let sameIdentity =
            commit.author == commit.committer
                && commit.authorEmail == commit.committerEmail

        guard !sameIdentity else {
            return AppLocalization.text("history.committedOn", commit.author, date)
        }

        return AppLocalization.text("history.committedWith", commit.author, commit.committer, date)
    }

    /// 40 pt 工具条：左边是版本按钮，右边是文件数。
    private func toolbar(_ commit: HistoryCommit) -> some View {
        HStack {
            revisionButton(commit)

            Spacer()

            if let fileCount {
                Text(fileCount)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.bar)
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

    /// 68 pt 提交卡片：48 pt 头像，右边上排 11 pt 的作者与提交人，下排 13 pt 的标题，最右是有效签名的按钮。
    private func card(_ commit: HistoryCommit) -> some View {
        HStack(alignment: .top, spacing: 8) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(Self.byline(commit))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(commit.subject)
                    .font(.system(size: 13))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            CommitSignatureButton(store: session.signatures, commit: commit.id, runner: session.runner, small: false)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .frame(height: 68)
    }

    /// 双击或回车：按变更集的顺序打开这些文件在详情提交里的版本，内容经 Git 取到会话缓存；失败时显示错误。
    private func openFiles(_ paths: Set<String>) {
        guard let commit = history.selectedCommit else {
            return
        }

        let ordered = history.changes
            .map(\.path)
            .filter { paths.contains($0) }

        session.open(ordered, at: commit.id)
    }
}

// MARK: - CommitPageFileRow

/// 整页详情的一个变更文件，高 48 pt：18 × 18 的状态图标，右边上一行是文件名与绿色的新增、红色的删除行数，下一行是 11 pt 的路径。
///
/// 二进制文件没有行数，不写这两个数。
struct CommitPageFileRow: View {
    /// 当前文件变更。
    let file: CommitFileChange

    /// 状态图标与两行文字隔 8 pt。
    var body: some View {
        HStack(spacing: 8) {
            FileChangeStatusView(code: file.status, size: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(RepositorySession.fileName(file.path))
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let additions = file.additions, let deletions = file.deletions {
                        Text("+\(additions)")
                            .foregroundStyle(Color(nsColor: .systemGreen))

                        Text("−\(deletions)")
                            .foregroundStyle(Color(nsColor: .systemRed))
                    }
                }
                .font(.system(size: 11))

                // 重命名与复制写出原路径
                Text(file.originalPath.map { $0 + " → " + file.path } ?? file.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 48)
    }
}
