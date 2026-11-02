import AppKit

// MARK: - PullRequestMarkdown

/// 评论与描述的正文：按完整的 Markdown 语法解析，转成文字区显示的带格式文字。
///
/// 正文 13 pt、段后 12，列表里的段落段后 0；软换行与硬换行都换行，换行前的一行没有段后间距。
/// 代码块与引用块是 `NSTextBlock`，表格是 `NSTextTable`，列表每层缩进 8；HTML 与分隔线不显示。
/// 代码块、表格之后，以及最外层的列表结束时空一行；正文末尾不留空行。
enum PullRequestMarkdown {
    /// 转换结果按正文缓存：列宽变化时只重新排版，不重新解析。
    ///
    /// `NSCache` 的键只能是对象，正文按 Objective-C 字符串作键。
    @MainActor
    // swiftlint:disable:next legacy_objc_type
    private static let cache = NSCache<NSString, NSAttributedString>()

    /// 正文转成带格式的文字；同一段正文只转换一次。
    @MainActor
    static func attributedString(_ text: String) -> NSAttributedString {
        // swiftlint:disable:next legacy_objc_type
        let key = text as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let string = convert(text)
        cache.setObject(string, forKey: key)
        return string
    }

    /// 解析并转换；解析失败时按纯文字显示。
    static func convert(_ text: String) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        guard let parsed = try? AttributedString(markdown: text, options: options) else {
            return NSAttributedString(
                string: text,
                attributes: [.font: Style.body, .foregroundColor: NSColor.labelColor]
            )
        }

        var builder = Builder()

        for block in blocks(of: parsed) {
            builder.append(block)
        }

        return builder.finish()
    }

    /// 文字在给定宽度下排版后的高度，向上取整；行片段边距为 0，与文字区相同。
    static func height(of string: NSAttributedString, width: CGFloat) -> CGFloat {
        let storage = NSTextStorage(attributedString: string)
        let layoutManager = NSLayoutManager()

        let container = NSTextContainer(size: NSSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0

        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        return ceil(layoutManager.usedRect(for: container).height)
    }
}

// MARK: - Nested Types

extension PullRequestMarkdown {
    /// 一个叶子块：同一个块结构下相邻的几段文字。
    fileprivate struct Block {
        /// 块结构，组件从内到外；没有时按段落处理。
        let intent: PresentationIntent?

        /// 块里的文字，按行内格式分段。
        var spans: [Span]
    }

    /// 块里行内格式相同的一段文字。
    fileprivate struct Span {
        /// 原文。
        let text: String

        /// 行内格式。
        let inline: InlinePresentationIntent

        /// 链接的地址；图片是图片的地址。
        let link: URL?
    }

    /// 一个块的字体、文字颜色与段后间距。
    fileprivate struct Format {
        /// 块的字体，行内格式在它上面加粗或加斜。
        let font: NSFont

        /// 文字颜色。
        let color: NSColor

        /// 块的最后一行的段后间距。
        let spacing: CGFloat
    }

    /// 字体、间距与框的规格。
    fileprivate enum Style {
        /// 正文：系统字体 13 pt。
        static var body: NSFont { .systemFont(ofSize: 13) }

        /// 行内代码与代码块：用户的等宽字体 12 pt。
        static var code: NSFont {
            NSFont.userFixedPitchFont(ofSize: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
        }

        /// 段落与标题的段后间距。
        static let paragraphSpacing: CGFloat = 12

        /// 列表每一层的缩进，首行与续行相同。
        static let listIndentation: CGFloat = 8

        /// 标题：H1–H3 是 24 / 18 / 14 pt 常规字，H4–H6 是 13 pt 粗体。
        static func header(level: Int) -> NSFont {
            let size: CGFloat =
                switch level {
                case 1: 24
                case 2: 18
                case 3: 14
                default: 13
                }

            let font = NSFont.userFont(ofSize: size) ?? .systemFont(ofSize: size)
            return level <= 3 ? font : adding(.bold, to: font)
        }

        /// 在字体原有的特征上加上粗体或斜体；字体没有对应的字形时保持原样。
        static func adding(_ traits: NSFontDescriptor.SymbolicTraits, to font: NSFont) -> NSFont {
            guard !traits.isEmpty else {
                return font
            }

            let combined = font.fontDescriptor.symbolicTraits.union(traits)
            let descriptor = font.fontDescriptor.withSymbolicTraits(combined)

            return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
        }
    }
}

// MARK: - Private

extension PullRequestMarkdown {
    /// 按块结构把相邻的文字分成块；HTML 块整块去掉。
    private static func blocks(of parsed: AttributedString) -> [Block] {
        var blocks: [Block] = []

        for run in parsed.runs {
            let inline = run.inlinePresentationIntent ?? []

            // HTML 块没有块结构，整段不显示
            if inline.contains(.blockHTML) {
                continue
            }

            let span = Span(
                text: String(parsed[run.range].characters),
                inline: inline,
                link: run.imageURL ?? run.link
            )

            if let last = blocks.indices.last, blocks[last].intent == run.presentationIntent {
                blocks[last].spans.append(span)
            } else {
                blocks.append(Block(intent: run.presentationIntent, spans: [span]))
            }
        }

        return blocks
    }
}

// MARK: - Builder

extension PullRequestMarkdown {
    /// 块结构的一个组件。
    fileprivate typealias Component = PresentationIntent.IntentType

