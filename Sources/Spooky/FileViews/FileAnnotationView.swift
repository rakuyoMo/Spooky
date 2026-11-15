import AppKit
import SpookyKit

// MARK: - FileAnnotationView

/// Blame 的注释栏：在正文右边，随正文纵向滚动，左缘可以按住拖动调整宽度。
///
/// 底色与正文不同，两栏之间不画分隔线；每段第一行最左是头像，后面是提交标题，右边是作者与相对日期。
final class FileAnnotationView: NSView {
    /// 拖动左缘时注释栏宽度的范围。
    static let annotationWidths: ClosedRange<CGFloat> = 175 ... 600

    /// 没有保存过宽度时注释栏的宽度。
    static let defaultAnnotationWidth: CGFloat = 405

    /// 注释栏宽度在偏好里的键：拖动后保存，所有窗口共用。
    static let annotationWidthKey = "blameAnnotationWidth"

    /// 左缘可以按住拖动的宽度。
    private static let dividerHitWidth: CGFloat = 3

    /// 注释文字的字号。
    private static let fontSize: CGFloat = 11

    /// 段第一行头像的直径。
    private static let avatarSize: CGFloat = 21

    /// 单击注释：段的序号、段第一行在本视图中的矩形与本视图。
    var clicked: ((Int, NSRect, NSView) -> Void)?

    /// 双击注释：段的序号。
    var doubleClicked: ((Int) -> Void)?

    /// 拖动改变了宽度，容器据此重新排版。
    var widthChanged: (() -> Void)?

    /// 注释栏当前的宽度：取自偏好，限制在可拖动的范围内。
    private(set) var width = FileAnnotationView.clampedWidth(
        (UserDefaults.standard.object(forKey: FileAnnotationView.annotationWidthKey) as? CGFloat)
            ?? FileAnnotationView.defaultAnnotationWidth
    )

    /// 对应的正文。
    private weak var document: FileTextDocumentView?

    /// 正文所在的滚动视图，决定纵向偏移。
    private weak var scrollView: NSScrollView?

    /// Blame 的注释。
    private var annotations: FileTextAnnotations?

    /// 已读到的头像，键是作者邮箱。
    private var avatars: [String: NSImage] = [:]

    /// 已经请求过头像的邮箱，没有头像的不再重复请求。
    private var requestedAvatars = Set<String>()

    /// 与正文使用同样的翻转坐标。
    override var isFlipped: Bool { true }

    /// 绑定正文与滚动视图；正文滚动时重绘。
    ///
    /// - Parameters:
    ///   - scrollView: 正文所在的滚动视图。
    ///   - document: 正文。
    init(scrollView: NSScrollView, document: FileTextDocumentView) {
        self.scrollView = scrollView
        self.document = document
        super.init(frame: .zero)

        // 底色只铺在注释栏自己的范围内，不盖住左边的正文与上方的头部
        clipsToBounds = true

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipViewScrolled),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    /// 视图由代码构建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("FileAnnotationView 不从归档恢复")
    }

    /// 换上新的注释并重绘。
    func update(annotations: FileTextAnnotations?) {
        self.annotations = annotations
        needsDisplay = true
    }

    /// 铺注释栏的底色，再画可见的段：高亮底色、段之间的分隔线与第一行的注释。
    override func draw(_ dirtyRect: NSRect) {
        guard let document, let style = document.style, style.lineHeight > 0 else {
            return
        }

        style.annotationBackground.setFill()
        dirtyRect.fill()

        guard let annotations else {
            return
        }

        // 换算到正文坐标，取出与重绘范围相交的段
        let visible = NSRect(x: 0, y: dirtyRect.minY + scrollOffset, width: 1, height: dirtyRect.height)

        for index in document.visibleGroups(in: visible, annotations: annotations) {
            let group = annotations.groups[index]
            let rect = firstRowRect(of: group, style: style)

            if group.commitID == annotations.highlightedCommit {
                style.annotationHighlight.setFill()
                NSRect(
                    x: 0,
                    y: rect.minY,
                    width: bounds.width,
                    height: CGFloat(group.lineCount) * style.lineHeight
                )
                .fill()
            }

            if index > 0 {
                style.separator.setFill()
                NSRect(x: 0, y: rect.minY, width: bounds.width, height: 1).fill()
            }

            if let commit = annotations.commits[group.commitID] {
                drawAnnotation(commit, in: rect, style: style)
            }
        }
    }

    /// 左缘显示左右调整的光标。
    override func resetCursorRects() {
        addCursorRect(
            NSRect(x: 0, y: 0, width: Self.dividerHitWidth, height: bounds.height),
            cursor: .resizeLeftRight
        )
    }

    /// 按住左缘拖动宽度；单击注释弹出提交摘要，双击回到对应的提交。
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if point.x < Self.dividerHitWidth {
            trackDivider()

            return
        }

        guard let document, let style = document.style, style.lineHeight > 0, let annotations else {
            return
        }

        // 换算到正文坐标，得到点中的行与段
        let y = point.y + scrollOffset
        let line = Int(((y - document.topInset) / style.lineHeight).rounded(.down)) + 1

        guard let index = annotations.groupIndex(containing: line) else {
            return
        }

        if event.clickCount >= 2 {
            doubleClicked?(index)
        } else {
            clicked?(index, firstRowRect(of: annotations.groups[index], style: style), self)
        }
    }

    /// 在注释栏上滚动同样滚动正文。
    override func scrollWheel(with event: NSEvent) {
        scrollView?.scrollWheel(with: event)
    }

    /// 正文滚动后跟着重绘。
    @objc
    private func clipViewScrolled() {
        needsDisplay = true
    }
}

