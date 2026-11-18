import AppKit
import SwiftUI

// MARK: - AppSymbol

/// 按名字取用的符号：系统符号之外，Spooky 自绘的图形也各有一个名字，界面各处用同一种方式取图。
///
/// 自绘的图形与分支图形是一套：按 18 × 18 的网格描出，线宽 1.5，圆环半径 2.4，作为模板图着色；名字都以 `spooky.` 开头。
enum AppSymbol {
    /// 自绘的分支图形。
    static let branch = "spooky.branch"

    /// 自绘的合并图形：一根竖线下端是圆环、上端是实心箭头，右下方另一根线向上拐过圆角并入竖线中段。
    static let merge = "spooky.merge"

    /// 自绘的变基图形：一根竖线下端是圆环、上端是实心箭头。
    static let rebase = "spooky.rebase"

    /// 自绘的新建分支图形：分叉缩到左上，右下角是挖出加号的实心圆角标。
    static let createBranch = "spooky.createBranch"

    /// 自绘的请求图形：左边一根两端带圆环的竖线；右边一根竖线下端是圆环，上端向左折成实心箭头，指向左边那根线的上端。
    static let pullRequest = "spooky.pullRequest"

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
        guard isDrawn(name) else {
            return NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
        }

        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
            guard
                let context = NSGraphicsContext.current?.cgContext,
                let outline = outline(name, in: rect.insetBy(dx: inset, dy: inset))
            else { return false }

            context.addPath(outline.cgPath)
            context.fillPath()

            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription

        return image
    }

    /// 是不是自绘的图形。
    static func isDrawn(_ name: String) -> Bool {
        name.hasPrefix("spooky.")
    }

    /// 自绘的图形在给定正方形里的填充轮廓；系统符号为 nil。
    ///
    /// - Parameters:
    ///   - name: 符号的名字。
    ///   - square: 图形所在的正方形。
    static func outline(_ name: String, in square: CGRect) -> Path? {
        switch name {
        case branch:
            BranchShape.outline(in: square)

        case merge:
            mergeOutline(in: SymbolGrid(square: square))

        case rebase:
            rebaseOutline(in: SymbolGrid(square: square))

        case createBranch:
            createBranchOutline(in: square)

        case pullRequest:
            pullRequestOutline(in: SymbolGrid(square: square))

        default:
            nil
        }
    }
}

// MARK: - Outlines

extension AppSymbol {
    /// 合并：主干偏左，右侧的线从底部升起，拐过圆角后斜着并入主干中段，下端不带圆环。
    private static func mergeOutline(in grid: SymbolGrid) -> Path {
        var lines = Path()

        // 主干：下端圆环的顶部到箭头的底边
        lines.move(to: grid.point(6.5, 11.7))
        lines.addLine(to: grid.point(6.5, 5.4))

        // 右侧的线向上，拐过圆角后斜着并入主干
        lines.move(to: grid.point(14.3, 16.5))
        lines.addLine(to: grid.point(14.3, 12.6))
        lines.addQuadCurve(to: grid.point(13, 11), control: grid.point(14.3, 11.5))
        lines.addLine(to: grid.point(6.5, 8.4))

        return grid.stroked(lines)
            .union(grid.ring(6.5, 14.1))
            .union(grid.arrowhead(tip: (6.5, 1.8), pointsLeft: false))
    }

    /// 变基：居中的一根竖线，下端圆环，上端实心箭头。
    private static func rebaseOutline(in grid: SymbolGrid) -> Path {
        var line = Path()
        line.move(to: grid.point(9, 11.7))
        line.addLine(to: grid.point(9, 5.4))

        return grid.stroked(line)
            .union(grid.ring(9, 14.1))
            .union(grid.arrowhead(tip: (9, 1.8), pointsLeft: false))
    }

    /// 新建分支：分叉缩到左上，右下角的实心圆角标里挖出加号；角标与 “已在别的工作树签出” 同一位置与大小。
    private static func createBranchOutline(in square: CGRect) -> Path {
        SymbolBadge.outline(in: square, glyph: BranchShape.outline(in:)) { center, side in
            // 横竖两条圆头短杠，长为边长的 0.3，粗与线宽相同
            let length = side * 0.3
            let thickness = side * 1.5 / 18
            let corner = CGSize(width: thickness / 2, height: thickness / 2)

            var plus = Path()

            plus.addRoundedRect(
                in: CGRect(x: center.x - length / 2, y: center.y - thickness / 2, width: length, height: thickness),
                cornerSize: corner
            )

            plus.addRoundedRect(
                in: CGRect(x: center.x - thickness / 2, y: center.y - length / 2, width: thickness, height: length),
                cornerSize: corner
            )

            return plus
        }
    }

