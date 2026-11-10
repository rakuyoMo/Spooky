import AppKit
import Testing

@testable import Spooky

// MARK: - AppIconRendererTests

/// 运行时 App 图标的合成。
///
/// Dock 画包内图标时用系统处理过的样子，画运行时图标时原样画出、而且画小一圈：
/// 合成结果要以系统图标为底、按 `dockScale` 放大、保留比白色还亮的亮边且不被压暗，只在目标与包内图标不同的地方改动，
/// Dock 里的运行时图标才与包内图标一致，连上服务器时只有指示灯变化。
struct AppIconRendererTests {
    /// 合成用的位图边长：放大后边缘移动几个像素，足够看出位置。
    private static let side = 800

    /// 居中方块的半边长：放大后是 320 × 1.0125 = 324，左边缘由 80 移到 76。
    private static let squareHalfSide = 320

    /// 8 位量化与缩放插值带来的误差上限。
    private static let tolerance: Float = 2 / 255

    /// 图标的 icns 所在的目录：本文件位于 `Tests/SpookyTests/` 下，向上三级是仓库根目录。
    private static let iconsURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/Spooky/AppIcon", directoryHint: .isDirectory)

    /// 1024 px 图标里四盏指示灯的圆心，y 自上而下，与 `scripts/make-icon.js` 的机架一致。
    private static let lightCenters = [(714, 626), (750, 626), (714, 772), (750, 772)]

    /// 指示灯的半径，外加 1 px 抗锯齿的边。
    private static let lightReach = 12

    /// 内容以中心为准按 `dockScale` 放大：方块的中心不动，左边缘向外移出原来的位置；
    /// 像素尺寸与系统图标相同，Dock 按同样的尺寸缩放，放大只发生在图标内部。
    @Test("内容以中心为准放大，像素尺寸与系统图标相同")
    func scalesAroundCenter() throws {
        let system = try Self.squareImage(color: (1, 1, 1), halfSide: Self.squareHalfSide)
        let empty = try Self.squareImage(color: (0, 0, 0), halfSide: 0)
        let input = try Self.pixels(of: system)
        let center = Self.side / 2

        let rendered = try #require(
            AppIconRenderer.runtimeIcon(
                system: system,
                bundled: empty,
                target: empty
            )
        )

        #expect(rendered.width == Self.side && rendered.height == Self.side)

        // 放大前方块从 80 开始，放大后从 76 开始：78 列由透明变成不透明，74 列仍然透明。
        let output = try Self.pixels(of: rendered)

        #expect(input[Self.offset(x: 78, y: center) + 3] == 0)
        #expect(output[Self.offset(x: 78, y: center) + 3] > 1 - Self.tolerance)
        #expect(output[Self.offset(x: 74, y: center) + 3] < Self.tolerance)
        #expect(output[Self.offset(x: center, y: center) + 3] > 1 - Self.tolerance)
    }

    /// 系统图标带着高于白色的亮度余量：白色仍是 1，比白色还亮的亮边原样保留，不被整体压暗；
    /// 目标图标与包内图标不同的地方叠上两者的差别，相同的地方保持系统图标，比白色还亮的结果不截断。
    @Test("保留系统图标的亮度，只在目标与包内图标不同的地方改动")
    func keepsSystemBrightnessAndAddsTargetDifference() throws {
        let center = Self.side / 2
        let black = try Self.image(color: (0, 0, 0))

        let bright = try Self.pixels(
            of: #require(
                AppIconRenderer.runtimeIcon(
                    system: Self.highDynamicRangeImage(),
                    bundled: black,
                    target: black
                )
            )
        )

        // 中间一条是亮边，其余是白色。
        let white = Self.offset(x: center, y: center / 2)
        let edge = Self.offset(x: center, y: center)

        for channel in 0 ..< 3 {
            #expect(abs(bright[white + channel] - 1) < Self.tolerance)
            #expect(abs(bright[edge + channel] - Self.edgeBrightness) < Self.tolerance)
        }

        // 灰色的系统图标上叠目标的差别：中间的方块里红色加上 1，方块外与系统图标相同。
        let gray = Float(128) / 255

        let output = try Self.pixels(
            of: #require(
                AppIconRenderer.runtimeIcon(
                    system: Self.image(color: (0.5, 0.5, 0.5)),
                    bundled: black,
                    target: Self.image(color: (0, 0, 0), square: (1, 0, 0), squareHalfSide: 100)
                )
            )
        )

        let changed = Self.offset(x: center, y: center)
        let unchanged = Self.offset(x: center / 4, y: center / 4)

        #expect(abs(output[changed] - (gray + 1)) < Self.tolerance)
        #expect(abs(output[changed + 1] - gray) < Self.tolerance)
        #expect(abs(output[changed + 2] - gray) < Self.tolerance)

        for channel in 0 ..< 3 {
            #expect(abs(output[unchanged + channel] - gray) < Self.tolerance)
        }
    }

    /// 各组的默认图标与深色图标，亮灯版与灭灯版都只在指示灯处不同：服务器幽灵是机架上的四盏灯，午夜是眼睛与光晕；
    /// 运行时图标叠上的是两者的差别，别处不同就会把别的改动也带上去。
    @Test("亮灯版与灭灯版只差指示灯", arguments: AppIconGroup.allCases, [false, true])
    func litIconDiffersOnlyAtLights(group: AppIconGroup, isDark: Bool) throws {
        let unlit = group.iconName(for: AppIconVariant(isDark: isDark, isConnected: false))
        let lit = group.iconName(for: AppIconVariant(isDark: isDark, isConnected: true))
        let unlitPixels = try Self.bytes(of: Self.icon(named: unlit))
        let litPixels = try Self.bytes(of: Self.icon(named: lit))
        var changed = 0

        for index in 0 ..< 1024 * 1024 where unlitPixels[index] != litPixels[index] {
            let x = index % 1024
            let y = index / 1024

            #expect(Self.isOnLight(x: x, y: y, of: group), "\(lit)：(\(x), \(y)) 不在指示灯上")

            changed += 1
        }

        // 灯真的有变化：亮灯版不能与灭灯版相同。
        #expect(changed > 0)
    }
}

