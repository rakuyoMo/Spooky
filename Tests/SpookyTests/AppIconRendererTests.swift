import AppKit
import Testing

@testable import Spooky

// MARK: - AppIconRendererTests

/// 运行时 App 图标的逐像素处理。
///
/// “透明 · 深色” “色调 · 深色”：去色后不带色彩，着色后只带色调颜色，明暗顺序与透明度不变；
/// 深色图标处理后仍比默认图标暗，Dock 上才是与系统图标一致的深底。
/// 点亮指示灯：只有灯所在的像素变化，灯的颜色与系统处理过的其余部分一致，连上服务器时图标才只有指示灯在变。
struct AppIconRendererTests {
    /// 要处理的两种样式：透明、色调。
    private static let processedStyles: [AppIconStyle] = [.clear, .tinted]

    /// 8 位量化带来的误差上限。
    private static let tolerance = 2.0 / 255

    /// 按亮度拟合系统的处理时，8 位量化累积出的误差上限。
    private static let fittingTolerance = 3.0 / 255

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

    /// 指示灯灭着与亮着的两版图标：默认图标与深色图标各一对。
    private static let iconPairs = [
        (unlit: "AppIcon", lit: "AppIconConnected"),
        (unlit: "AppIconDark", lit: "AppIconDarkConnected"),
    ]

    /// 着色用的色调颜色：固定的 sRGB 颜色，不随外观变化。
    private static var tintColor: NSColor {
        NSColor(srgbRed: 0.2, green: 0.6, blue: 0.9, alpha: 1)
    }

    /// 各种色彩鲜明的像素，包括默认图标底板顶部的夜色紫。
    private static var colorfulPixels: [Pixel] {
        [
            (1, 0, 0, 1),
            (0, 1, 0, 1),
            (0, 0, 1, 1),
            (1, 0.6, 0.1, 1),
            (0.17, 0.14, 0.44, 1),
        ]
    }

    /// 包内默认图标的替身：从黑到白的灰阶，后面跟两盏灭着的灯。
    private static var unlitPixels: [Pixel] {
        (0 ... 100).map { step in
            let gray = Double(step) / 100
            return (gray, gray, gray, 1)
        } + [
            (0.08, 0.06, 0.2, 1),
            (0.08, 0.06, 0.2, 1),
        ]
    }

    /// 亮灯版的替身：与 `unlitPixels` 只差最后两盏灯，一绿一青。
    private static var litPixels: [Pixel] {
        unlitPixels.dropLast(2) + [
            (0.27, 0.88, 0.54, 1),
            (0.31, 0.84, 1, 1),
        ]
    }

    /// 去色后每个像素的红、绿、蓝相等：透明样式不带任何色彩。
    @Test("去色后不带色彩")
    func clearRemovesColor() throws {
        let output = try Self.pixels(
            of: Self.render(Self.image(of: Self.colorfulPixels), as: .clear)
        )

        for pixel in output {
            #expect(abs(pixel.red - pixel.green) <= Self.tolerance)
            #expect(abs(pixel.green - pixel.blue) <= Self.tolerance)
        }
    }

    /// 着色后亮部的色相与色调颜色一致：色调样式的图案是色调颜色。
    @Test("着色后亮部是色调颜色的色相")
    func tintedTakesTintHue() throws {
        let output = try Self.pixels(
            of: Self.render(
                Self.image(of: [(1, 1, 1, 1), (0.6, 0.6, 0.6, 1)]),
                as: .tinted
            )
        )

        for pixel in output {
            let color = NSColor(
                srgbRed: pixel.red,
                green: pixel.green,
                blue: pixel.blue,
                alpha: 1
            )

            #expect(abs(color.hueComponent - Self.tintColor.hueComponent) < 0.01)
            #expect(color.saturationComponent > 0.3)
        }
    }

    /// 黑色变成不带色彩的深色：两种样式的底色都是中性的深色，与色调颜色无关。
    @Test("黑色变成中性的深色", arguments: processedStyles)
    func blackBecomesNeutralDark(style: AppIconStyle) throws {
        let output = try Self.pixels(
            of: Self.render(Self.image(of: [(0, 0, 0, 1)]), as: style)
        )

        let pixel = try #require(output.first)

        #expect(abs(pixel.red - pixel.green) <= Self.tolerance)
        #expect(abs(pixel.green - pixel.blue) <= Self.tolerance)
        #expect(pixel.red < 0.1)
    }

    /// 原图越亮，处理后越亮：明暗层次保留下来，图案才认得出。
    @Test("明暗顺序不变", arguments: processedStyles)
    func brightnessOrderIsPreserved(style: AppIconStyle) throws {
        let grays: [Pixel] = [0, 0.25, 0.5, 0.75, 1].map { ($0, $0, $0, 1) }

        let lumas = try Self.pixels(
            of: Self.render(Self.image(of: grays), as: style)
        )
        .map(Self.luma)

        for (darker, brighter) in zip(lumas, lumas.dropFirst()) {
            #expect(darker < brighter)
        }
    }