    /// 逐块写出带格式的文字：同一个代码块、引用块、列表与表格的各段共用同一个框或列表对象。
    fileprivate struct Builder {
        /// 正在写的表格。
        struct Table {
            /// 表格在块结构里的 identity。
            let identity: Int

            /// 各单元格共用的表格。
            let table: NSTextTable

            /// 各列的对齐。
            let columns: [PresentationIntent.TableColumn]

            /// 表格外层的容器，从外到内。
            let containers: [Component]

            /// 下一个单元格按行优先的位置。
            var next = 0
        }

        /// 已写出的文字；每段末尾都带一个换行，结束时去掉最后一个。
        let output = NSMutableAttributedString()

        /// 引用块与代码块的框，按块的 identity 共用。
        var textBlocks: [Int: NSTextBlock] = [:]

        /// 列表，按列表的 identity 共用。
        var textLists: [Int: NSTextList] = [:]

        /// 已写出标记的列表项。
        var markedItems: Set<Int> = []

        /// 正在写的表格；表格之外为 nil。
        var table: Table? = nil

        /// 下一个块之前要补的空行。
        var blankLines = 0

        /// 上一个块的容器，从外到内。
        var previousContainers: [Component] = []

        /// 写出一个块：分隔线不显示，表格的单元格按位置补齐，其余按块的格式写出。
        mutating func append(_ block: Block) {
            let components = block.intent?.components ?? []
            let containers = Array(components.dropFirst().reversed())
            let leaf = components.first

            // 最外层的列表结束时空一行；列表在引用块里时不空
            if
                let list = Self.outermostList(in: previousContainers),
                !containers.contains(where: { $0.identity == list })
            {
                blankLines += 1
            }

            defer { previousContainers = containers }

            switch leaf?.kind {
            case .thematicBreak:
                return

            case .tableCell(let column):
                appendCell(block.spans, column: column, containers: containers)

            default:
                closeTable()
                appendBlock(block.spans, leaf: leaf, containers: containers)
            }
        }

        /// 收尾：补齐最后一个表格，去掉最后一个换行；还没补上的空行不再写出。
        mutating func finish() -> NSAttributedString {
            closeTable()

            if output.string.hasSuffix("\n") {
                output.deleteCharacters(in: NSRange(location: output.length - 1, length: 1))
            }

            return output
        }

        /// 段落、标题与代码块：列表项的第一块前写出标记，软换行断开的几行共用块的段落样式。
        private mutating func appendBlock(_ spans: [Span], leaf: Component?, containers: [Component]) {
            let format = Self.format(of: leaf?.kind, in: containers)
            let content = Self.content(of: spans, format: format)

            let isCode =
                if case .codeBlock = leaf?.kind {
                    true
                } else {
                    false
                }

            // 代码块原文末尾的换行由段落的换行代替
            if isCode, content.string.hasSuffix("\n") {
                content.deleteCharacters(in: NSRange(location: content.length - 1, length: 1))
            }

            // 只有 HTML 的段落不显示；空的代码块仍是一个空框
            guard content.length > 0 || isCode else {
                return
            }

            appendBlankLines(before: containers)

            let markers = markers(for: containers)

            if !markers.isEmpty {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: format.font,
                    .foregroundColor: format.color,
                ]

                content.insert(NSAttributedString(string: markers, attributes: attributes), at: 0)
            }

            let style = paragraphStyle(for: containers, spacing: format.spacing)

            // 代码块的各行共用一个框，之后空一行
            if isCode, let leaf {
                style.textBlocks.append(codeBlock(leaf.identity))
                blankLines += 1
            }

            appendParagraphs(content, style: style, format: format)
        }