    /// 请求：左边的竖线连着上下两个圆环；右边的竖线从下端圆环向上，拐过圆角向左，末端是指向左上圆环的实心箭头。
    private static func pullRequestOutline(in grid: SymbolGrid) -> Path {
        var lines = Path()

        // 左边两个圆环之间的竖线
        lines.move(to: grid.point(4.2, 6.6))
        lines.addLine(to: grid.point(4.2, 11.7))

        // 右边的竖线向上，拐过圆角后向左，终点藏在箭头里
        lines.move(to: grid.point(13.8, 11.7))
        lines.addLine(to: grid.point(13.8, 6.6))
        lines.addQuadCurve(to: grid.point(11.4, 4.2), control: grid.point(13.8, 4.2))

        return grid.stroked(lines)
            .union(grid.ring(4.2, 4.2))
            .union(grid.ring(4.2, 14.1))
            .union(grid.ring(13.8, 14.1))
            .union(grid.arrowhead(tip: (9.1, 4.2), pointsLeft: true))
    }
}

// MARK: - SymbolGrid

/// 自绘图形的 18 × 18 设计网格：网格坐标换成所在正方形里的点，按网格单位描出圆环、线条与箭头。
private struct SymbolGrid {
    /// 图形所在的正方形。
    let square: CGRect

    /// 一个网格单位的长度。
    private var unit: CGFloat { square.width / 18 }

    /// 网格坐标换成正方形里的点。
    func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: square.minX + x * unit, y: square.minY + y * unit)
    }

    /// 以网格坐标为圆心、半径 2.4 的圆环的填充轮廓。
    func ring(_ x: Double, _ y: Double) -> Path {
        var circle = Path()
        circle.addEllipse(in: CGRect(origin: point(x, y), size: .zero).insetBy(dx: -2.4 * unit, dy: -2.4 * unit))

        return stroked(circle)
    }

    /// 线条按线宽 1.5、圆头圆角描成的填充轮廓。
    func stroked(_ path: Path) -> Path {
        path.strokedPath(StrokeStyle(lineWidth: 1.5 * unit, lineCap: .round, lineJoin: .round))
    }

    /// 实心箭头：底边宽 5.6、高 3.6 的三角形，外面再描一圈线宽让三个角变圆。
    ///
    /// - Parameters:
    ///   - tip: 尖端的网格坐标。
    ///   - pointsLeft: 尖端朝左；否则朝上。
    func arrowhead(tip: (x: Double, y: Double), pointsLeft: Bool) -> Path {
        let corners =
            if pointsLeft {
                [point(tip.x, tip.y), point(tip.x + 3.6, tip.y - 2.8), point(tip.x + 3.6, tip.y + 2.8)]
            } else {
                [point(tip.x, tip.y), point(tip.x - 2.8, tip.y + 3.6), point(tip.x + 2.8, tip.y + 3.6)]
            }

        var triangle = Path()
        triangle.addLines(corners)
        triangle.closeSubpath()

        return triangle.union(stroked(triangle))
    }
}

// MARK: - SymbolBadge

/// 图标右下角的实心圆角标：图形缩到左上，在角标四周让出一圈空隙，角标里挖出图案。
/// “已在别的工作树签出” 与新建分支的角标共用这里的位置与大小。
enum SymbolBadge {
    /// 带角标的图标在给定正方形里的填充轮廓。
    ///
    /// - Parameters:
    ///   - square: 图标所在的正方形。
    ///   - glyph: 不带角标的图形在给定正方形里的轮廓。
    ///   - cutout: 角标里挖掉的图案，参数是角标的圆心与图标的边长。
    static func outline(
        in square: CGRect,
        glyph: (CGRect) -> Path,
        cutout: (CGPoint, CGFloat) -> Path
    ) -> Path {
        let side = square.width
        let center = CGPoint(x: square.minX + side * 0.74, y: square.minY + side * 0.74)

        // 以角标圆心为中心、按边长比例取半径的圆
        let circle = { (radius: Double) in
            Path(ellipseIn: CGRect(origin: center, size: .zero).insetBy(dx: -side * radius, dy: -side * radius))
        }

        // 图形缩到左上，挖掉比角标大一圈的圆，再放上角标
        let scaled = CGRect(origin: square.origin, size: CGSize(width: side * 0.8, height: side * 0.8))
        var path = glyph(scaled).subtracting(circle(0.32))
        path.addPath(circle(0.26).subtracting(cutout(center, side)))

        return path
    }
}

// MARK: - AppSymbolImage

/// SwiftUI 用的符号图，大小随字体：自绘的图形铺在一个隐藏的方形系统符号上，取它在当前字体下的大小。
struct AppSymbolImage: View {
    /// 符号的名字。
    let name: String

    /// 系统符号或自绘的图形，颜色随前景样式。
    var body: some View {
        if AppSymbol.isDrawn(name) {
            Image(systemName: "square")
                .hidden()
                .overlay { AppSymbolShape(name: name) }
        } else {
            Image(systemName: name)
        }
    }
}

// MARK: - AppSymbolShape

/// 自绘的图形，在所在矩形里居中的最大正方形内描出；大小由调用处的边框决定。
struct AppSymbolShape: Shape {
    /// 自绘图形的名字。
    let name: String

    /// 图形在矩形里居中的最大正方形内描出；名字不是自绘的图形时为空。
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)

        return AppSymbol.outline(name, in: square) ?? Path()
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
