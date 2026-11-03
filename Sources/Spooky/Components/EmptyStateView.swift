import AppKit
import SwiftUI

// MARK: - EmptyStateView

/// 通用空状态：图标、18 pt 标题、说明与按钮行自上而下相隔 8，铺满容器，背景是 `contentBackground` 材质。
///
/// 整块以标题定位，标题的中心比容器中心低 32；图标、说明与按钮行都可以没有，没有的不占位置。
/// 按钮行由空状态排成一行，调用处只给出里面的控件。
struct EmptyStateView<Actions: View>: View {
    /// 本地化后的标题。
    let title: String

    /// 本地化后的说明；为空时没有说明这一行。
    let message: String

    /// 系统符号名称；为 nil 时没有图标。
    let symbol: String?

    /// 按钮行里的控件；为 nil 时没有按钮行。
    private let actions: Actions?

    /// 标题、说明与按钮行在宽度内居中，标题的中心对齐比容器中心低 32 的位置。
    var body: some View {
        VStack(spacing: 8) {
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

            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let actions {
                HStack(spacing: 8) {
                    actions
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: Alignment(horizontal: .center, vertical: .emptyStateTitle)
        )
        .background(ContentBackgroundView())
    }

    /// 带按钮行的空状态。
    ///
    /// - Parameters:
    ///   - title: 本地化后的标题。
    ///   - message: 本地化后的说明；为空时没有说明这一行。
    ///   - symbol: 系统符号名称；为 nil 时没有图标。
    ///   - actions: 按钮行里的控件，由空状态排成一行。
    init(
        title: String,
        message: String,
        symbol: String?,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.symbol = symbol
        self.actions = actions()
    }
}

// MARK: - Convenience

extension EmptyStateView where Actions == EmptyView {
    /// 没有按钮行的空状态。
    ///
    /// - Parameters:
    ///   - title: 本地化后的标题。
    ///   - message: 本地化后的说明；为空时没有说明这一行。
    ///   - symbol: 系统符号名称；为 nil 时没有图标。
    init(title: String, message: String, symbol: String?) {
        self.title = title
        self.message = message
        self.symbol = symbol
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
