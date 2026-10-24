import AppKit
import SwiftUI

// MARK: - ThemeColorWell

/// 主题颜色的方形色块：点开系统颜色面板编辑这一种颜色，可以调不透明度。
///
/// 颜色面板正在编辑这个色块时，描边加粗并换成强调色。
struct ThemeColorWell: View {
    /// 当前颜色；主题缺少这个颜色时为 nil。
    let color: PaletteColor?

    /// 颜色键，颜色面板据此认出正在编辑的色块。
    let key: String

    /// 是否允许编辑。
    let isEnabled: Bool

    /// 色块的读屏名称。
    let label: String

    /// 用户在颜色面板里调出新颜色。
    let change: (PaletteColor) -> Void

    /// 共用的颜色面板接收方，它记着正在编辑哪个色块。
    private let picker = ThemeColorPicker.shared

    /// 填满颜色的方块与 1 pt 描边；正在编辑时描边为 2 pt 强调色。
    var body: some View {
        #warning("TODO: 打开 Themes 页并点开一个色块，核实色块的描边颜色与宽度、正在编辑时的选中样式和禁用时的样子；只影响 Themes 页的四个色块。")

        let isActive = picker.key == key

        Button {
            guard let color else {
                return
            }

            picker.show(color, key: key, apply: change)
        } label: {
            GeometryReader { proxy in
                Image(nsImage: Self.swatch(color, size: proxy.size))
            }
            .overlay {
                Rectangle().strokeBorder(
                    isActive ? Color.accentColor : AppPalette.color("general_border_color"),
                    lineWidth: isActive ? 2 : 1
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityValue(color?.hex ?? "")
    }

    /// 用系统的色块画法画出颜色：半透明的颜色沿对角线分别铺在黑底与白底上，不透明度一眼可见。
    private static func swatch(_ color: PaletteColor?, size: CGSize) -> NSImage {
        let fill = color?.nsColor

        return NSImage(size: size, flipped: false) { rect in
            fill?.drawSwatch(in: rect)
            return true
        }
    }
}

// MARK: - ThemeColorPicker

/// 系统颜色面板的接收方：把面板里调出的颜色写回正在编辑的那一种主题颜色。
///
/// 编辑期间颜色面板的目标指向这里；结束或面板关闭后清掉目标，色块回到未选中的样子。
@MainActor
@Observable
final class ThemeColorPicker: NSObject {
    /// 设置窗口只有一个 Themes 页，共用同一个接收方。
    static let shared = ThemeColorPicker()

    /// 正在编辑的颜色键；nil 表示没有在编辑。
    private(set) var key: String?

    /// 把面板调出的颜色写回主题。
    @ObservationIgnored
    private var apply: ((PaletteColor) -> Void)?

    /// 颜色面板关闭的通知。
    @ObservationIgnored
    private var closeObserver: NSObjectProtocol?

    /// 监听颜色面板关闭：用户直接关掉面板时同样结束编辑。
    override private init() {
        super.init()

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: NSColorPanel.shared,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
    }

    /// 打开颜色面板编辑一种颜色：面板显示不透明度，拖动时连续写回。
    ///
    /// - Parameters:
    ///   - color: 这种颜色当前的值。
    ///   - key: 颜色键。
    ///   - apply: 面板每次改动后写回主题。
    func show(_ color: PaletteColor, key: String, apply: @escaping (PaletteColor) -> Void) {
        let panel = NSColorPanel.shared

        // 先断开目标再换颜色：换到另一个色块时，面板显示的新颜色不能写回上一个色块。
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.color = color.nsColor

        self.key = key
        self.apply = apply

        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.orderFront(nil)
    }

    /// 结束编辑并关闭颜色面板。
    func stop() {
        guard key != nil else {
            return
        }

        finish()
        NSColorPanel.shared.orderOut(nil)
    }

    /// 颜色面板里每次调色都会送来；无法换算到 sRGB 的颜色不写回。
    @objc
    private func colorChanged(_ sender: NSColorPanel) {
        guard let apply, let color = PaletteColor(nsColor: sender.color) else {
            return
        }

        apply(color)
    }

    /// 清掉编辑状态，颜色面板不再向这里发送改动。
    private func finish() {
        key = nil
        apply = nil

        NSColorPanel.shared.setTarget(nil)
        NSColorPanel.shared.setAction(nil)
    }
}

// MARK: - ThemeFontPicker

/// 系统字体面板的接收方：把面板里选出的字体写回正在编辑的主题。
///
/// 编辑期间字体管理器的目标指向这里；结束或面板关闭后交还响应链，不影响其它文本视图。
@MainActor
final class ThemeFontPicker: NSObject, NSFontChanging {
    /// 设置窗口只有一个 Themes 页，共用同一个接收方。
    static let shared = ThemeFontPicker()

    /// 面板换算新字体时依据的当前字体。
    private var font: NSFont?

    /// 写回主题；nil 表示没有在编辑。
    private var apply: ((NSFont) -> Void)?

    /// 字体面板关闭的通知。
    private var closeObserver: NSObjectProtocol?

    /// 是否正在为某个主题编辑字体。
    var isEditing: Bool { apply != nil }

    /// 监听字体面板关闭：用户直接关掉面板时同样结束编辑。
    override private init() {
        super.init()

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: NSFontPanel.shared,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
    }

    /// 打开字体面板，从主题当前的字体开始编辑。
    ///
    /// - Parameters:
    ///   - font: 主题当前的字体。
    ///   - apply: 面板每次改动后写回主题。
    func show(_ font: NSFont, apply: @escaping (NSFont) -> Void) {
        self.font = font
        self.apply = apply

        let manager = NSFontManager.shared
        manager.target = self
        manager.setSelectedFont(font, isMultiple: false)
        manager.orderFrontFontPanel(self)
    }

    /// 结束编辑并关闭字体面板。
    func stop() {
        guard isEditing else {
            return
        }

        finish()
        NSFontPanel.shared.orderOut(nil)
    }

    /// 字体面板的改动：按面板的选择换算当前字体，再写回主题。
    func changeFont(_ sender: NSFontManager?) {
        guard let sender, let font, let apply else {
            return
        }

        let converted = sender.convert(font)
        self.font = converted
        apply(converted)
    }

    /// 主题只保存字体与字号，面板不显示颜色、下划线等效果。
    func validModesForFontPanel(_: NSFontPanel) -> NSFontPanel.ModeMask {
        [.collection, .face, .size]
    }

    /// 清掉编辑状态，字体面板的改动重新交给响应链。
    private func finish() {
        font = nil
        apply = nil

        if NSFontManager.shared.target === self {
            NSFontManager.shared.target = nil
        }
    }
}
