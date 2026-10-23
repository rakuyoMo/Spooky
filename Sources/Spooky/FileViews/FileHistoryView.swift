import SpookyKit
import SwiftUI

// MARK: - FileHistoryTimelineView

/// 文件历史的左栏：文件按钮与提交数、日期筛选，以及按天分组的提交时间线。
struct FileHistoryTimelineView: View {
    /// 同一天的提交组成一个分组。
    private struct DaySection: Identifiable {
        /// 这一天的开始时刻。
        let day: Date

        /// 这一天的提交，保持 Git 输出的顺序。
        var commits: [HistoryCommit]

        /// 日期即身份。
        var id: Date { day }
    }

    /// 当前仓库会话。
    let session: RepositorySession

    /// 时间线、筛选与选择。
    @Bindable
    var state: FileHistoryState

    /// 文件选择器是否打开。
    @State
    private var choosingFile = false

    /// 按提交人日期把相邻的提交分到同一天。
    private var sections: [DaySection] {
        let calendar = Calendar.current
        var sections: [DaySection] = []

        for commit in state.commits {
            let day = calendar.startOfDay(for: commit.commitDate)

            if sections.last?.day == day {
                sections[sections.count - 1].commits.append(commit)
            } else {
                sections.append(DaySection(day: day, commits: [commit]))
            }
        }

        return sections
    }

    /// 提交数的文案，读取完成前为空。
    private var countText: String {
        switch state.totalCount {
        case nil: ""
        case 1: AppLocalization.text("fileHistory.oneCommit")
        case let count?: AppLocalization.text("fileHistory.commits", count)
        }
    }

    /// 连接横幅、40 pt 头部、日期筛选、时间线与读取状态。
    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(session: session)

            header
            dateFilter
            Divider()

            timeline
                .frame(maxHeight: .infinity)

            if let failure = state.failure {
                FailureDetailsView(failure: failure) { state.reload() }
                    .padding(12)
            }