        /// 补上之前记下的空行：空行只带前后两个块共有的引用块与列表。
        private mutating func appendBlankLines(before containers: [Component]) {
            defer { blankLines = 0 }

            guard blankLines > 0, output.length > 0 else {
                return
            }

            let shared = zip(previousContainers, containers).prefix { $0 == $1 }.map(\.0)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: Style.body,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle(for: shared, spacing: 0),
            ]

            let lines = String(repeating: "\n", count: blankLines)
            output.append(NSAttributedString(string: lines, attributes: attributes))
        }

        /// 写出一个块的几行：每行末尾一个换行，除最后一行外都没有段后间距。
        private func appendParagraphs(
            _ content: NSMutableAttributedString,
            style: NSParagraphStyle,
            format: PullRequestMarkdown.Format
        ) {
            let line = NSMutableParagraphStyle()
            line.setParagraphStyle(style)
            line.paragraphSpacing = 0

            let terminator: [NSAttributedString.Key: Any] = [.font: format.font, .foregroundColor: format.color]
            content.append(NSAttributedString(string: "\n", attributes: terminator))
            content.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: content.length))

            // 软换行与硬换行断开的行，以及代码块的各行；最后一个换行属于最后一行
            let newline = UInt16(UInt8(ascii: "\n"))
            var start = 0

            for (offset, unit) in content.string.utf16.enumerated() where unit == newline {
                guard offset < content.length - 1 else {
                    break
                }

                content.addAttribute(
                    .paragraphStyle,
                    value: line,
                    range: NSRange(location: start, length: offset + 1 - start)
                )

                start = offset + 1
            }

            output.append(content)
        }

        /// 这一块所在的、还没写出标记的列表项的标记，从外到内：无序 “• ”，嵌在别的列表里的无序 “◦ ”，有序 “<序号>. ”。
        private mutating func markers(for containers: [Component]) -> String {
            var markers = ""
            var lists = 0
            var ordered = false

            for component in containers {
                switch component.kind {
                case .orderedList, .unorderedList:
                    lists += 1
                    ordered = component.kind == .orderedList

                case .listItem(let ordinal):
                    guard markedItems.insert(component.identity).inserted else {
                        continue
                    }

                    if ordered {
                        markers += "\(ordinal). "
                    } else {
                        markers += lists > 1 ? "◦ " : "• "
                    }

                default:
                    break
                }
            }

            return markers
        }
    }
}

// MARK: - Builder Tables

extension PullRequestMarkdown.Builder {
    /// 写出一个单元格：表头一行是第 0 行；没有文字的单元格在解析结果里不出现，按位置补成空的单元格。
    fileprivate mutating func appendCell(
        _ spans: [PullRequestMarkdown.Span],
        column: Int,
        containers: [PullRequestMarkdown.Component]
    ) {
        guard
            containers.count >= 2,
            case .table(let columns) = containers[containers.count - 2].kind
        else { return }

        let identity = containers[containers.count - 2].identity
        let outer = Array(containers.dropLast(2))

        if table?.identity != identity {
            closeTable()
            appendBlankLines(before: outer)

            let textTable = NSTextTable()
            textTable.numberOfColumns = columns.count
            table = Table(
                identity: identity,
                table: textTable,
                columns: columns,
                containers: outer
            )
        }

        let row: Int =
            if case .tableRow(let index) = containers[containers.count - 1].kind {
                index
            } else {
                0
            }

        let position = row * columns.count + column

        fillCells(upTo: position)
        appendCellParagraph(spans, at: position)
    }

    /// 补齐最后一行的单元格，结束表格；表格之后空一行。
    fileprivate mutating func closeTable() {
        guard let table else {
            return
        }

        let columns = max(table.columns.count, 1)
        fillCells(upTo: (table.next + columns - 1) / columns * columns)

        self.table = nil
        blankLines += 1
    }

