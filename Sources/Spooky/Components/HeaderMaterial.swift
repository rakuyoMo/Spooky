import AppKit
import SwiftUI

// MARK: - HeaderMaterial

/// 跟随窗口活跃状态的原生头部材质，文件头部、Working Copy 的分支栏与提交区共用。
///
/// 底边分隔线与输入框的底和描边画在材质视图里面，由系统随材质合成：深色下比周围亮，浅色下比周围暗。
/// 叠在材质之上的 SwiftUI 视图不参与这种合成。
struct HeaderMaterial: NSViewRepresentable {
    /// 是否在底边贴一条 1 pt 分隔线。
    var showsBottomSeparator = false

    /// 各输入框的位置，以材质的左上角为原点。
    var fieldFrames: [CGRect] = []

    /// 不强调的 headerView 材质在窗口内部混合，需要时在底边贴上分隔线。
    func makeNSView(context _: Context) -> HeaderMaterialView {
        let view = HeaderMaterialView()
        view.material = .headerView
        view.blendingMode = .withinWindow
        view.state = .followsWindowActiveState

        if showsBottomSeparator {
            view.addBottomSeparator()
        }

        return view
    }

    /// 输入框跟随 SwiftUI 量出的位置。
    func updateNSView(_ view: HeaderMaterialView, context _: Context) {
        view.fieldFrames = fieldFrames
    }
}

// MARK: - HeaderMaterialView

/// 头部材质视图：坐标自上而下，与 SwiftUI 量出的位置一致。
final class HeaderMaterialView: NSVisualEffectView {
    /// 各输入框的位置；少了的输入框随之移除。
    var fieldFrames: [CGRect] = [] {
        didSet {
            guard fieldFrames != oldValue else {
                return
            }

            needsLayout = true
        }
    }

    /// 底边的分隔线；没有时为 nil。
    private var separator: HeaderMaterialLayer?

    /// 已经放进材质的输入框，与 `fieldFrames` 依次对应。
    private var fields: [HeaderMaterialLayer] = []

    /// 坐标从顶边向下增长。
    override var isFlipped: Bool { true }

    /// 分隔线贴住底边，输入框按最新的位置摆放。
    override func layout() {
        super.layout()

        separator?.frame = NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1)
        placeFields()
    }

    /// 在底边贴一条横贯全宽的 1 pt 分隔线，颜色是 `separatorColor`。
    func addBottomSeparator() {
        let separator = HeaderMaterialLayer(fill: .separatorColor)
        addSubview(separator)

        self.separator = separator
        needsLayout = true
    }
}

// MARK: - Private

extension HeaderMaterialView {
    /// 按位置放上、挪动或移除输入框：底色取 `text_view_background_color`，1 pt `separatorColor` 描边，圆角 5。
    private func placeFields() {
        // 输入框比位置多时移除多出来的，少时补上
        while fields.count > fieldFrames.count {
            fields.removeLast().removeFromSuperview()
        }

        while fields.count < fieldFrames.count {
            let field = HeaderMaterialLayer(
                fill: AppPalette.nsColor("text_view_background_color"),
                border: .separatorColor,
                cornerRadius: 5
            )

            addSubview(field)
            fields.append(field)
        }

        for (field, frame) in zip(fields, fieldFrames) {
            field.frame = frame
        }
    }
}

// MARK: - HeaderMaterialLayer

/// 材质里的一块图层：底色、描边与圆角在创建时给定，由系统随材质合成。
private final class HeaderMaterialLayer: NSView {
    /// 底色。
    private let fill: NSColor

    /// 1 pt 描边的颜色；为 nil 时不描边。
    private let border: NSColor?

    /// 允许系统按材质合成底色与描边。
    override var allowsVibrancy: Bool { true }

    /// 底色与描边由图层绘制。
    override var wantsUpdateLayer: Bool { true }

    /// 建立图层。
    ///
    /// - Parameters:
    ///   - fill: 底色。
    ///   - border: 1 pt 描边的颜色；为 nil 时不描边。
    ///   - cornerRadius: 圆角半径。
    init(fill: NSColor, border: NSColor? = nil, cornerRadius: CGFloat = 0) {
        self.fill = fill
        self.border = border
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.borderWidth = border == nil ? 0 : 1
    }

    /// 只由代码创建。
    required init?(coder _: NSCoder) { nil }

    /// 不抢占上方控件的鼠标命中。
    override func hitTest(_: NSPoint) -> NSView? { nil }

    /// 按当前外观取底色与描边色。
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = fill.cgColor
            layer?.borderColor = border?.cgColor
        }
    }
}