            if state.isLoading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(AppLocalization.text("history.loading"))
                }
                .font(.system(size: 11))
                .padding(8)
            }
        }
        .frame(minWidth: 100)
        .onChange(of: session.searchText) { state.search(session.searchText) }
    }

    /// 左侧文件按钮打开文件选择器，右侧是提交数。
    private var header: some View {
        HStack(spacing: 8) {
            Button {
                choosingFile = true
            } label: {
                Label(RepositorySession.fileName(state.path ?? ""), systemImage: "doc")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .buttonStyle(.accessoryBar)
            .help(state.path ?? "")
            .accessibilityLabel(AppLocalization.text("showFile.file"))
            .popover(isPresented: $choosingFile, arrowEdge: .bottom) {
                FileSelectorView(session: session, revision: nil) {
                    choosingFile = false
                    session.showFileHistory($0)
                }
            }

            Spacer(minLength: 4)

            Text(countText)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.bar)
    }

    /// 按提交人日期筛选：不限、之后、之前或区间。
    private var dateFilter: some View {
        HStack(spacing: 6) {
            Text(AppLocalization.text("fileHistory.date"))
                .foregroundStyle(.secondary)

            Picker("", selection: $state.dateRange) {
                Text(AppLocalization.text("fileHistory.anyDate")).tag(FileHistoryDateRange.any)
                Text(AppLocalization.text("fileHistory.after")).tag(FileHistoryDateRange.after)
                Text(AppLocalization.text("fileHistory.before")).tag(FileHistoryDateRange.before)
                Text(AppLocalization.text("fileHistory.between")).tag(FileHistoryDateRange.between)
            }
            .labelsHidden()
            .fixedSize()

            if state.dateRange != .any {
                DatePicker("", selection: $state.startDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
            }

            if state.dateRange == .between {
                Text(AppLocalization.text("fileHistory.to"))
                    .foregroundStyle(.secondary)

                DatePicker("", selection: $state.endDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
            }

            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .controlSize(.small)
        .padding(.horizontal, 12)
        .frame(height: 28)
    }

    /// 子模块与空结果显示说明，否则显示按天分组的时间线。
    @ViewBuilder
    private var timeline: some View {
        if state.isSubmodule {
            FileNoticeView(message: AppLocalization.text("fileHistory.submodule"))
        } else if state.commits.isEmpty, !state.isLoading, state.failure == nil {
            EmptyStateView(title: AppLocalization.text("history.empty"), message: "", symbol: "clock")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $state.selectedID) {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.commits) { commit in
                            FileHistoryCommitRow(commit: commit)
                                .tag(commit.id)
                                .onAppear { loadMoreIfLast(commit) }
                        }
                    } header: {
                        Text(section.day.formatted(date: .long, time: .omitted).uppercased())
                            .font(.system(size: 11))
                    }
                }
            }
            .contextMenu(forSelectionType: String.self) { ids in
                if let commit = state.commits.first(where: { ids.contains($0.id) }) {
                    menu(for: commit)
                }
            } primaryAction: { ids in
                // 双击与回车回到对应的提交
                if let commit = state.commits.first(where: { ids.contains($0.id) }) {
                    session.showCommit(commit)
                }
            }
            .accessibilityIdentifier("file-history-commits")
        }
    }

    /// 时间线的右键菜单：查看这个版本、回到提交、恢复与导出。
    @ViewBuilder
    private func menu(for commit: HistoryCommit) -> some View {
        let path = state.path ?? ""
        let name = RepositorySession.fileName(path)

        Button(AppLocalization.text("fileHistory.showAt", name, commit.shortID)) {
            session.showFile(path, at: commit.id, mode: .raw)
        }

        Button(AppLocalization.text("fileHistory.blameAt", name, commit.shortID)) {
            session.showFile(path, at: commit.id, mode: .blame)
        }

        Button(AppLocalization.text("fileHistory.showCommitFor", commit.shortID)) {
            session.showCommit(commit)
        }

        Divider()

        Button(AppLocalization.text("fileHistory.restoreAt", name, commit.shortID)) {
            session.restoreFile(path, at: commit.id)
        }
        .disabled(!session.canWrite)

        Button(AppLocalization.text("fileHistory.exportAt", name, commit.shortID)) {
            session.exportFile(path, at: commit.id)
        }
    }

    /// 列表显示到最后一条时续载下一页。
    private func loadMoreIfLast(_ commit: HistoryCommit) {
        if commit.id == state.commits.last?.id, state.hasMore {
            state.loadNextPage()
        }
    }
}

// MARK: - FileHistoryCommitRow

/// 时间线中的一个提交：左侧时间线节点，第一行标题，第二行短哈希、作者与时间。
private struct FileHistoryCommitRow: View {
    /// 这一行的提交。
    let commit: HistoryCommit

