import AppKit
import SpookyKit

// MARK: - BookmarkOutlineItem

/// 大纲视图里一行对应的对象：根分组标题，或一个书签。
///
/// 书签行按身份复用同一个对象，刷新后展开与选中状态才能保留。
final class BookmarkOutlineItem: NSObject {
    /// 书签的身份；根分组标题没有。
    let id: Bookmark.ID?

    /// 创建一行对应的对象。
    ///
    /// - Parameter id: 书签的身份；nil 表示根分组标题。
    init(id: Bookmark.ID?) {
        self.id = id
    }
}

// MARK: - BookmarkOutlineView

/// 书签列表：回车打开选中的仓库，删除键删除选中的书签；书签只能在应用内拖动。
final class BookmarkOutlineView: NSOutlineView {
    /// 回车或换行键的动作。
    var onOpen: (() -> Void)?

    /// 删除键的动作。
    var onDelete: (() -> Void)?

    /// 回车打开、删除键删除，其余按键照常处理。
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            onOpen?()

        case 51, 117:
            onDelete?()

        default:
            super.keyDown(with: event)
        }
    }

    /// 拖到应用外不产生任何动作，应用内只做移动。
    override func draggingSession(
        _: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }

    /// 拖动时按住修饰键也只做移动。
    override func ignoreModifierKeys(for _: NSDraggingSession) -> Bool {
        true
    }
}

// MARK: - BookmarkCellView

/// 书签的一行：16 pt 图标、名称与失效标记或克隆进度；服务器仓库在名称前带主机前缀，名称可以原地改。
final class BookmarkCellView: NSTableCellView {
    /// 复用单元格的标识。
    static let identifier = NSUserInterfaceItemIdentifier("BookmarkCellView")

    /// 服务器仓库的主机前缀，不随改名编辑。
    private let hostField = NSTextField(labelWithString: "")

    /// 仓库失效时的警告图标。
    private let warningView = NSImageView()

    /// 仓库失效时的文字说明，失效状态不只靠图标与颜色表达。
    private let warningField = NSTextField(labelWithString: AppLocalization.text("repositories.unavailableShort"))

    /// 克隆中的 16 pt 进度：Git 报告百分比后是确定进度，之前转圈。
    private let progressView = NSProgressIndicator()

    /// 按代码布局创建单元格。
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        identifier = Self.identifier
        configureViews()
    }

    /// 单元格只由代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    /// 显示一个书签。
    ///
    /// - Parameters:
    ///   - bookmark: 要显示的书签。
    ///   - isMissing: 仓库是否已失效；克隆中不算失效。
    ///   - clone: 正在克隆到这个书签的活动；没有时为 nil。
    func configure(_ bookmark: Bookmark, isMissing: Bool, clone: CloneActivity? = nil) {
        let isMissing = isMissing && clone == nil

        imageView?.image = NSImage(systemSymbolName: bookmark.symbolName, accessibilityDescription: nil)
        textField?.stringValue = bookmark.name

        let host = bookmark.location?.host
        hostField.stringValue = host.map { $0 + ":" } ?? ""
        hostField.isHidden = host == nil

        // 失效的仓库名称变灰，并带警告图标与文字
        let color: NSColor = isMissing ? .disabledControlTextColor : .controlTextColor
        textField?.textColor = color
        hostField.textColor = color
        warningView.isHidden = !isMissing
        warningField.isHidden = !isMissing
        showProgress(clone?.isRunning ?? false ? clone?.progress : nil, running: clone?.isRunning ?? false)

        toolTip = bookmark.location?.displayPath
        setAccessibilityLabel(bookmark.displayName)
        setAccessibilityValue(isMissing ? AppLocalization.text("repositories.unavailableShort") : nil)
    }
}

// MARK: - Layout

extension BookmarkCellView {
    /// 克隆中显示进度：有百分比时是确定进度，没有时转圈；不在克隆时隐藏。
    private func showProgress(_ progress: CloneProgress?, running: Bool) {
        progressView.isHidden = !running

        guard running else {
            progressView.stopAnimation(nil)
            return
        }

        if let fraction = progress?.fraction {
            progressView.isIndeterminate = false
            progressView.doubleValue = fraction * 100
        } else {
            progressView.isIndeterminate = true
            progressView.startAnimation(nil)
        }
    }

    /// 图标距左 3 pt，名称在图标右侧 8 pt，失效标记距右 3 pt。
    private func configureViews() {
        let icon = NSImageView()
        icon.symbolConfiguration = .init(pointSize: 13, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        imageView = icon

        let name = NSTextField(labelWithString: "")
        name.font = .systemFont(ofSize: 13)
        name.isEditable = true
        name.lineBreakMode = .byTruncatingTail
        name.usesSingleLineMode = true
        name.cell?.isScrollable = false
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField = name

        hostField.font = .systemFont(ofSize: 13)
        hostField.setContentHuggingPriority(.required, for: .horizontal)
        hostField.setContentCompressionResistancePriority(.required, for: .horizontal)

        warningView.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        warningView.contentTintColor = .systemYellow
        warningView.setAccessibilityElement(false)

        warningField.font = .systemFont(ofSize: 11)
        warningField.textColor = .secondaryLabelColor
        warningField.setContentHuggingPriority(.required, for: .horizontal)
        warningField.setContentCompressionResistancePriority(.required, for: .horizontal)
        warningField.setAccessibilityElement(false)

        progressView.style = .spinning
        progressView.controlSize = .small
        progressView.minValue = 0
        progressView.maxValue = 100
        progressView.isHidden = true
        progressView.setAccessibilityLabel(AppLocalization.text("clone.state.running"))

        // 隐藏的前缀、失效标记与进度不占位置，名称占满剩下的宽度
        let stack = NSStackView(views: [icon, hostField, name, warningView, warningField, progressView])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 0
        stack.setCustomSpacing(8, after: icon)
        stack.setCustomSpacing(6, after: name)
        stack.setCustomSpacing(3, after: warningView)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        name.setContentHuggingPriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),

            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            warningView.widthAnchor.constraint(equalToConstant: 16),
            warningView.heightAnchor.constraint(equalToConstant: 16),
            progressView.widthAnchor.constraint(equalToConstant: 16),
            progressView.heightAnchor.constraint(equalToConstant: 16),
        ])
    }
}
