import SwiftUI

/// 左右控件保留固有宽度，摘要始终对齐整栏中心，并优先让出空间。
struct DiffBottomBarLayout: Layout {
    /// 按两侧较大的占宽留对称空间，摘要与任一侧至少相隔 8 pt。
    static func frames(width: CGFloat, sizes: [CGSize]) -> [CGRect] {
        guard sizes.count == 3 else { return [] }

        let side = max(sizes[0].width + 8, sizes[2].width + 10)
        let summaryWidth = min(sizes[1].width, max(0, width - 2 * (side + 8)))
        return [
            CGRect(x: 8, y: (32 - sizes[0].height) / 2, width: sizes[0].width, height: sizes[0].height),
            CGRect(
                x: (width - summaryWidth) / 2,
                y: (32 - sizes[1].height) / 2,
                width: summaryWidth,
                height: sizes[1].height
            ),
            CGRect(
                x: width - 10 - sizes[2].width,
                y: (32 - sizes[2].height) / 2,
                width: sizes[2].width,
                height: sizes[2].height
            ),
        ]
    }

    /// 底栏固定 32 pt 高；未指定宽度时按两侧控件及摘要的理想宽度确定。
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = proposal.width ?? sizes.reduce(34) { $0 + $1.width }
        return CGSize(width: width, height: 32)
    }

    /// 三组分别放置，刷新或长译文不会推动摘要的中心。
    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let frames = Self.frames(width: bounds.width, sizes: sizes)

        for (index, frame) in frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

}