    /// 39 pt 高的两行布局。
    var body: some View {
        HStack(spacing: 8) {
            TimelineMark()
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(commit.subject)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    Text(commit.shortID)
                        .font(.system(size: 11, design: .monospaced))

                    Text(commit.author)
                        .font(.system(size: 11))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(commit.commitDate, format: .dateTime.hour().minute())
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(height: 39)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - TimelineMark

/// 时间线的竖线与节点：贯穿整行的细线，中间一个空心圆点。
private struct TimelineMark: View {
    /// 竖线在下，节点盖在中间。
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.tertiary)
                .frame(width: 2)

            Circle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(Circle().strokeBorder(.secondary, lineWidth: 1.5))
                .frame(width: 9, height: 9)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - FileHistoryDetailView

/// 文件历史的右栏：所选提交的短哈希、悬停出现的动作条与 Diff / Raw 切换，下面是补丁或原文。
struct FileHistoryDetailView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 所选提交的详情状态。
    @Bindable
    var state: FileHistoryState

    /// 鼠标是否在头部上，决定动作条是否显示。
    @State
    private var hovering = false

    /// 内置主题随系统外观切换。
    @Environment(\.colorScheme)
    private var colorScheme

    /// 没有选中提交时显示空状态。
    var body: some View {
        if let commit = state.selectedCommit {
            VStack(spacing: 0) {
                header(commit)
                Divider()

                content(commit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            EmptyStateView(title: AppLocalization.text("history.noSelection"), message: "", symbol: "doc.text")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 动作条：查看这个版本的 Blame、回到对应的提交。
    private func actions(_ commit: HistoryCommit) -> [FileViewAction] {
        let path = state.path ?? ""

        return [
            FileViewAction(title: AppLocalization.text("blame.title")) {
                session.showFile(path, at: commit.id, mode: .blame)
            },
            FileViewAction(title: AppLocalization.text("fileHistory.showCommit")) {
                session.showCommit(commit)
            },
        ]
    }

    /// 40 pt 头部：可选中的短哈希、动作条与 Diff / Raw 分段控件。
    private func header(_ commit: HistoryCommit) -> some View {
        HStack(spacing: 8) {
            Text(commit.shortID)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Spacer(minLength: 8)

            FileActionBar(actions: actions(commit), hovering: hovering)

            Picker("", selection: $state.detailMode) {
                Text(AppLocalization.text("fileHistory.diff")).tag(FileHistoryDetailMode.diff)
                Text(AppLocalization.text("showFile.raw")).tag(FileHistoryDetailMode.raw)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 112)
        }
        .padding(.horizontal, 20)
        .frame(height: 40)
        .background(.bar)
        .modifier(FileActionHeader(actions: actions(commit), hovering: $hovering))
    }

    /// 补丁、原文、不能显示的说明或读取状态。
    @ViewBuilder
    private func content(_ commit: HistoryCommit) -> some View {
        if let failure = state.detailFailure {
            FailureDetailsView(failure: failure) { state.loadDetail() }
                .padding(20)
        } else if state.detailMode == .diff, let diff = state.diff, let source = state.detailSource {
            ScrollView {
                ReadOnlyFileDiffView(result: diff, source: source) { state.loadDetail(showLarge: true) }
            }
            .background(TextTheme.current(dark: colorScheme == .dark).colors["background"]?.color ?? .clear)
            .reloadsOnDiffPreferenceChange { state.loadDetail() }
        } else if state.detailMode == .raw, let content = state.content {
            raw(content, commit: commit)
        } else {
            let key = state.detailMode == .diff ? "working.loadingDiff" : "showFile.loading"

            ProgressView(AppLocalization.text(key))
                .controlSize(.small)
        }
    }

    /// 这个版本的原文；版本中没有这个文件或不能以文本显示时给出说明。
    @ViewBuilder
    private func raw(_ content: FileRevisionContent, commit: HistoryCommit) -> some View {
        switch content.unavailable {
        case .missing:
            FileNoticeView(message: AppLocalization.text("showFile.untracked"))

        case .binary:
            FileNoticeView(message: AppLocalization.text("showFile.binary"))

        case .submodule:
            FileNoticeView(message: AppLocalization.text("showFile.submodule"))

        case nil:
            FileTextView(
                contentID: content.path + "@" + commit.id,
                path: content.path,
                lines: content.lines,
                theme: TextTheme.current(dark: colorScheme == .dark),
                menuActions: [
                    FileViewAction(title: AppLocalization.text("showFile.copy")) {
                        session.copyFile(content.path, at: commit.id)
                    },
                    FileViewAction(title: AppLocalization.text("showFile.export")) {
                        session.exportFile(content.path, at: commit.id)
                    },
                    FileViewAction(title: AppLocalization.text("showFile.open")) {
                        session.openFile(content.path, at: commit.id)
                    },
                ]
            )
        }
    }
}
