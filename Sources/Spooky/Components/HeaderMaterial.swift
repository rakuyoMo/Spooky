import AppKit
import SwiftUI

// MARK: - HeaderMaterial

/// 跟随窗口活跃状态的原生头部材质，文件头部、Working Copy 的分支栏与提交区共用。
///
/// 底边分隔线、输入框的底和描边，以及输入区与动作栏之间的分隔线画在材质视图里面，由系统随材质合成：深色下比周围亮，浅色下比周围暗。
/// 叠在材质之上的 SwiftUI 视图不参与这种合成。
struct HeaderMaterial: NSViewRepresentable {
    /// 是否在底边贴一条 1 pt 分隔线。
    var showsBottomSeparator = false

    /// 材质要画出的输入框。
    var fields: [HeaderMaterialField] = []

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
        view.fields = fields
    }
}

// MARK: - HeaderMaterialField

/// 材质里的一个输入框。
struct HeaderMaterialField: Equatable {
    /// 输入框的位置，以材质的左上角为原点。
    var frame: CGRect

    /// 框底部动作栏连同上方 1 pt 分隔线的高度；动作栏不填底色。为 0 时整个框都填底色。
    var footerHeight: CGFloat = 0
}

// MARK: - HeaderMaterialView

/// 头部材质视图：坐标自上而下，与 SwiftUI 量出的位置一致。
final class HeaderMaterialView: NSVisualEffectView {
    /// 各输入框；少了的输入框随之移除。
    var fields: [HeaderMaterialField] = [] {
        didSet {
            guard fields != oldValue else {
                return
            }

            needsLayout = true
        }
    }

    /// 底边的分隔线；没有时为 nil。
    private var separator: HeaderMaterialLayer?

    /// 已经放进材质的输入框图层，每个输入框一组，与 `fields` 依次对应。
    private var fieldLayers: [[HeaderMaterialLayer]] = []

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
    /// 一个输入框各块图层的位置，与 `makeLayers(hasFooter:)` 的顺序对应。
    private static func layerFrames(of field: HeaderMaterialField) -> [CGRect] {
        let frame = field.frame

        guard field.footerHeight > 0 else {
            return [frame]
        }

        // 底色与分隔线收在 1 pt 描边以内，不与描边叠在一起
        let dividerY = frame.maxY - field.footerHeight

        return [
            frame,
            CGRect(
                x: frame.minX + 1,
                y: frame.minY + 1,
                width: frame.width - 2,
                height: dividerY - frame.minY - 1
            ),
            CGRect(x: frame.minX + 1, y: dividerY, width: frame.width - 2, height: 1),
        ]
    }

    /// 按位置放上、挪动或移除输入框。
    ///
    /// 没有动作栏的输入框是一块图层：底色取 `text_view_background_color`，1 pt `separatorColor` 描边，圆角 5。
    /// 带动作栏的输入框分成只描边的外框、填在输入区的底色与两区之间的分隔线三块：
    /// 分隔线与描边一样直接落在材质上，合成出的颜色相同；动作栏不填底色。
    private func placeFields() {
        // 输入框少了时移除多出来的几组
        while fieldLayers.count > fields.count {
            for layer in fieldLayers.removeLast() {
                layer.removeFromSuperview()
            }
        }

        for (index, field) in fields.enumerated() {
            let frames = Self.layerFrames(of: field)

            // 新出现的输入框补上一组图层，有无动作栏变了时换一组
            if index == fieldLayers.count {
                fieldLayers.append(makeLayers(hasFooter: field.footerHeight > 0))
            } else if fieldLayers[index].count != frames.count {
                for layer in fieldLayers[index] {
                    layer.removeFromSuperview()
                }

                fieldLayers[index] = makeLayers(hasFooter: field.footerHeight > 0)
            }

            for (layer, frame) in zip(fieldLayers[index], frames) {
                layer.frame = frame
            }
        }
    }

    /// 建一组输入框图层并放进材质；带动作栏时依次是外框、输入区的底色与分隔线。
    private func makeLayers(hasFooter: Bool) -> [HeaderMaterialLayer] {
        let fill = AppPalette.nsColor("text_view_background_color")

        let layers = hasFooter
            ? [
                HeaderMaterialLayer(fill: .clear, border: .separatorColor, cornerRadius: 5),
                HeaderMaterialLayer(
                    fill: fill,
                    cornerRadius: 4,
                    corners: [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                ),
                HeaderMaterialLayer(fill: .separatorColor),
            ]
            : [HeaderMaterialLayer(fill: fill, border: .separatorColor, cornerRadius: 5)]

        for layer in layers {
            addSubview(layer)
        }

        return layers
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
    ///   - corners: 取圆角的角；图层不翻转，上方两个角是 `MaxY` 一侧。
    init(
        fill: NSColor,
        border: NSColor? = nil,
        cornerRadius: CGFloat = 0,
        corners: CACornerMask = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner,
        ]
    ) {
        self.fill = fill
        self.border = border
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.maskedCorners = corners
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
