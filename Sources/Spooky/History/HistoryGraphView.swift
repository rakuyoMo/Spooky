import AppKit
import SpookyKit
import SwiftUI

// MARK: - HistoryGraphView

/// 每行一个原生画布，线段跨行拼接，点击穿透给列表。
///
/// 提交行画出本行的线段与圆点；日期分组行只画从上一行穿到下一行的竖线。
struct HistoryGraphView: NSViewRepresentable {
    /// 10 pt 列距、2 pt 线宽与 7 pt 圆点的原生绘制。
    final class GraphCanvas: NSView {
        /// 提交行的模型；分组行为 nil。
        var row: CommitGraphRow?

        /// 分组行穿过的线：取下一个提交上沿进入的线段，按它们的上沿列画竖线。
        var passing: [CommitGraphSegment] = []

        /// 上沿接上一提交，采用从上向下的坐标系。
        override var isFlipped: Bool { true }

        /// 图不接管点击，列表保留选择和双击语义。
        override func hitTest(_: NSPoint) -> NSView? { nil }

        /// 线段换列时在中间三分之一使用贝塞尔过渡。
        override func draw(_: NSRect) {
            for segment in passing {
                let x = CGFloat(segment.start) * 10 + 7
                let path = NSBezierPath()
                path.lineWidth = 2
                path.move(to: NSPoint(x: x, y: 0))
                path.line(to: NSPoint(x: x, y: bounds.height))
                Self.color(of: segment).setStroke()
                path.stroke()
            }

            guard let row else { return }

            for segment in row.segments {
                let start = NSPoint(
                    x: CGFloat(segment.start) * 10 + 7,
                    y: segment.startsAtCommit ? bounds.midY : 0
                )
                let end = NSPoint(
                    x: CGFloat(segment.end) * 10 + 7,
                    y: segment.endsAtCommit ? bounds.midY : bounds.height
                )
                let distance = (end.y - start.y) / 3
                let path = NSBezierPath()
                path.lineWidth = 2
                path.move(to: start)
                path.line(to: NSPoint(x: start.x, y: start.y + distance))
                path.curve(
                    to: NSPoint(x: end.x, y: end.y - distance),
                    controlPoint1: NSPoint(x: start.x, y: start.y + distance * 1.5),
                    controlPoint2: NSPoint(x: end.x, y: end.y - distance * 1.5)
                )
                path.line(to: end)
                Self.color(of: segment).setStroke()
                path.stroke()
            }

            // 圆点最后覆盖连接线，外圈厚度为 1.5 pt。
            let dot = NSBezierPath(
                ovalIn: NSRect(x: CGFloat(row.column) * 10 + 3.5, y: bounds.midY - 3.5, width: 7, height: 7)
            )
            dot.lineWidth = 3
            AppPalette.nsColor("repository_history_commit_bubble_border_color").setStroke()
            dot.stroke()
            AppPalette.nsColor("repository_history_commit_bubble_bg_color").setFill()
            dot.fill()
        }

        /// 十条泳道颜色按命名色循环，深浅外观由命名色自动切换。
        private static func color(of segment: CommitGraphSegment) -> NSColor {
            let names = ["gray", "blue", "pink", "green", "yellow", "orange", "indigo", "red", "teal", "purple"]
            return AppPalette.nsColor(names[segment.line % 10] + "_history_graph_line_color")
        }
    }

    /// 提交行的模型；分组行为 nil。
    let row: CommitGraphRow?

    /// 分组行穿过的线。
    let passing: [CommitGraphSegment]

    /// 画布宽度：提交行按本行的列数，分组行按穿过的最右一列。
    var width: CGFloat {
        let columns = row?.columnCount ?? (passing.map(\.start).max().map { $0 + 1 } ?? 0)
        return CGFloat(columns) * 10 + 7
    }

    /// 提交行的图。
    init(row: CommitGraphRow) {
        self.row = row
        passing = []
    }

    /// 分组行的竖线，取下一个提交上沿进入的线段。
    init(passingInto next: CommitGraphRow?) {
        row = nil
        passing = next?.segments.filter { !$0.startsAtCommit } ?? []
    }

    /// 建立轻量画布。
    func makeNSView(context _: Context) -> GraphCanvas { GraphCanvas() }

    /// 分页只更新对应行的几何模型。
    func updateNSView(_ view: GraphCanvas, context _: Context) {
        view.row = row
        view.passing = passing
        view.needsDisplay = true
    }
}

// MARK: - HistoryGroupRow

/// 按日期分组时一组的标题行：图照常画穿过的线，标题全大写、11 pt 次要色、垂直居中。
struct HistoryGroupRow: View {
    /// 穿过本行的提交图；不显示提交图时为 nil。
    let graph: HistoryGraphView?

    /// 组的标题。
    let title: String

    /// 图在最左侧，标题距图 8 pt。
    var body: some View {
        HStack(spacing: 8) {
            if let graph {
                graph
                    .frame(width: graph.width)
                    .accessibilityHidden(true)
            }

            Text(title.uppercased())
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