// MARK: - Private

extension AppIconRendererTests {
    /// 高动态范围替身里亮边的亮度：比白色亮一成。
    private static let edgeBrightness: Float = 1.1

    /// 高动态范围替身的亮度余量，与系统给出的 App 图标相同。
    private static let headroom: Float = 1.2

    /// 午夜光晕的椭圆，在幽灵的直立坐标里：中心是眼睛的中心，与 `scripts/make-icon.js` 的 `MIDNIGHT_EYE`、`MIDNIGHT_GLOW` 一致。
    private static let glow = (x: -125.0, y: -167.5, radiusX: 145.0, radiusY: 238.0)

    /// 光晕椭圆向外放宽的距离，在直立坐标里约合 1024 px 图标的 2 px 抗锯齿边。
    private static let glowReach = 3.0

    /// 像素是否落在这一组的指示灯上：服务器幽灵是四盏灯，午夜是光晕的椭圆，眼睛在它以内。
    /// - Parameters:
    ///   - x: 1024 px 图标的列
    ///   - y: 1024 px 图标的行，自上而下
    ///   - group: 图标所属的组
    private static func isOnLight(
        x: Int,
        y: Int,
        of group: AppIconGroup
    ) -> Bool {
        guard group == .midnight else {
            return lightCenters.contains { abs($0.0 - x) <= lightReach && abs($0.1 - y) <= lightReach }
        }

        // 先退出底板：满幅画面以 (100, 100) 为原点缩进 824 边长；再退出幽灵的姿态：原点 (700, 560)、向左倾斜 18°、缩到 0.95 倍。
        let frameX = (Double(x) + 0.5 - 100) * 1024 / 824 - 700
        let frameY = (Double(y) + 0.5 - 100) * 1024 / 824 - 560
        let angle = 18 * Double.pi / 180
        let uprightX = (frameX * cos(angle) - frameY * sin(angle)) / 0.95
        let uprightY = (frameX * sin(angle) + frameY * cos(angle)) / 0.95

        let dx = (uprightX - glow.x) / (glow.radiusX + glowReach)
        let dy = (uprightY - glow.y) / (glow.radiusY + glowReach)

        return dx * dx + dy * dy <= 1
    }

    /// 一张 `side` 边长的 8 位 sRGB 图：整张不透明的底色，可以在中间画一个不透明的方块。
    /// - Parameters:
    ///   - color: 底色
    ///   - square: 中间方块的颜色，nil 时与底色相同
    ///   - squareHalfSide: 中间方块的半边长
    private static func image(
        color: (Double, Double, Double),
        square: (Double, Double, Double)? = nil,
        squareHalfSide: Int = 0
    ) throws -> CGImage {
        let context = try bitmapContext(width: side, height: side)
        let squareColor = square ?? color

        context.setFillColor(CGColor(srgbRed: color.0, green: color.1, blue: color.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))

        context.setFillColor(CGColor(srgbRed: squareColor.0, green: squareColor.1, blue: squareColor.2, alpha: 1))
        context.fill(squareRect(halfSide: squareHalfSide))

        return try #require(context.makeImage())
    }

