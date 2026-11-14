import SwiftUI

// MARK: - ConflictArrows

/// 两张卡片汇入结果框的箭头：粗的空心弯箭头，从卡片底部中线向下弯入结果框；对应的卡片选中时轮廓变蓝。
struct ConflictArrows: View {
    /// 选中的卡片。
    let selection: Set<ConflictSide>

    /// 两条箭头的起点在两张卡片的中线，终点在结果框中央两侧各 50 pt。
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                arrow(
                    from: CGPoint(x: size.width * 0.25, y: 0),
                    to: CGPoint(x: size.width / 2 - 50, y: size.height),
                    isSelected: selection.contains(.ours)
                )

                arrow(
                    from: CGPoint(x: size.width * 0.75, y: 0),
                    to: CGPoint(x: size.width / 2 + 50, y: size.height),
                    isSelected: selection.contains(.theirs)
                )
            }
        }
        .accessibilityHidden(true)
    }

    /// 一条空心箭头的轮廓：竖直出发、竖直落下的弯曲箭身，末端是三角形的箭头。
    ///
    /// - Parameters:
    ///   - start: 箭身的起点。
    ///   - tip: 箭头尖端。
    static func outline(from start: CGPoint, to tip: CGPoint) -> Path {
        let headLength: CGFloat = 18
        let headWidth: CGFloat = 30
        let neck = CGPoint(x: tip.x, y: tip.y - headLength)

        // 箭身沿中线描成 12 pt 宽的轮廓，多伸进箭头 1 pt，合并时不留缝
        var center = Path()
        center.move(to: start)
        center.addCurve(
            to: CGPoint(x: neck.x, y: neck.y + 1),
            control1: CGPoint(x: start.x, y: (start.y + neck.y) / 2),
            control2: CGPoint(x: neck.x, y: (start.y + neck.y) / 2)
        )

        let shaft = center.strokedPath(StrokeStyle(lineWidth: 12, lineCap: .butt))

        var head = Path()
        head.move(to: CGPoint(x: neck.x - headWidth / 2, y: neck.y))
        head.addLine(to: CGPoint(x: neck.x + headWidth / 2, y: neck.y))
        head.addLine(to: tip)
        head.closeSubpath()

        return shaft.union(head)
    }

    /// 一条箭头：只描轮廓，选中时用强调色。
    private func arrow(from start: CGPoint, to tip: CGPoint, isSelected: Bool) -> some View {
        Self.outline(from: start, to: tip)
            .stroke(
                isSelected ? Color.accentColor : Color(nsColor: .tertiaryLabelColor),
                style: StrokeStyle(lineWidth: isSelected ? 2 : 1.5, lineJoin: .round)
            )
    }
}