// MARK: - Private

extension FileAnnotationView {
    /// 相对日期用完整单位名，如 “2 months ago”。
    private static var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        return formatter
    }

    /// 正文已经向上滚过的距离。
    private var scrollOffset: CGFloat {
        scrollView?.contentView.bounds.minY ?? 0
    }

    /// 把宽度限制在可拖动的范围内。
    private static func clampedWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, annotationWidths.lowerBound), annotationWidths.upperBound)
    }

    /// 段第一行在本视图中的矩形。
    private func firstRowRect(of group: BlameGroup, style: FileTextStyle) -> NSRect {
        let top = (document?.lineTop(group.firstLine - 1) ?? 0) - scrollOffset
        return NSRect(x: 0, y: top, width: bounds.width, height: style.lineHeight)
    }

    /// 跟随鼠标调整宽度，注释栏的右缘不动；松开后保存到偏好。
    private func trackDivider() {
        while let event = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            guard let superview else {
                return
            }

            let x = superview.convert(event.locationInWindow, from: nil).x
            width = Self.clampedWidth(frame.maxX - x)
            widthChanged?()

            guard event.type == .leftMouseUp else {
                continue
            }

            UserDefaults.standard.set(Double(width), forKey: Self.annotationWidthKey)
            window?.invalidateCursorRects(for: self)

            return
        }
    }

    /// 一行注释：最左是头像，标题紧随其后并按宽度截断，作者与相对日期靠右。
    private func drawAnnotation(_ commit: BlameCommit, in rect: NSRect, style: FileTextStyle) {
        let font = NSFont.systemFont(ofSize: Self.fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail

        let date = Self.relativeFormatter.localizedString(for: commit.authorDate, relativeTo: Date())
        let detail = NSAttributedString(
            string: commit.author + "  " + date,
            attributes: [.font: font, .foregroundColor: style.secondary, .paragraphStyle: paragraph]
        )
        let title = NSAttributedString(
            string: commit.summary,
            attributes: [.font: font, .foregroundColor: style.text, .paragraphStyle: paragraph]
        )

        // 头像在第一行里竖直居中
        let avatarRect = NSRect(
            x: rect.minX + 6,
            y: rect.minY + (rect.height - Self.avatarSize) / 2,
            width: Self.avatarSize,
            height: Self.avatarSize
        )

        drawAvatar(for: commit, in: avatarRect)

        // 文字同样竖直居中；作者与日期最多占一半宽度
        let textHeight = (font.ascender - font.descender).rounded(.up)
        let y = rect.minY + (rect.height - textHeight) / 2
        let titleX = avatarRect.maxX + 6
        let detailWidth = min(detail.size().width.rounded(.up), (rect.width - titleX) / 2)

        detail.draw(
            with: NSRect(x: rect.maxX - 6 - detailWidth, y: y, width: detailWidth, height: textHeight),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )

        title.draw(
            with: NSRect(
                x: titleX,
                y: y,
                width: max(0, rect.maxX - 18 - detailWidth - titleX),
                height: textHeight
            ),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )
    }

    /// 圆形头像：读到图片前与没有图片时写姓名缩写，外圈 1 pt 分隔线色的描边。
    private func drawAvatar(for commit: BlameCommit, in rect: NSRect) {
        let circle = NSBezierPath(ovalIn: rect)

        NSGraphicsContext.saveGraphicsState()
        circle.addClip()

        if let image = avatar(for: commit.authorEmail) {
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        } else {
            AppPalette.nsColor("avatar_background_color").setFill()
            rect.fill()

            // 缩写按直径缩放字号，在圆里居中
            let initials = NSAttributedString(
                string: InitialsAvatar.initials(of: commit.author),
                attributes: [
                    .font: NSFont.systemFont(ofSize: rect.height * 0.4, weight: .medium),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
            let size = initials.size()

            initials.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
        }

        NSGraphicsContext.restoreGraphicsState()

        NSColor.separatorColor.setStroke()
        NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }

    /// 作者的头像，来源与缓存和历史列表相同；第一次用到时在后台读取，读到后重绘。
    private func avatar(for email: String) -> NSImage? {
        if let image = avatars[email] {
            return image
        }

        guard !requestedAvatars.contains(email) else {
            return nil
        }

        requestedAvatars.insert(email)

        Task { [weak self] in
            guard let image = await AvatarStore.shared.image(for: email) else {
                return
            }

            self?.avatars[email] = image
            self?.needsDisplay = true
        }

        return nil
    }

}
