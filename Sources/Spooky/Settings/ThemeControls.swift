import AppKit
import SwiftUI

// MARK: - ThemeColorWell

/// 主题颜色的色板：点开系统颜色面板编辑，可以调不透明度；内置主题只读时禁用。
struct ThemeColorWell: NSViewRepresentable {
    /// 色板动作的接收方，持有最新的写回闭包。
    @MainActor
    final class Coordinator: NSObject {
        /// 把面板选出的颜色写回主题。
        var change: (PaletteColor) -> Void

        /// 建立写回闭包。
        init(_ change: @escaping (PaletteColor) -> Void) { self.change = change }

        /// 颜色面板里每次调色都会送来；无法换算到 sRGB 的颜色不写回。
        @objc
        func colorChanged(_ sender: NSColorWell) {
            guard let color = PaletteColor(nsColor: sender.color) else {
                return
            }

            change(color)
        }
    }

    /// 当前颜色；主题缺少这个颜色时为 nil。
    let color: PaletteColor?

    /// 是否允许编辑。
    let isEnabled: Bool

    /// 色板的读屏名称。
    let label: String

    /// 用户选出新颜色。
    let change: (PaletteColor) -> Void

    /// 建立动作接收方。
    func makeCoordinator() -> Coordinator { Coordinator(change) }

    /// 带边框的系统色板，打开的颜色面板显示不透明度。
    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell(style: .default)
        well.supportsAlpha = true
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        return well
    }

    /// 同步颜色、可用状态与读屏名称。
    func updateNSView(_ well: NSColorWell, context: Context) {
        context.coordinator.change = change
        well.setAccessibilityLabel(label)

        // 禁用前先断开颜色面板，面板里的后续改动不能落到只读主题上。
        if !isEnabled, well.isActive {
            well.deactivate()
        }

        well.isEnabled = isEnabled

        // 程序设置颜色不会触发动作；只在值不同时设置，避免打断面板里的拖动。
        if let color, PaletteColor(nsColor: well.color) != color {
            well.color = color.nsColor
        }
    }

    /// 色板按外层给出的尺寸绘制。
    func sizeThatFits(_ proposal: ProposedViewSize, nsView _: NSColorWell, context _: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 44, height: 24))
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
