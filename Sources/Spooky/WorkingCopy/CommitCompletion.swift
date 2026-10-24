import AppKit
import SpookyKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - CompletionTrigger

/// 光标处正在输入的补全：`c:` 引用提交，`\` 引用改动文件，标题以 `fixup!` / `squash!` 开头时选择目标提交。
enum CompletionTrigger: Equatable {
    /// `c:` 之后的查询，选中后替换为短哈希。
    case commit(query: String, range: NSRange)

    /// `\` 之后的查询，选中后替换为文件路径。
    case file(query: String, range: NSRange)

    /// 前缀之后的查询，选中后把标题余下部分替换为目标提交的标题。
    case fixup(query: String, range: NSRange)

    /// 选中后被替换的文字范围，以 UTF-16 计。
    var range: NSRange {
        switch self {
        case .commit(_, let range), .file(_, let range), .fixup(_, let range): range
        }
    }

    /// 查找光标处的补全。
    ///
    /// - Parameters:
    ///   - text: 标题或正文的全文。
    ///   - caret: 光标的 UTF-16 位置。
    ///   - subject: 是否为标题；只有标题识别 fixup / squash 前缀。
    static func detect(in text: String, caret: Int, subject: Bool) -> Self? {
        guard (0 ... text.utf16.count).contains(caret) else { return nil }

        let end = String.Index(utf16Offset: caret, in: text)

        // 标题的前缀补全替换前缀之后的整行。
        if subject, let prefix = ["fixup! ", "squash! "].first(where: text.hasPrefix) {
            let start = text.index(text.startIndex, offsetBy: prefix.count)

            if end >= start {
                return .fixup(query: String(text[start ..< end]), range: NSRange(start ..< text.endIndex, in: text))
            }
        }

        // 其余补全只看光标前、空白之后的这个词。
        let start = text[..<end].lastIndex(where: \.isWhitespace).map { text.index(after: $0) } ?? text.startIndex
        let token = text[start ..< end]
        let range = NSRange(start ..< end, in: text)

        if token.hasPrefix("c:") {
            return .commit(query: String(token.dropFirst(2)), range: range)
        }

        if token.hasPrefix("\\") {
            return .file(query: String(token.dropFirst()), range: range)
        }

        return nil
    }
}

// MARK: - CommitCompletion

/// 一条补全建议与选中后插入的文字。
struct CommitCompletion: Identifiable, Equatable {
    /// 建议的内容。
    enum Content: Equatable {
        /// 最近的提交。
        case commit(HistoryCommit)

        /// 工作区里有改动的文件。
        case file(String)
    }

    /// 列表内的稳定标识。
    let id: String

    /// 显示内容。
    let content: Content

    /// 选中后插入的文字，已规范为 NFC。
    let insertion: String

    /// 按触发方式筛选候选：提交按哈希前缀或标题、作者匹配，文件按路径匹配，查询都不区分大小写。
    ///
    /// - Parameters:
    ///   - trigger: 当前的补全。
    ///   - commits: 最近的提交，按历史顺序排列。
    ///   - paths: 改动文件的路径。
    static func matches(for trigger: CompletionTrigger, commits: [HistoryCommit], paths: [String]) -> [Self] {
        switch trigger {
        case .commit(let query, _), .fixup(let query, _):
            let fixup = if case .fixup = trigger { true } else { false }
            return commits
                .filter {
                    query.isEmpty || $0.id.hasPrefix(query.lowercased())
                        || $0.subject.localizedCaseInsensitiveContains(query)
                        || $0.author.localizedCaseInsensitiveContains(query)
                }
                .map {
                    Self(
                        id: $0.id,
                        content: .commit($0),
                        insertion: (fixup ? $0.subject : $0.shortID).precomposedStringWithCanonicalMapping
                    )
                }

        case .file(let query, _):
            return paths
                .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
                .map { Self(id: $0, content: .file($0), insertion: $0.precomposedStringWithCanonicalMapping) }
        }
    }
}

// MARK: - CommitCompletionPanel

/// 补全弹窗：挂在文本视图窗口上的无边框子窗口，位于光标下方，不抢键盘焦点。
@MainActor
final class CommitCompletionPanel {
    /// 弹窗的显示模型。
    @Observable
    final class Model {
        /// 当前候选。
        var items: [CommitCompletion] = []

        /// 选中的候选位置。
        var selection = 0

        /// 点击候选时接受。
        var onAccept: (CommitCompletion) -> Void = { _ in }
    }

    /// 弹窗默认宽度。
    private static let width = 450.0

    /// 弹窗最大高度，超出时滚动。
    private static let maximumHeight = 600.0

    /// 列表最多保留的候选数。
    private static let limit = 100

    /// 候选与选中位置。
    private let model = Model()

    /// 按需创建的子窗口。
    private var panel: NSPanel? = nil

    /// 弹窗是否正在显示。
    var isVisible: Bool { panel?.isVisible ?? false }