    /// 一张 `side` 边长的 8 位 sRGB 图：只有中间的方块不透明，其余全透明。
    /// - Parameters:
    ///   - color: 方块的颜色
    ///   - halfSide: 方块的半边长，0 时整张透明
    private static func squareImage(
        color: (Double, Double, Double),
        halfSide: Int
    ) throws -> CGImage {
        let context = try bitmapContext(width: side, height: side)

        context.setFillColor(CGColor(srgbRed: color.0, green: color.1, blue: color.2, alpha: 1))
        context.fill(squareRect(halfSide: halfSide))

        return try #require(context.makeImage())
    }

    /// 系统图标的替身：白色的底、中间一条比白色还亮的亮边，带着与系统图标相同的亮度余量。
    private static func highDynamicRangeImage() throws -> CGImage {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.extendedSRGB))
        let context = try floatContext(width: side, height: side)
        let edge = CGFloat(edgeBrightness)
        let center = side / 2
        let band = 20

        context.setFillColor(try #require(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 1])))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))

        // 扩展 sRGB 的颜色才能比 1 大。
        context.setFillColor(try #require(CGColor(colorSpace: colorSpace, components: [edge, edge, edge, 1])))
        context.fill(CGRect(x: 0, y: center - band, width: side, height: band * 2))

        let image = try #require(context.makeImage())

        return try #require(CGImageCreateCopyWithContentHeadroom(headroom, image))
    }

    /// 以位图中心为中心、给定半边长的方块。
    private static func squareRect(halfSide: Int) -> CGRect {
        CGRect(
            x: side / 2 - halfSide,
            y: side / 2 - halfSide,
            width: halfSide * 2,
            height: halfSide * 2
        )
    }

    /// 读出图像的全部分量：扩展 sRGB 的 32 位浮点，预乘透明度，按行自上而下、每个像素依次是红、绿、蓝、透明度。
    private static func pixels(of image: CGImage) throws -> [Float] {
        let context = try floatContext(width: image.width, height: image.height)

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        let count = image.width * image.height * 4
        let data = try #require(context.data)
            .bindMemory(to: Float.self, capacity: count)

        return Array(UnsafeBufferPointer(start: data, count: count))
    }

    /// 像素在 `pixels(of:)` 结果里的下标。
    /// - Parameters:
    ///   - x: 列
    ///   - y: 行，自上而下
    private static func offset(
        x: Int,
        y: Int
    ) -> Int {
        (y * side + x) * 4
    }

    /// 读出图像每个像素的 8 位 RGBA（预乘透明度），按行自上而下，一个像素合成一个整数，便于逐字节比较。
    private static func bytes(of image: CGImage) throws -> [UInt32] {
        let context = try bitmapContext(width: image.width, height: image.height)

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        let count = image.width * image.height
        let data = try #require(context.data)
            .bindMemory(to: UInt32.self, capacity: count)

        return Array(UnsafeBufferPointer(start: data, count: count))
    }

    /// 仓库里的 icns 中 1024 px 的一张，原尺寸画出时逐像素不变。
    /// - Parameter name: icns 的文件名，不含扩展名
    private static func icon(named name: String) throws -> CGImage {
        let icon = try #require(NSImage(contentsOf: iconsURL.appending(path: "\(name).icns")))

        var rect = CGRect(x: 0, y: 0, width: 1024, height: 1024)

        return try #require(icon.cgImage(forProposedRect: &rect, context: nil, hints: nil))
    }

    /// 32 位浮点、预乘透明度的扩展 sRGB 位图上下文：分量可以大于 1。
    private static func floatContext(
        width: Int,
        height: Int
    ) throws -> CGContext {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.extendedSRGB))

        return try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 32,
                bytesPerRow: width * 16,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.floatComponents.rawValue
                    | CGImageByteOrderInfo.order32Little.rawValue
            )
        )
    }

    /// 8 位 RGBA、预乘透明度的 sRGB 位图上下文。
    private static func bitmapContext(
        width: Int,
        height: Int
    ) throws -> CGContext {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))

        return try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
    }
}
