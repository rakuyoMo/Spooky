import AppKit
import SwiftUI

// MARK: - EmptyStateView

/// 通用空状态：图标、18 pt 标题、说明与按钮行自上而下相隔 8，铺满容器，背景是 `contentBackground` 材质。
///
/// 整块以标题定位，标题的中心比容器中心低 32；容器包括窗口工具栏下面的那一段。
/// 图标与按钮行可以没有，没有的不占位置；说明为空时仍留出一行的高度。
/// 按钮行由空状态排成一行，调用处只给出里面的控件，按钮用 `EmptyStateButton`。
struct EmptyStateView<Actions: View>: View {
    /// 本地化后的标题。
    let title: String

    /// 本地化后的说明；为空时这一行留空。
    let message: String

    /// 系统符号名称；为 nil 时没有图标。
    let symbol: String?

    /// 内联内容按实际文字和按钮确定高度，整页空状态仍铺满容器。
    let fitsContent: Bool

    /// 按钮行里的控件；为 nil 时没有按钮行。
    private let actions: Actions?

    /// 标题、说明与按钮行在宽度内居中，标题的中心对齐比容器中心低 32 的位置；
    /// 整块与背景延伸到窗口工具栏下面，容器的中心按延伸后的高度算。
    var body: some View {
        if fitsContent {
            EmptyStateInlineLayout(hasSymbol: symbol != nil) {
                content
            }
            .background(ContentBackgroundView())
        } else {
            VStack(spacing: 8) {
                content
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: Alignment(horizontal: .center, vertical: .emptyStateTitle)
            )
            .background(ContentBackgroundView())
            .ignoresSafeArea(.container, edges: .top)
        }
    }

    /// 两种容器共用标题、说明、按钮与原有文本样式。
    @ViewBuilder
    private var content: some View {
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: 58, weight: .light))
                .frame(width: 128, height: 100)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }

        // 容器的中心对齐到标题中心以上 32 处，标题因此比容器中心低 32
        Text(title)
            .font(.system(size: 18))
            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .alignmentGuide(.emptyStateTitle) { $0[VerticalAlignment.center] - 32 }

        // 说明为空时同样占一行，按钮行与标题之间隔着这一行
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .accessibilityHidden(message.isEmpty)

        if let actions {
            HStack(spacing: 8) {
                actions
            }
            .padding(.horizontal, 20)
            .padding(.bottom, fitsContent ? EmptyStateButton.bottomOutset : 0)
        }
    }

    /// 带按钮行的空状态。
    ///
    /// - Parameters:
    ///   - title: 本地化后的标题。
    ///   - message: 本地化后的说明；为空时这一行留空。
    ///   - symbol: 系统符号名称；为 nil 时没有图标。
    ///   - fitsContent: 内联模式按内容自动增加高度，不延伸到工具栏区域。
    ///   - actions: 按钮行里的控件，由空状态排成一行；按钮用 `EmptyStateButton`。
    init(
        title: String,
        message: String,
        symbol: String?,
        fitsContent: Bool = false,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.symbol = symbol
        self.fitsContent = fitsContent
        self.actions = actions()
    }
}

// MARK: - Convenience

extension EmptyStateView where Actions == EmptyView {
    /// 没有按钮行的空状态。
    ///
    /// - Parameters:
    ///   - title: 本地化后的标题。
    ///   - message: 本地化后的说明；为空时这一行留空。
    ///   - symbol: 系统符号名称；为 nil 时没有图标。
    init(title: String, message: String, symbol: String?) {
        self.title = title
        self.message = message
        self.symbol = symbol
        fitsContent = false
        actions = nil
    }
}

// MARK: - Alignment

extension VerticalAlignment {
    /// 空状态在容器里定位用的标题位置，默认是视图的垂直中心。
    private enum EmptyStateTitle: AlignmentID {
        /// 没有另外指定时取垂直中心；容器取到的就是它自己的中心。
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    /// 空状态在容器里定位用的标题位置。
    fileprivate static let emptyStateTitle = VerticalAlignment(EmptyStateTitle.self)
}

// MARK: - EmptyStateButton

/// 空状态按钮行里的按钮：工具栏样式的边框，标题是次要标签色。
struct EmptyStateButton: NSViewRepresentable {
    /// 原生按钮的可见边框超出 SwiftUI 使用的对齐矩形，内联容器要给底边留出这段高度。
    static var bottomOutset: CGFloat {
        let button = NSButton(title: "", target: nil, action: nil)
        button.bezelStyle = .toolbar
        return max(0, button.alignmentRectInsets.bottom)
    }

    /// 本地化后的标题。
    let title: String

    /// 按下按钮时的动作。
    let action: () -> Void

    /// 建立空状态按钮。
    ///
    /// - Parameters:
    ///   - title: 本地化后的标题。
    ///   - action: 按下按钮时的动作。
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    /// 转发按钮动作的目标。
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    /// 工具栏样式、按标题定宽的按钮。
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "", target: context.coordinator, action: #selector(Coordinator.press))
        button.bezelStyle = .toolbar
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    /// 同步标题、动作与可用状态；可用状态取 SwiftUI 的 `disabled`。
    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        button.isEnabled = context.environment.isEnabled

        // 标题写成次要标签色、居中，字体取按钮自己的
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .paragraphStyle: paragraph,
            ]
        )
    }
}

// MARK: EmptyStateButton.Coordinator

extension EmptyStateButton {
    /// 按钮的目标，按下时执行最新的动作。
    final class Coordinator: NSObject {
        /// 按下按钮时的动作。
        var action: () -> Void

        /// 记下动作。
        ///
        /// - Parameter action: 按下按钮时的动作。
        init(action: @escaping () -> Void) {
            self.action = action
        }

        /// 执行动作。
        @objc
        func press() {
            action()
        }
    }
}

// MARK: - ContentBackgroundView

/// 空状态铺满容器的 `contentBackground` 材质。
private struct ContentBackgroundView: NSViewRepresentable {
    /// 只设材质，混合方式与状态取系统默认。
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .contentBackground
        return view
    }

    /// 材质固定，不随更新变化。
    func updateNSView(_: NSVisualEffectView, context _: Context) { }
}