    /// 在下一个单元格与给定位置之间补上空的单元格。
    private mutating func fillCells(upTo position: Int) {
        while let next = table?.next, next < position {
            appendCellParagraph([], at: next)
        }
    }

    /// 写出给定位置的单元格：四边 1 pt 边框、内边距 4，表头粗体，按列的对齐排列。
    ///
    /// 相邻单元格的边框只画一次：每格画右边与下边，第一列另画左边，表头一行另画上边。
    private mutating func appendCellParagraph(_ spans: [PullRequestMarkdown.Span], at position: Int) {
        guard var table else {
            return
        }

        let columns = max(table.columns.count, 1)
        let row = position / columns
        let column = position % columns

        let cell = NSTextTableBlock(
            table: table.table,
            startingRow: row,
            rowSpan: 1,
            startingColumn: column,
            columnSpan: 1
        )

        cell.setWidth(1, type: .absoluteValueType, for: .border, edge: .maxX)
        cell.setWidth(1, type: .absoluteValueType, for: .border, edge: .maxY)
        cell.setWidth(column == 0 ? 1 : 0, type: .absoluteValueType, for: .border, edge: .minX)
        cell.setWidth(row == 0 ? 1 : 0, type: .absoluteValueType, for: .border, edge: .minY)
        cell.setBorderColor(AppPalette.nsColor("general_border_color"))
        cell.setWidth(4, type: .absoluteValueType, for: .padding)

        let style = paragraphStyle(for: table.containers, spacing: 0)
        style.textBlocks.append(cell)
        style.alignment = Self.alignment(of: column < table.columns.count ? table.columns[column] : nil)

        // 表头一行粗体
        let body = PullRequestMarkdown.Style.body
        let font = row == 0 ? PullRequestMarkdown.Style.adding(.bold, to: body) : body
        let format = PullRequestMarkdown.Format(font: font, color: Self.textColor(in: table.containers), spacing: 0)

        let content = Self.content(of: spans, format: format)
        let terminator: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: format.color]
        content.append(NSAttributedString(string: "\n", attributes: terminator))
        content.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: content.length))
        output.append(content)

        table.next = position + 1
        self.table = table
    }
}

// MARK: - Builder Styles

extension PullRequestMarkdown.Builder {
    /// 引用块与列表的段落样式：引用块的框与列表从外到内，列表每层缩进 8。
    fileprivate mutating func paragraphStyle(
        for containers: [PullRequestMarkdown.Component],
        spacing: CGFloat
    ) -> NSMutableParagraphStyle {
        var blocks: [NSTextBlock] = []
        var lists: [NSTextList] = []

        for component in containers {
            switch component.kind {
            case .blockQuote:
                blocks.append(quoteBlock(component.identity))

            case .orderedList, .unorderedList:
                lists.append(list(component, nested: !lists.isEmpty))

            default:
                break
            }
        }

        let style = NSMutableParagraphStyle()
        style.textBlocks = blocks
        style.textLists = lists
        style.firstLineHeadIndent = PullRequestMarkdown.Style.listIndentation * CGFloat(lists.count)
        style.headIndent = style.firstLineHeadIndent
        style.paragraphSpacing = spacing
        return style
    }

    /// 代码块的框：四边 1 pt 边框、内边距 8，宽度占满；底色与边框随外观切换。
    fileprivate mutating func codeBlock(_ identity: Int) -> NSTextBlock {
        if let block = textBlocks[identity] {
            return block
        }

        let block = NSTextBlock()
        block.setWidth(1, type: .absoluteValueType, for: .border)
        block.setBorderColor(AppPalette.nsColor("general_border_color"))
        block.setWidth(8, type: .absoluteValueType, for: .padding)
        block.setContentWidth(100, type: .percentageValueType)
        block.backgroundColor = AppPalette.nsColor("repository_pullrequests_code_block_background_color")

        textBlocks[identity] = block
        return block
    }

    /// 引用块的框：四边 4 pt 边框只有左边画出竖条，左右内边距 8，宽度占满，没有底色。
    private mutating func quoteBlock(_ identity: Int) -> NSTextBlock {
        if let block = textBlocks[identity] {
            return block
        }

        let block = NSTextBlock()
        block.setWidth(4, type: .absoluteValueType, for: .border)
        block.setBorderColor(AppPalette.nsColor("general_border_color"), for: .minX)
        block.setWidth(8, type: .absoluteValueType, for: .padding, edge: .minX)
        block.setWidth(8, type: .absoluteValueType, for: .padding, edge: .maxX)
        block.setContentWidth(100, type: .percentageValueType)

        textBlocks[identity] = block
        return block
    }

