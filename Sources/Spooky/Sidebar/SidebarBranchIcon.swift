import SwiftUI

// MARK: - SidebarBranchIcon

/// 侧边栏分支行的图标：本地与远端分支是三个圆环连成的分叉，已归档的分支是归档盒；
/// 分支已在别的工作树签出时，图形缩到左上，右下角加一枚挖出两个小方块的实心圆角标。颜色随所在的行。
struct SidebarBranchIcon: View {
    /// 分支的种类。
    enum Kind {
        /// 本地分支。
        case branch

        /// 已归档的本地分支。
        case archived

        /// 远端分支。
        case remoteBranch
    }

    /// 分支的种类。
    let kind: Kind

    /// 分支已在别的工作树签出。
    var isCheckedOutElsewhere = false

    /// 侧边栏条目行的档位，决定图标的边长。
    @Environment(\.sidebarRowSize)
    private var rowSize

    /// 图标的边长：小档 13、中档 16、大档 18 pt。
    private var side: CGFloat {
        switch rowSize {
        case .small: 13
        case .medium: 16
        case .large: 18
        @unknown default: 16
        }
    }

    /// 图标；不带角标的已归档分支用系统符号，其余自行绘制。带角标的图标边长放大到 1.25 倍，图形本身的大小不变。
    var body: some View {
        switch (kind, isCheckedOutElsewhere) {
        case (.archived, false):
            Image(systemName: "archivebox")

        case (.archived, true):
            BranchGlyph(isArchived: true, hasWorktreeBadge: true).frame(width: side * 1.25, height: side * 1.25)

        case (.branch, true):
            BranchGlyph(isArchived: false, hasWorktreeBadge: true).frame(width: side * 1.25, height: side * 1.25)

        case (.branch, false), (.remoteBranch, _):
            BranchShape().frame(width: side, height: side)
        }
    }
}

// MARK: - BranchGlyph

/// 带角标的分支图形，按 18 × 18 的网格描出，随所在的矩形等比缩放：分叉或带盖的归档盒缩到左上，
/// 右下角是挖出两个并排小方块的实心圆，图形在角标四周让出一圈空隙。
private struct BranchGlyph: Shape {
    /// 画归档盒；否则画分叉。
    let isArchived: Bool

    /// 右下角带 “已在别的工作树签出” 的角标。
    let hasWorktreeBadge: Bool

    /// 描出整个图标的填充轮廓。
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)

        guard hasWorktreeBadge else {
            return outline(in: square)
        }

        return SymbolBadge.outline(in: square, glyph: outline(in:)) { center, side in
            // 左右两个小方块，各宽 0.13，中间隔 0.06
            var squares = Path()

            for offset in [-0.16, 0.03] {
                squares.addRoundedRect(
                    in: CGRect(
                        x: center.x + side * offset,
                        y: center.y - side * 0.065,
                        width: side * 0.13,
                        height: side * 0.13
                    ),
                    cornerSize: CGSize(width: side * 0.03, height: side * 0.03)
                )
            }

            return squares
        }
    }

    /// 不带角标的图形在给定正方形里的填充轮廓。
    private func outline(in square: CGRect) -> Path {
        guard isArchived else {
            return BranchShape.outline(in: square)
        }

        let unit = square.width / 18

        // 网格坐标换成正方形里的点
        let point = { (x: Double, y: Double) in
            CGPoint(x: square.minX + x * unit, y: square.minY + y * unit)
        }

        var path = Path()

        // 盒盖
        path.addRoundedRect(
            in: CGRect(origin: point(2, 3.2), size: CGSize(width: 14 * unit, height: 3.4 * unit)),
            cornerSize: CGSize(width: unit, height: unit)
        )

        // 盒身
        path.move(to: point(3.4, 6.6))
        path.addLine(to: point(3.4, 13))
        path.addQuadCurve(to: point(5, 14.6), control: point(3.4, 14.6))
        path.addLine(to: point(13, 14.6))
        path.addQuadCurve(to: point(14.6, 13), control: point(14.6, 14.6))
        path.addLine(to: point(14.6, 6.6))

        // 把手
        path.move(to: point(7, 9.6))
        path.addLine(to: point(11, 9.6))

        return path.strokedPath(StrokeStyle(lineWidth: 1.5 * unit, lineCap: .round, lineJoin: .round))
    }
}
