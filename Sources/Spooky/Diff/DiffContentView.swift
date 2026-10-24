import SpookyKit
import SwiftUI

// MARK: - DiffContentView

/// 工作区的单列表 Diff：吸顶块头、可换行正文，底栏放忽略空白、显示整个文件、增删统计与上下文行数。
struct DiffContentView: View {
    /// 写操作使用所属会话。
    let session: RepositorySession

    /// 当前可写快照。
    let snapshot: DiffSnapshot

    /// 已解析的文件段。
    let diff: RepositoryDiff

    /// 内置主题随系统外观切换。
    @Environment(\.colorScheme)
    private var colorScheme

    /// 一个制表符占的空格数。
    @AppStorage(TextPreferences.tabWidthKey)
    private var tabWidth = TextPreferences.defaultTabWidth

    /// 标出不可见字符。
    @AppStorage(TextPreferences.showsInvisiblesKey)
    private var showsInvisibles = false

    /// 语法着色总开关。
    @AppStorage(TextPreferences.syntaxColoringKey)
    private var colorsSyntax = true

    /// Diff 中的语法着色。
    @AppStorage(TextPreferences.diffSyntaxColoringKey)
    private var colorsDiffSyntax = false

    /// 两侧全文的语法片段，读完之前与识别不了语言时按纯文本显示。
    @State
    private var syntax: DiffSyntax?

    /// 各块的行内高亮，按块元素的身份存放；算完之前不高亮。
    @State
    private var highlights: [[Int]: [Int: [Range<Int>]]] = [:]

    /// 文本区与摘要共享同一组块数据。
    var body: some View {
        let style = TextStyle(
            theme: TextTheme.current(dark: colorScheme == .dark),
            tabWidth: tabWidth,
            showsInvisibles: showsInvisibles
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if snapshot.onlyWhitespaceChanges {
                    DiffNotice(key: "diff.onlyWhitespace", style: style)
                }

                ForEach(DiffSegment.all(in: diff)) { segment in
                    segmentView(segment, style: style)
                }
            }
            .coordinateSpace(name: DiffHunkView.coordinateSpace)
        }
        .background(style.color("background"))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DiffBottomBar(session: session, diff: diff)
        }
        .task(id: [colorsSyntax, colorsDiffSyntax]) {
            let colored = await session.diffSyntax(for: snapshot, diff: diff)

            // 着色期间切换了开关时任务已取消，结果作废，不覆盖新任务写入的片段
            guard !Task.isCancelled else {
                return
            }

            syntax = colored
        }
        .task(id: diff) {
            // 补丁重新读取后先清掉旧的范围，避免套到新的行上
            highlights = [:]

            let ranges = await DiffSegment.highlights(in: diff)

            guard !Task.isCancelled else {
                return
            }

            highlights = ranges
        }
    }

    /// 一个元素：文件段的开头，或可以按块、按行写入的块。
    @ViewBuilder
    private func segmentView(_ segment: DiffSegment, style: TextStyle) -> some View {
        switch segment {
        case .file(let file):
            fileHeader(file, style: style)

        case .hunk(let file, let hunk):
            DiffHunkView(
                hunk: hunk,
                style: style,
                spans: { syntax?.spans(for: $0) },
                highlights: highlights[segment.id] ?? [:],
                staged: snapshot.side == .staged,
                enabled: session.canWrite && !session.isLoadingDiff && diff.files.count == 1
            ) { lines, discard in
                session.apply(file: file.id, hunk: hunk.id, lines: lines, discard: discard)
            }
        }
    }

    /// 文件段的开头：Git 扩展头，以及二进制或无文本改动的提示。
    private func fileHeader(_ file: DiffFile, style: TextStyle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DiffFileHeader(file: file, style: style)

            if file.isBinary {
                Text(AppLocalization.text("working.binary"))
                    .padding(20)
            } else if file.hunks.isEmpty {
                Text(AppLocalization.text("working.noDiff"))
                    .padding(20)
            }
        }
    }
}

// MARK: - DiffSegment

/// 懒加载栈里的一个元素：文件段的开头，或文件段里的一个块。
///
/// 文件头与各块要作为同一层的元素放进懒加载栈；一个元素展开成多个视图时，第一个块的块头不会显示。
enum DiffSegment: Identifiable {
    /// 文件段的开头。
    case file(DiffFile)

    /// 文件段里的一个块。
    case hunk(DiffFile, DiffHunk)