    /// 列表：有序用数字，无序用实心圆点，嵌在别的列表里的无序用空心圆点。
    private mutating func list(_ component: PullRequestMarkdown.Component, nested: Bool) -> NSTextList {
        if let list = textLists[component.identity] {
            return list
        }

        let format: NSTextList.MarkerFormat =
            if component.kind == .orderedList {
                .decimal
            } else {
                nested ? .circle : .disc
            }

        let list = NSTextList(markerFormat: format, options: 0)
        textLists[component.identity] = list
        return list
    }
}

// MARK: - Builder Helpers

extension PullRequestMarkdown.Builder {
    /// 块的字体、颜色与段后间距：标题段后 12，代码块段后 0，段落在列表里段后 0、其余 12。
    fileprivate static func format(
        of kind: PresentationIntent.Kind?,
        in containers: [PullRequestMarkdown.Component]
    ) -> PullRequestMarkdown.Format {
        let style = PullRequestMarkdown.Style.self
        let color = textColor(in: containers)

        switch kind {
        case .header(let level):
            // H6 用次一级的文字色；在引用块里时与引用块的文字相同
            let quoted = containers.contains { $0.kind == .blockQuote }
            let headerColor = level >= 6 && !quoted ? NSColor.secondaryLabelColor : color

            return PullRequestMarkdown.Format(
                font: style.header(level: level),
                color: headerColor,
                spacing: style.paragraphSpacing
            )

        case .codeBlock:
            let codeColor = AppPalette.nsColor("repository_pullrequests_code_block_text_color")
            return PullRequestMarkdown.Format(font: style.code, color: codeColor, spacing: 0)

        default:
            let inList = containers.contains { $0.kind == .orderedList || $0.kind == .unorderedList }
            return PullRequestMarkdown.Format(
                font: style.body,
                color: color,
                spacing: inList ? 0 : style.paragraphSpacing
            )
        }
    }

    /// 引用块里的文字用停用控件的文字色，其余用正文色。
    fileprivate static func textColor(in containers: [PullRequestMarkdown.Component]) -> NSColor {
        containers.contains { $0.kind == .blockQuote } ? .disabledControlTextColor : .labelColor
    }

    /// 最外层的列表：容器从外到内先遇到列表时是它，先遇到引用块时为 nil。
    fileprivate static func outermostList(in containers: [PullRequestMarkdown.Component]) -> Int? {
        for component in containers {
            switch component.kind {
            case .orderedList, .unorderedList: return component.identity
            case .blockQuote: return nil
            default: continue
            }
        }

        return nil
    }

    /// 块里的文字：行内 HTML 只去掉标签，软换行换成换行；斜体、粗体加在块的字体上，行内代码用等宽 12 pt。
    fileprivate static func content(
        of spans: [PullRequestMarkdown.Span],
        format: PullRequestMarkdown.Format
    ) -> NSMutableAttributedString {
        let content = NSMutableAttributedString()

        for span in spans where !span.inline.contains(.inlineHTML) {
            var traits: NSFontDescriptor.SymbolicTraits = []

            if span.inline.contains(.emphasized) {
                traits.insert(.italic)
            }

            if span.inline.contains(.stronglyEmphasized) {
                traits.insert(.bold)
            }

            let style = PullRequestMarkdown.Style.self

            var attributes: [NSAttributedString.Key: Any] = [
                .font: span.inline.contains(.code) ? style.code : style.adding(traits, to: format.font),
                .foregroundColor: format.color,
            ]

            if span.inline.contains(.strikethrough) {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }

            if let link = span.link {
                attributes[.link] = link
            }

            let text = span.inline.contains(.softBreak) ? "\n" : span.text
            content.append(NSAttributedString(string: text, attributes: attributes))
        }

        return content
    }

    /// 列的对齐：没有写明时靠左。
    private static func alignment(of column: PresentationIntent.TableColumn?) -> NSTextAlignment {
        switch column?.alignment {
        case .center: .center
        case .right: .right
        default: .left
        }
    }
}
