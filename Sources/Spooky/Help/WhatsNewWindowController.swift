import AppKit
import SwiftUI

// MARK: - WhatsNewWindowController

/// Help › What's New：左边按版本从新到旧列出历次的更新说明，右边显示选中的一篇。
///
/// 说明随发布打包进 App 的 `ReleaseNotes` 资源目录，每个版本一个子目录；没有任何说明的构建里菜单项不可用。
@MainActor
final class WhatsNewWindowController: NSWindowController {
    /// 显示说明的窗口，同一时间只有一个。
    private static var shown: WhatsNewWindowController?

    /// 800 × 552 的窗口：上面 52 pt 是工具栏，侧边栏占满窗口高度。
    ///
    /// - Parameter state: 窗口列出的条目与选中的版本。
    private init(state: WhatsNewState) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 552),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.title = AppLocalization.text("help.whatsNew")

        // 先装一个空的工具栏，SwiftUI 才会把隐藏侧边栏按钮与上一篇、下一篇放进去
        window.toolbar = NSToolbar(identifier: "Spooky.WhatsNew")
        window.toolbarStyle = .unified

        window.contentViewController = NSHostingController(rootView: WhatsNewView(state: state))

        // 装入内容会把窗口缩到 SwiftUI 的理想尺寸，先回到初始尺寸再居中
        window.setContentSize(NSSize(width: 800, height: 552))
        window.center()

        super.init(window: window)
    }

    /// 窗口只由代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    /// 显示 What's New；已经在显示时带到前面。
    ///
    /// 窗口原来没在显示时选中第一行；指定了版本时选中那一条。
    ///
    /// - Parameter version: 要选中的版本，nil 表示按上面的规则。
    static func show(selecting version: String? = nil) {
        let state = WhatsNewState.shared

        guard !state.entries.isEmpty else {
            return
        }

        let controller = shown ?? WhatsNewWindowController(state: state)
        shown = controller

        // 指定了版本时选中它；窗口重新打开时回到第一行，已经在显示时保持原来的选中行
        if let version {
            state.selection = version
        } else if controller.window?.isVisible != true {
            state.selection = state.entries.first?.version
        }

        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - WhatsNewView

/// What's New 的内容：侧边栏是版本列表，详情是选中的说明；工具栏的上一篇、下一篇在列表里上下移动选中行。
struct WhatsNewView: View {
    /// 条目、已读记录与选中的版本。
    @Bindable
    var state: WhatsNewState

    /// 320 pt 宽的列表与详情。
    var body: some View {
        NavigationSplitView {
            // 列表不接收键盘焦点，选中行始终是灰色的高亮；切换由点按与工具栏的上一篇、下一篇完成
            List(state.entries, selection: $state.selection) { entry in
                WhatsNewRow(
                    entry: entry,
                    isCurrent: entry.version == state.currentVersion,
                    isUnread: state.isUnread(entry)
                )
                .listRowInsets(EdgeInsets())
            }
            .listStyle(.sidebar)
            .focusable(false)
            .navigationSplitViewColumnWidth(320)
        } detail: {
            detail
                .toolbar {
                    ToolbarItemGroup(placement: .navigation) {
                        navigationButtons
                    }
                }
        }
        .navigationTitle(AppLocalization.text("help.whatsNew"))
    }

    /// 选中条目的说明；没有选中时居中提示。
    @ViewBuilder
    private var detail: some View {
        if let entry = state.entries.first(where: { $0.version == state.selection }) {
            ReleaseNotesView(entry: entry)
        } else {
            Text(AppLocalization.text("whatsNew.empty"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 上一篇与下一篇：选中第一行时上一篇禁用，选中最后一行时下一篇禁用。
    @ViewBuilder
    private var navigationButtons: some View {
        let index = state.entries.firstIndex { $0.version == state.selection }

        Button {
            index.map { state.selection = state.entries[$0 - 1].version }
        } label: {
            Label(AppLocalization.text("whatsNew.previous"), systemImage: "chevron.left")
        }
        .help(AppLocalization.text("whatsNew.previous.tip"))
        .disabled((index ?? 0) == 0)

        Button {
            index.map { state.selection = state.entries[$0 + 1].version }
        } label: {
            Label(AppLocalization.text("whatsNew.next"), systemImage: "chevron.right")
        }
        .help(AppLocalization.text("whatsNew.next.tip"))
        .disabled(index.map { $0 >= state.entries.count - 1 } ?? true)
    }
}

// MARK: - WhatsNewRow

/// 版本列表的一行：说明图标，标题与版本号胶囊，副标题，没读过时右端的蓝点。
struct WhatsNewRow: View {
    /// 这一行的版本。
    let entry: WhatsNewEntry

    /// 是 App 当前的版本：标题加粗，胶囊用绿色。
    let isCurrent: Bool

    /// 还没读过：右端显示蓝点。
    let isUnread: Bool

    /// 48 pt 高：图标的墨迹从侧边栏左边 24 pt 起，两行文字从 50 pt 起，一起垂直居中。
    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "doc.text")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                titleLine

                Text(AppLocalization.text("whatsNew.entry.subtitle"))
                    .font(.system(size: 10))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
            }
            .padding(.leading, 2)
        }
        .frame(height: 48)
        .accessibilityElement(children: .combine)
    }

    /// 标题、版本号胶囊与蓝点：胶囊在标题后 8 pt，蓝点与胶囊至少隔 12 pt、右边距侧边栏右边 22 pt；放不下时标题截尾，胶囊与蓝点保持完整。
    private var titleLine: some View {
        HStack(spacing: 0) {
            Text(AppLocalization.text("whatsNew.entry.title", entry.version))
                .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                .lineLimit(1)
                .layoutPriority(1)

            versionBadge
                .fixedSize()
                .padding(.leading, 8)

            Spacer(minLength: 12)

            if isUnread {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .padding(.trailing, 6)
                    .accessibilityLabel(AppLocalization.text("whatsNew.unread"))
            }
        }
    }

    /// 版本号胶囊：当前版本用绿色，其余用浅灰底与主文字色。
    @ViewBuilder
    private var versionBadge: some View {
        let label = Text(verbatim: entry.version)
            .font(.system(size: 10))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)

        if isCurrent {
            label
                .foregroundStyle(AppPalette.color("green_badge_text_color"))
                .background(AppPalette.color("green_badge_background_color"), in: Capsule())
        } else {
            label
                .foregroundStyle(.primary)
                .background(.fill, in: Capsule())
        }
    }
}