    /// 文件段序号，块再加上块序号。
    var id: [Int] {
        switch self {
        case .file(let file): [file.id]
        case .hunk(let file, let hunk): [file.id, hunk.id]
        }
    }

    /// 按补丁顺序排出的全部元素。
    static func all(in diff: RepositoryDiff) -> [Self] {
        diff.files.flatMap { file in
            [.file(file)] + file.hunks.map { .hunk(file, $0) }
        }
    }

    /// 补丁里各块的行内高亮，按块元素的身份存放，块内的键是行序号。
    ///
    /// 显示整个文件的大补丁也要逐对比较，放到后台完成；每份补丁只算一次，排版时只取结果。
    static func highlights(in diff: RepositoryDiff) async -> [[Int]: [Int: [Range<Int>]]] {
        await Task.detached(priority: .userInitiated) {
            var result: [[Int]: [Int: [Range<Int>]]] = [:]

            for file in diff.files {
                for hunk in file.hunks {
                    result[[file.id, hunk.id]] = InlineDiff.ranges(in: hunk)
                }
            }

            return result
        }.value
    }
}

// MARK: - DiffFileHeader

/// 文件段开头的 Git 扩展头，显示重命名、复制与模式变化，可选中复制。
struct DiffFileHeader: View {
    /// 文件段。
    let file: DiffFile

    /// 主题字体。
    let style: TextStyle

    /// 等宽字体的次要色原文。
    var body: some View {
        Text(file.headers.joined(separator: "\n"))
            .font(style.font)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
    }
}

// MARK: - DiffNotice

/// Diff 区里与文件头同样式的一行说明，如只剩空白改动。
struct DiffNotice: View {
    /// 说明的资源键。
    let key: String

    /// 主题字体。
    let style: TextStyle

    /// 高 32 pt、左侧与文件头对齐。
    var body: some View {
        Text(AppLocalization.text(key))
            .font(style.font)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
    }
}

// MARK: - DiffBottomBar

/// Diff 底栏：左侧两个开关，中间是块数与增删行数，右侧是上下文行数。
private struct DiffBottomBar: View {
    /// 显示整个文件属于当前会话的视图状态。
    @Bindable
    var session: RepositorySession

    /// 统计来源。
    let diff: RepositoryDiff

    /// 全局的忽略空白偏好。
    @AppStorage(DiffPreferences.ignoresWhitespaceKey)
    private var ignoresWhitespace = false

    /// 全局的上下文行数偏好。
    @AppStorage(DiffPreferences.contextLinesKey)
    private var contextLines = DiffOptions.defaultContextLines

    /// 32 pt 高的材质底栏。
    var body: some View {
        HStack(spacing: 4) {
            toggle("diff.ignoreWhitespace", symbol: "space", isOn: $ignoresWhitespace)

            toggle(
                "diff.showEntireFile",
                symbol: "arrow.up.and.down.text.horizontal",
                isOn: Binding(
                    get: { session.diffShowsEntireFile },
                    set: {
                        session.diffShowsEntireFile = $0
                        session.loadDiff()
                    }
                )
            )

            Spacer(minLength: 8)

            if session.isLoadingDiff {
                ProgressView().controlSize(.mini)
            }

            Text(summary)

            Spacer(minLength: 8)

            Text(AppLocalization.text("diff.context"))

            Picker(AppLocalization.text("diff.context"), selection: $contextLines) {
                ForEach(DiffOptions.contextChoices, id: \.self) {
                    Text(DiffPreferences.contextTitle($0)).tag($0)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
            .disabled(session.diffShowsEntireFile)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .frame(height: 32)
        .background(.bar)
    }

    /// 块数、新增行数与删除行数。
    private var summary: String {
        let hunks = diff.files.flatMap(\.hunks)
        let lines = hunks.flatMap(\.lines)

        return AppLocalization.text(
            "working.diffSummary",
            hunks.count,
            lines.filter { $0.prefix == 43 }.count,
            lines.filter { $0.prefix == 45 }.count
        )
    }

    /// 30 pt 宽的图标开关，打开时图标使用强调色。
    private func toggle(_ key: String, symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Image(systemName: symbol)
                .foregroundStyle(isOn.wrappedValue ? Color.accentColor : .secondary)
        }
        .toggleStyle(.button)
        .buttonStyle(.borderless)
        .frame(width: 30)
        .help(AppLocalization.text(key))
        .accessibilityLabel(AppLocalization.text(key))
    }
}