    /// 透明度不变：图标四周的透明边仍然透明，半透明的边缘仍然半透明。
    @Test("透明度不变", arguments: processedStyles)
    func alphaIsPreserved(style: AppIconStyle) throws {
        let input: [Pixel] = [
            (0.5, 0.5, 0.5, 0),
            (0.8, 0.4, 0.2, 0.5),
            (0.8, 0.4, 0.2, 1),
        ]

        let output = try Self.pixels(
            of: Self.render(Self.image(of: input), as: style)
        )

        for (source, result) in zip(input, output) {
            #expect(abs(source.alpha - result.alpha) <= Self.tolerance)
        }
    }

    /// 深色图标处理后整体比默认图标暗，且是深底（平均亮度低于一半）：这正是深色子变体要换成深色图标的原因。
    @Test("深色图标处理后比默认图标暗", arguments: processedStyles)
    func processedDarkIconIsDarkerThanDefault(style: AppIconStyle) throws {
        let darkLuma = try Self.meanLuma(
            of: Self.render(Self.icon(named: "AppIconDark", side: 64), as: style)
        )

        let defaultLuma = try Self.meanLuma(
            of: Self.render(Self.icon(named: "AppIcon", side: 64), as: style)
        )

        #expect(darkLuma < defaultLuma)
        #expect(darkLuma < 0.5)
    }

    /// 亮灯版与灭灯版只在四盏指示灯处不同：点亮指示灯时按两者的差别换像素，别处不同就会把别的改动也换上去。
    @Test("亮灯版与灭灯版只差指示灯", arguments: iconPairs)
    func litIconDiffersOnlyAtLights(unlit: String, lit: String) throws {
        let unlitPixels = try Self.bytes(of: Self.icon(named: unlit, side: 1024))
        let litPixels = try Self.bytes(of: Self.icon(named: lit, side: 1024))
        var changed = 0

        for index in 0 ..< 1024 * 1024 where unlitPixels[index] != litPixels[index] {
            let x = index % 1024
            let y = index / 1024

            #expect(
                Self.lightCenters.contains { abs($0.0 - x) <= Self.lightReach && abs($0.1 - y) <= Self.lightReach },
                "(\(x), \(y)) 不在指示灯上"
            )

            changed += 1
        }

        // 灯真的有变化：亮灯版不能与灭灯版相同。
        #expect(changed > 0)
    }

    /// 灯以外的像素逐字节保持系统的处理结果：连上服务器时，系统给图标做的处理一点不变。
    @Test("灯以外保持系统的处理结果", arguments: [false, true])
    func pixelsOutsideLightsKeepSystemStyle(recolorsLights: Bool) throws {
        let styled = try Self.image(of: Self.unlitPixels.map(Self.systemStyle))

        let output = try #require(
            AppIconRenderer.lightUp(
                styled,
                unlit: Self.image(of: Self.unlitPixels),
                lit: Self.image(of: Self.litPixels),
                recolorsLights: recolorsLights
            )
        )

        let expected = try Self.bytes(of: styled)
        let actual = try Self.bytes(of: output)

        for index in 0 ..< Self.unlitPixels.count - 2 {
            #expect(actual[index] == expected[index])
        }
    }

    /// 原样显示的样式下，亮着的灯就是亮灯版的颜色：系统在这类样式下不改颜色。
    @Test("原样显示时灯是亮灯版的颜色")
    func regularStyleLightsTakeLitColors() throws {
        let output = try #require(
            AppIconRenderer.lightUp(
                Self.image(of: Self.unlitPixels),
                unlit: Self.image(of: Self.unlitPixels),
                lit: Self.image(of: Self.litPixels),
                recolorsLights: false
            )
        )

        let lights = try Self.pixels(of: output).suffix(2)

        for (light, expected) in zip(lights, Self.litPixels.suffix(2)) {
            #expect(abs(light.red - expected.red) <= Self.tolerance)
            #expect(abs(light.green - expected.green) <= Self.tolerance)
            #expect(abs(light.blue - expected.blue) <= Self.tolerance)
        }
    }

    /// 透明、色调样式下，亮着的灯按系统的处理上色；系统在边缘加的描边不是亮度的函数，不能把灯的颜色带偏。
    @Test("透明、色调样式下灯按系统的处理上色", arguments: [false, true])
    func processedStyleLightsFollowSystemStyle(hasEdgeHighlight: Bool) throws {
        var unlit = Self.unlitPixels
        var styled = Self.unlitPixels.map(Self.systemStyle)

        // 描边：一圈中灰的像素被系统额外提亮，处理结果不在亮度的直线上。
        if hasEdgeHighlight {
            let edge = [Pixel](repeating: (0.5, 0.5, 0.5, 1), count: 12)
            let highlighted: [Pixel] = edge.map(Self.systemStyle).map {
                (min($0.red + 0.2, 1), min($0.green + 0.2, 1), min($0.blue + 0.2, 1), 1)
            }

            unlit.insert(contentsOf: edge, at: 0)
            styled.insert(contentsOf: highlighted, at: 0)
        }

        let lit = Array(unlit.dropLast(2)) + Self.litPixels.suffix(2)

        let output = try #require(
            AppIconRenderer.lightUp(
                Self.image(of: styled),
                unlit: Self.image(of: unlit),
                lit: Self.image(of: lit),
                recolorsLights: true
            )
        )

        let lights = try Self.pixels(of: output).suffix(2)

        for (light, source) in zip(lights, Self.litPixels.suffix(2)) {
            let expected = Self.systemStyle(source)

            #expect(abs(light.red - expected.red) <= Self.fittingTolerance)
            #expect(abs(light.green - expected.green) <= Self.fittingTolerance)
            #expect(abs(light.blue - expected.blue) <= Self.fittingTolerance)
        }
    }
}

