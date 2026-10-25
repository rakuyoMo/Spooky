import AppKit

// MARK: - QuickActionCellView

/// 结果表的一行：32 × 30 的符号、标题与副标题，选中时右侧显示按键提示。
final class QuickActionCellView: NSTableCellView {
    /// 行高。
    static let height: CGFloat = 40

    /// 表格里复用的标识。
    static let identifier = NSUserInterfaceItemIdentifier("QuickActionCell")

    /// 11 pt 的类型名，跟在标题下方。
    private let subtitleField = NSTextField(labelWithString: "")

    /// 13 pt 的按键提示，只在选中行显示。
    private let hintField = NSTextField(labelWithString: "")

    /// 未选中时把提示的宽度压成 0，标题与副标题占满整行。
    private var hintWidth: NSLayoutConstraint?

    /// 选中时提示占出宽度，文字随强调色的底换成反色；未选中时收起提示。
    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            subtitleField.cell?.backgroundStyle = backgroundStyle
            hintField.cell?.backgroundStyle = backgroundStyle
            imageView?.contentTintColor = backgroundStyle == .emphasized ? .alternateSelectedControlTextColor : .labelColor
            updateHint()
        }
    }

    /// 按固定的间距排好符号、文字与提示。
    override init(frame: NSRect) {
        super.init(frame: frame)

        identifier = Self.identifier

        let icon = NSImageView()
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .light, scale: .large)
        icon.contentTintColor = .labelColor
        imageView = icon

        let title = NSTextField(labelWithString: "")
        title.font = .systemFont(ofSize: 13)
        title.textColor = .controlTextColor
        title.lineBreakMode = .byTruncatingTail
        textField = title

        subtitleField.font = .systemFont(ofSize: 11)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.lineBreakMode = .byTruncatingTail

        hintField.font = .systemFont(ofSize: 13)
        hintField.textColor = .controlTextColor
        hintField.alignment = .center
        hintField.maximumNumberOfLines = 2
        hintField.setContentHuggingPriority(.required, for: .horizontal)
        hintField.setContentCompressionResistancePriority(.required, for: .horizontal)

        for view in [icon, title, subtitleField, hintField] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        activateConstraints(icon: icon, title: title)
        updateHint()
    }

    /// 只从代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 填入一行的内容。
    ///
    /// - Parameter hint: 对象行是 “默认动作 ↩︎” 与 “More Actions ⇥” 两行，动作行是 “↩︎”。
    func configure(_ item: QuickActionItem, hint: String) {
        imageView?.image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)
        textField?.stringValue = item.title
        subtitleField.stringValue = item.subtitle
        hintField.stringValue = hint
        setAccessibilityLabel(item.title + ", " + item.subtitle)
    }
}

// MARK: - Private

extension QuickActionCellView {
    /// 符号距左 14 pt（行的选中底左右各内缩 10 pt），文字距符号 8 pt，标题距顶 4 pt，提示距右 14 pt。
    private func activateConstraints(icon: NSImageView, title: NSTextField) {
        let hintWidth = hintField.widthAnchor.constraint(equalToConstant: 0)
        self.hintWidth = hintWidth

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 30),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            title.topAnchor.constraint(equalTo: topAnchor, constant: 4),

            subtitleField.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitleField.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            subtitleField.topAnchor.constraint(equalTo: title.bottomAnchor),

            hintField.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
            hintField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            hintField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    /// 提示只在选中行显示。
    private func updateHint() {
        let selected = backgroundStyle == .emphasized
        hintWidth?.isActive = !selected
        hintField.isHidden = !selected
    }
}

// MARK: - QuickActionEmptyCellView

/// 没有结果时唯一的一行：居中的 No Results，不可选。
final class QuickActionEmptyCellView: NSTableCellView {
    /// 表格里复用的标识。
    static let identifier = NSUserInterfaceItemIdentifier("QuickActionEmptyCell")

    /// 13 pt 的文字居中摆放。
    override init(frame: NSRect) {
        super.init(frame: frame)

        identifier = Self.identifier

        let label = NSTextField(labelWithString: AppLocalization.text("quickActions.noResults"))
        label.font = .systemFont(ofSize: 13)
        label.textColor = .controlTextColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        textField = label

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    /// 只从代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - QuickActionRowView

/// 结果表的行：选中底是左右各内缩 10 pt、圆角 6 pt 的强调色圆角矩形。
final class QuickActionRowView: NSTableRowView {
    /// 表格里复用的标识。
    static let identifier = NSUserInterfaceItemIdentifier("QuickActionRow")

    /// 焦点始终在输入框里，选中行仍按有焦点的样式绘制，文字随之反色。
    override var isEmphasized: Bool {
        get { true }
        set { }
    }

    /// 自绘圆角的选中底。
    override func drawSelection(in _: NSRect) {
        NSColor.selectedContentBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 0), xRadius: 6, yRadius: 6).fill()
    }
}