// MARK: - ReleaseNotesView

/// 一个版本的更新说明：顶部是带版本号的标题，正文渲染 `###` 节标题、无序列表与段落，行内的粗体与链接照 Markdown 显示。
struct ReleaseNotesView: View {
    /// 说明里的一块内容。
    enum Block: Equatable {
        /// `###` 节标题。
        case heading(String)

        /// 列表的一项。
        case item(String)

        /// 一段文字。
        case paragraph(String)
    }

    /// 显示的版本与说明。
    let entry: WhatsNewEntry

    /// 可滚动、可选择文字的说明，左右留 32 pt、上下留 24 pt。
    var body: some View {
        let blocks = Self.blocks(of: entry.notes)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(AppLocalization.text("whatsNew.detail.title", entry.version))
                    .font(.system(size: 22, weight: .bold))

                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    let previous = index == 0 ? nil : blocks[index - 1]

                    view(for: block)
                        .padding(.top, Self.spacing(before: block, after: previous))
                }
            }
            .textSelection(.enabled)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 按行拆成节标题、列表项与段落；空行只分隔，不单独成块。
    static func blocks(of markdown: String) -> [Block] {
        markdown.split(whereSeparator: \.isNewline).compactMap { line in
            let text = line.trimmingCharacters(in: .whitespaces)

            if text.hasPrefix("### ") {
                return .heading(String(text.dropFirst(4)))
            }

            if text.hasPrefix("- ") || text.hasPrefix("* ") {
                return .item(String(text.dropFirst(2)))
            }

            return text.isEmpty ? nil : .paragraph(text)
        }
    }

    /// 一块内容与上面的距离：节标题之前 24 pt，列表项之间 8 pt，其余（包括顶部标题之后与节标题之后）16 pt。
    ///
    /// - Parameters:
    ///   - block: 这一块。
    ///   - previous: 上一块；nil 表示紧接着顶部标题。
    static func spacing(before block: Block, after previous: Block?) -> CGFloat {
        switch (previous, block) {
        case (.some, .heading):
            24

        case (.item, .item):
            8

        default:
            16
        }
    }

    /// 一块内容的视图：节标题 15 pt 粗体，正文 13 pt、行距 3.5 pt；列表的圆点缩进 8 pt，文字从 22 pt 起，换行后与文字对齐。
    @ViewBuilder
    private func view(for block: Block) -> some View {
        switch block {
        case .heading(let text):
            Text(inline(text))
                .font(.system(size: 15, weight: .bold))

        case .item(let text):
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(verbatim: "•")
                    .frame(width: 14, alignment: .leading)
                    .accessibilityHidden(true)

                Text(inline(text))
            }
            .font(.system(size: 13))
            .lineSpacing(3.5)
            .padding(.leading, 8)

        case .paragraph(let text):
            Text(inline(text))
                .font(.system(size: 13))
                .lineSpacing(3.5)
        }
    }

    /// 行内的粗体与链接；解析不了时显示原文。
    private func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