// MARK: - Private

extension AppIconRendererTests {
    /// 未预乘透明度的 sRGB 像素，各分量 0–1。
    private typealias Pixel = (red: Double, green: Double, blue: Double, alpha: Double)

    /// 按样式处理图像；原样显示的样式不经处理。
    /// - Parameters:
    ///   - image: 要处理的图像
    ///   - style: 要处理成的样式
    private static func render(
        _ image: CGImage,
        as style: AppIconStyle
    ) throws -> CGImage {
        switch style {
        case .regular:
            image

        case .clear:
            try #require(AppIconRenderer.clear(image))

        case .tinted:
            try #require(AppIconRenderer.tinted(image, tintColor: tintColor))
        }
    }

    /// 替身的系统处理：各通道是亮度的线性函数，红色在暗部被夹到 0、蓝色在亮部被夹到 1，与 “色调 · 浅色” 下的蓝色相仿。
    private static func systemStyle(_ pixel: Pixel) -> Pixel {
        let brightness = luma(pixel)
        let clamp = { (value: Double) in min(max(value, 0), 1) }

        return (
            red: clamp(-0.2 + 0.9 * brightness),
            green: clamp(0.53 + 0.42 * brightness),
            blue: clamp(0.98 + 0.05 * brightness),
            alpha: pixel.alpha
        )
    }

    /// 把一排像素做成一行高的 sRGB 图像。
    /// - Parameter pixels: 从左到右的像素
    private static func image(of pixels: [Pixel]) throws -> CGImage {
        let context = try bitmapContext(width: pixels.count, height: 1)
        let data = try #require(context.data)
            .bindMemory(to: UInt8.self, capacity: pixels.count * 4)

        // 位图预乘透明度，写入前把颜色乘上透明度。
        for (index, pixel) in pixels.enumerated() {
            let components = [
                pixel.red * pixel.alpha,
                pixel.green * pixel.alpha,
                pixel.blue * pixel.alpha,
                pixel.alpha,
            ]

            for (offset, component) in components.enumerated() {
                data[index * 4 + offset] = UInt8((component * 255).rounded())
            }
        }

        return try #require(context.makeImage())
    }

    /// 读出图像的全部像素，除掉透明度还原成未预乘的颜色；全透明的像素颜色记为 0。
    private static func pixels(of image: CGImage) throws -> [Pixel] {
        let context = try bitmapContext(width: image.width, height: image.height)

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        let count = image.width * image.height
        let data = try #require(context.data)
            .bindMemory(to: UInt8.self, capacity: count * 4)

        return (0 ..< count).map { index in
            let alpha = Double(data[index * 4 + 3]) / 255
            let scale = alpha > 0 ? 1 / (255 * alpha) : 0

            return (
                red: Double(data[index * 4]) * scale,
                green: Double(data[index * 4 + 1]) * scale,
                blue: Double(data[index * 4 + 2]) * scale,
                alpha: alpha
            )
        }
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

    /// 仓库里的 icns 画成给定边长的图像：比较明暗时缩小以加快测试，逐像素比较时取原尺寸。
    /// - Parameters:
    ///   - name: icns 的文件名，不含扩展名
    ///   - side: 图像的边长
    private static func icon(
        named name: String,
        side: Int
    ) throws -> CGImage {
        let icon = try #require(NSImage(contentsOf: iconsURL.appending(path: "\(name).icns")))

        // 取 icns 里 1024 px 的一张，原尺寸画出时逐像素不变。
        var rect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
        let largest = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        let source = try #require(largest)

        let context = try bitmapContext(width: side, height: side)

        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: side, height: side))

        return try #require(context.makeImage())
    }

    /// 不透明部分的平均亮度，0–1；只数完全不透明的像素，四周的透明边与投影不计入。
    private static func meanLuma(of image: CGImage) throws -> Double {
        let lumas = try pixels(of: image)
            .filter { $0.alpha == 1 }
            .map(luma)

        return lumas.reduce(0, +) / Double(max(lumas.count, 1))
    }

    /// 像素的 Rec. 709 亮度（在 sRGB 编码值上计算）。
    private static func luma(_ pixel: Pixel) -> Double {
        0.2126 * pixel.red + 0.7152 * pixel.green + 0.0722 * pixel.blue
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
