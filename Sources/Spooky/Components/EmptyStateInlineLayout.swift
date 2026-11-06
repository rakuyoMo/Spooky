import SwiftUI

/// 内联空状态按实际子视图量高，保留标题中心低于容器中心 32 pt 的定位。
struct EmptyStateInlineLayout: Layout {
    /// 图标存在时，标题是第二个子视图。
    let hasSymbol: Bool

    /// 上下两侧所需半高分别计算，标题以下的空说明行与按钮都计入。
    static func height(sizes: [CGSize], titleIndex: Int) -> CGFloat {
        guard sizes.indices.contains(titleIndex) else { return 0 }

        let halfTitle = sizes[titleIndex].height / 2
        let above = sizes.prefix(titleIndex).reduce(halfTitle) { $0 + $1.height + 8 }
        let below = sizes.dropFirst(titleIndex + 1).reduce(halfTitle) { $0 + $1.height + 8 }
        return ceil(2 * max(above - 32, below + 32))
    }

    /// 文字在给定宽度内自然换行，底部按钮必须完整落在自己的边界内。
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
        return CGSize(width: width, height: Self.height(sizes: sizes, titleIndex: hasSymbol ? 1 : 0))
    }

    /// 标题先定位，其余子视图沿 8 pt 间距向上下排列。
    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)) }
        let titleIndex = hasSymbol ? 1 : 0
        guard sizes.indices.contains(titleIndex) else { return }

        let before = sizes.prefix(titleIndex).reduce(CGFloat(0)) { $0 + $1.height + 8 }
        var y = bounds.midY + 32 - sizes[titleIndex].height / 2 - before

        for (index, size) in sizes.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.midX - size.width / 2, y: y),
                proposal: ProposedViewSize(size)
            )
            y += size.height + 8
        }
    }

}