    /// 显示或更新候选；没有候选时关闭。
    ///
    /// - Parameters:
    ///   - items: 已筛选的候选。
    ///   - textView: 正在编辑的文本视图。
    ///   - anchor: 补全开始位置，弹窗左缘与它对齐。
    ///   - accept: 选中候选的处理。
    func show(
        _ items: [CommitCompletion],
        for textView: NSTextView,
        at anchor: Int,
        accept: @escaping (CommitCompletion) -> Void
    ) {
        guard !items.isEmpty, let window = textView.window else {
            close()
            return
        }

        if model.items.map(\.id) != items.prefix(Self.limit).map(\.id) { model.selection = 0 }
        model.items = Array(items.prefix(Self.limit))
        model.onAccept = accept

        let panel = panel ?? makePanel()
        self.panel = panel
        panel.setFrame(frame(for: textView, at: anchor), display: true)

        if panel.parent == nil {
            window.addChildWindow(panel, ordered: .above)
        }

        panel.orderFront(nil)
    }

    /// 关闭弹窗并清空候选。
    func close() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        model.items = []
    }

    /// 弹窗显示时处理文本视图的按键：↑↓ 移动、↩ 接受、Esc 关闭、删除后重新筛选，其它命令先关闭弹窗再照常执行。
    ///
    /// - Returns: 按键是否已由弹窗处理。
    func handle(_ selector: Selector) -> Bool {
        guard isVisible, !model.items.isEmpty else { return false }

        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            model.selection = max(0, model.selection - 1)
            return true

        case #selector(NSResponder.moveDown(_:)):
            model.selection = min(model.items.count - 1, model.selection + 1)
            return true

        case #selector(NSResponder.insertNewline(_:)):
            model.onAccept(model.items[model.selection])
            return true

        case #selector(NSResponder.cancelOperation(_:)):
            close()
            return true

        // 删除字符时保留弹窗，内容变化后按新的查询重新筛选。
        case #selector(NSResponder.deleteBackward(_:)), #selector(NSResponder.deleteWordBackward(_:)):
            return false

        default:
            close()
            return false
        }
    }
}

// MARK: - Private

extension CommitCompletionPanel {
    /// 无边框、不激活的子窗口，内容是菜单材质的圆角背景与候选列表。
    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true

        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true

        let content = CompletionHostingView(rootView: CommitCompletionList(model: model))
        content.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            content.topAnchor.constraint(equalTo: background.topAnchor),
            content.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])

        panel.contentView = background
        return panel
    }

    /// 弹窗放在补全起点的下方；下方空间不够时放到上方。
    private func frame(for textView: NSTextView, at anchor: Int) -> NSRect {
        let caret = textView.firstRect(forCharacterRange: NSRange(location: anchor, length: 0), actualRange: nil)
        let height = min(
            model.items.reduce(12.0) { $0 + CommitCompletionList.rowHeight(for: $1) },
            Self.maximumHeight
        )
        let below = NSRect(x: caret.minX - 8, y: caret.minY - height - 4, width: Self.width, height: height)
        let visible = textView.window?.screen?.visibleFrame ?? .infinite

        guard below.minY < visible.minY else {
            return below
        }

        return NSRect(x: below.minX, y: caret.maxY + 4, width: Self.width, height: height)
    }
}

// MARK: - CompletionHostingView

/// 弹窗不成为主窗口，第一次点击也要直接选中候选。
private final class CompletionHostingView: NSHostingView<CommitCompletionList> {
    /// 接受不激活窗口的首次点击。
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
}

// MARK: - CommitCompletionList

/// 候选列表：提交行显示首字母头像、作者、日期、短哈希与标题，文件行显示图标与路径。
private struct CommitCompletionList: View {
    /// 弹窗模型。
    let model: CommitCompletionPanel.Model

    /// 选中行跟随键盘滚动到可见位置。
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        row(item, selected: index == model.selection)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture { model.onAccept(item) }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selection) {
                guard model.items.indices.contains(model.selection) else { return }
                proxy.scrollTo(model.items[model.selection].id)
            }
        }
    }

    /// 提交行 44 pt，文件行 24 pt。
    static func rowHeight(for item: CommitCompletion) -> CGFloat {
        if case .commit = item.content { 44 } else { 24 }
    }
}

// MARK: - Private

extension CommitCompletionList {
    /// 路径扩展名对应的文件类型，识别不了时按普通数据显示。
    private static func type(of path: String) -> UTType {
        let name = path.split(separator: "/").last ?? ""
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count > 1 else {
            return .data
        }

        return UTType(filenameExtension: String(parts[parts.count - 1])) ?? .data
    }

    /// 选中行使用强调色底与白字。
    private func row(_ item: CommitCompletion, selected: Bool) -> some View {
        Group {
            switch item.content {
            case .commit(let commit): commitRow(commit)
            case .file(let path): fileRow(path)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(selected ? Color.white : Color.primary)
        .padding(.horizontal, 3)
        .frame(height: Self.rowHeight(for: item))
        .background(selected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5))
    }

    /// 32 pt 作者头像；上行作者与日期，下行等宽短哈希与截断的标题。
    private func commitRow(_ commit: HistoryCommit) -> some View {
        HStack(spacing: 8) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(commit.author).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(commit.commitDate, format: .dateTime.year().month().day())
                }

                HStack(spacing: 4) {
                    Text(commit.shortID).font(.system(size: 12, design: .monospaced))
                    Text(commit.subject).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// 按扩展名取系统文件图标，不访问文件本身。
    private func fileRow(_ path: String) -> some View {
        HStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(for: Self.type(of: path)))
                .resizable()
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            Text(path).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}
