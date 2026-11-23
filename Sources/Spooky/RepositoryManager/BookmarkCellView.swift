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

// MARK: - BookmarkWorktreeItem

/// 大纲视图里一个工作树的行对象：按所在书签与工作树路径复用，刷新后选中才能保留。
final class BookmarkWorktreeItem: NSObject {
    /// 工作树；每次列出子行时换成最近读到的。
    var worktree: Worktree

    /// 工作树所属仓库的位置。
    var repository: RepositoryLocation

    /// 工作树的位置，打开与菜单都用它；失效的工作树为 nil。
    var location: RepositoryLocation? {
        RepositorySession.location(of: worktree, in: repository)
    }

    /// 创建一个工作树的行对象。
    ///
    /// - Parameters:
    ///   - worktree: 工作树。
    ///   - repository: 工作树所属仓库的位置。
    init(worktree: Worktree, repository: RepositoryLocation) {
        self.worktree = worktree
        self.repository = repository
    }
}

// MARK: - BookmarkOutlineView

/// 书签列表：回车给选中的书签改名，删除键删除选中的书签；书签只能在应用内拖动。
final class BookmarkOutlineView: NSOutlineView {
    /// 回车或换行键的动作。
    var onRename: (() -> Void)?

    /// 删除键的动作。
    var onDelete: (() -> Void)?

    /// 回车改名、删除键删除，其余按键照常处理。
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            onRename?()

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

// MARK: - BookmarkNameField

/// 书签的名称：平时不能编辑，点它不进入改名；改名期间可以编辑，提交或取消后复原。
final class BookmarkNameField: NSTextField {
    /// 提交编辑、通知委托之后复原。
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)

        endRenaming()
    }

    /// 取消编辑后复原；取消不经过 `textDidEndEditing`。
    override func abortEditing() -> Bool {
        let aborted = super.abortEditing()

        endRenaming()
        return aborted
    }

    /// 设成可以编辑，由列表接着开始编辑。
    func beginRenaming() {
        isEditable = true
    }

    /// 回到不能编辑也不能选中文字的标签。
    func endRenaming() {
        isEditable = false
        isSelectable = false
    }
}

// MARK: - BookmarkCellView

/// 书签或工作树的一行：16 pt 图标、名称与警告图标或克隆进度；服务器仓库按设置在名称前带主机前缀，书签的名称可以原地改。
final class BookmarkCellView: NSTableCellView {
    /// 复用单元格的标识。
    static let identifier = NSUserInterfaceItemIdentifier("BookmarkCellView")

    /// 服务器仓库的主机前缀，不随改名编辑。
    private let hostField = NSTextField(labelWithString: "")

    /// 仓库失效时的警告图标，VoiceOver 读作 “Unavailable”：失效状态不只靠图标与颜色表达。
    private let warningView = NSImageView()

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
    ///   - showsHost: 服务器仓库是否在名称前写主机别名；悬停提示与 VoiceOver 的名字不论如何都带主机前缀。
    func configure(_ bookmark: Bookmark, isMissing: Bool, clone: CloneActivity? = nil, showsHost: Bool = true) {
        let isMissing = isMissing && clone == nil

        imageView?.image = NSImage(systemSymbolName: bookmark.symbolName, accessibilityDescription: nil)
        textField?.stringValue = bookmark.name

        let host = showsHost ? bookmark.location?.host : nil
        hostField.stringValue = host.map { $0 + ":" } ?? ""
        hostField.isHidden = host == nil

        showUnavailable(isMissing)
        showProgress(clone?.isRunning ?? false ? clone?.progress : nil, running: clone?.isRunning ?? false)

        toolTip = bookmark.location?.displayPath
        setAccessibilityLabel(bookmark.displayName)
    }

    /// 显示仓库的一个工作树：名称不能改，失效时与失效的书签一样。
    ///
    /// - Parameters:
    ///   - worktree: 工作树。
    ///   - repository: 工作树所属的仓库；服务器仓库的悬停提示里，路径带它的主机前缀。
    func configure(_ worktree: Worktree, in repository: RepositoryLocation) {
        imageView?.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: nil)
        textField?.stringValue = worktree.name
        textField?.isEditable = false

        hostField.stringValue = ""
        hostField.isHidden = true

        showUnavailable(!worktree.isValid)
        showProgress(nil, running: false)

        toolTip = RepositorySidebarView.tooltip(of: worktree, in: repository)
        setAccessibilityLabel(worktree.name)
    }
}

// MARK: - Layout

extension BookmarkCellView {
    /// 失效时名称与主机前缀变灰，右端显示警告图标。
    private func showUnavailable(_ isUnavailable: Bool) {
        let color: NSColor = isUnavailable ? .disabledControlTextColor : .controlTextColor
        textField?.textColor = color
        hostField.textColor = color
        warningView.isHidden = !isUnavailable
    }

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

    /// 图标距左 3 pt，名称在图标右侧 8 pt，警告图标或进度在名称右侧 8 pt、距右 3 pt。
    private func configureViews() {
        let icon = NSImageView()
        icon.symbolConfiguration = .init(pointSize: 13, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        imageView = icon

        let name = BookmarkNameField(labelWithString: "")
        name.font = .systemFont(ofSize: 13)
        name.lineBreakMode = .byTruncatingTail
        name.usesSingleLineMode = true
        name.cell?.isScrollable = false
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField = name

        hostField.font = .systemFont(ofSize: 13)
        hostField.setContentHuggingPriority(.required, for: .horizontal)
        hostField.setContentCompressionResistancePriority(.required, for: .horizontal)

        // 表格单元格不向辅助功能提供值，失效状态由警告图标的描述读出
        warningView.image = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: AppLocalization.text("repositories.unavailableShort")
        )
        warningView.contentTintColor = .systemYellow

        progressView.style = .spinning
        progressView.controlSize = .small
        progressView.minValue = 0
        progressView.maxValue = 100
        progressView.isHidden = true
        progressView.setAccessibilityLabel(AppLocalization.text("clone.state.running"))

        // 隐藏的前缀、警告图标与进度不占位置，名称占满剩下的宽度
        let stack = NSStackView(views: [icon, hostField, name, warningView, progressView])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 0
        stack.setCustomSpacing(8, after: icon)
        stack.setCustomSpacing(8, after: name)
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
