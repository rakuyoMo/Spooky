import AppKit
import SwiftUI

// MARK: - AppSymbol

/// 按名字取用的符号：系统符号之外，Spooky 自绘的图形也各有一个名字，界面各处用同一种方式取图。
enum AppSymbol {
    /// 自绘的分支图形。
    static let branch = "spooky.branch"

    /// AppKit 用的符号图：系统符号原样取出，大小由调用处的符号配置决定；自绘的图形画成给定边长的模板图。
    ///
    /// - Parameters:
    ///   - name: 符号的名字。
    ///   - side: 自绘图形所在模板图的边长，单位是 pt。
    ///   - inset: 图形四周的留白；工具栏会把图片放大到填满图标位，留白让它与旁边的系统符号一样大。
    ///   - accessibilityDescription: 辅助功能的说明。
    @MainActor
    static func image(
        _ name: String,
        side: CGFloat,
        inset: CGFloat = 0,
        accessibilityDescription: String?
    ) -> NSImage? {
        guard name == branch else {
            return NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
        }

        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            context.addPath(BranchShape.outline(in: rect.insetBy(dx: inset, dy: inset)).cgPath)
            context.fillPath()

            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription

        return image
    }
}

// MARK: - AppSymbolImage

/// SwiftUI 用的符号图，大小随字体：自绘的图形铺在一个隐藏的方形系统符号上，取它在当前字体下的大小。
struct AppSymbolImage: View {
    /// 符号的名字。
    let name: String

    /// 系统符号或自绘的图形，颜色随前景样式。
    var body: some View {
        if name == AppSymbol.branch {
            Image(systemName: "square")
                .hidden()
                .overlay { BranchShape() }
        } else {
            Image(systemName: name)
        }
    }
}

// MARK: - BranchShape

/// 分支的图形：左侧一根竖直的主干连着上下两个圆环，右上的圆环经一段圆角折线斜着并入主干。
///
/// 按 18 × 18 的网格描出，在所在的矩形里居中、等比缩放。
struct BranchShape: Shape {
    /// 图形在给定正方形里的填充轮廓。
    static func outline(in square: CGRect) -> Path {
        let unit = square.width / 18
        let radius = 2.4

        // 网格坐标换成正方形里的点
        let point = { (x: Double, y: Double) in
            CGPoint(x: square.minX + x * unit, y: square.minY + y * unit)
        }

        var path = Path()

        // 左上、右上与左下三个圆环
        for center in [point(4.6, 3.9), point(13.4, 3.9), point(4.6, 14.1)] {
            path.addEllipse(in: CGRect(origin: center, size: .zero).insetBy(dx: -radius * unit, dy: -radius * unit))
        }

        // 主干
        path.move(to: point(4.6, 3.9 + radius))
        path.addLine(to: point(4.6, 14.1 - radius))

        // 右上的圆环向下，拐过圆角后斜着并入主干
        path.move(to: point(13.4, 3.9 + radius))
        path.addLine(to: point(13.4, 7))
        path.addQuadCurve(to: point(12.1, 8.6), control: point(13.4, 8.1))
        path.addLine(to: point(4.6, 11.2))

        return path.strokedPath(StrokeStyle(lineWidth: 1.5 * unit, lineCap: .round, lineJoin: .round))
    }

    /// 图形在矩形里居中的最大正方形内描出。
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        return Self.outline(in: CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side))
    }
}
