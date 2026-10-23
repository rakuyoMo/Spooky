import AppKit

// MARK: - AppIconRenderer

/// 运行时换上的 App 图标的逐像素处理：给深色图标做 “透明 · 深色” “色调 · 深色” 处理，以及在系统处理过的默认图标上点亮指示灯。
///
/// 系统对 App 图标的透明、色调处理只看像素的 Rec. 709 亮度（在 sRGB 编码值上计算），
/// 各通道都是亮度的线性函数，透明度不变（macOS 27 实测）。
enum AppIconRenderer {
    /// 透明 · 深色：亮度为 0 时的灰度。
    private static let clearOffset = 0.075

    /// 透明 · 深色：灰度随亮度增长的斜率。
    private static let clearSlope = 0.79

    /// 色调 · 深色：亮度为 0 时各通道的值，与色调颜色无关。
    private static let tintedOffset = 0.08

    /// 色调 · 深色：各通道随 “亮度 × 色调颜色的对应通道” 增长的斜率。
    private static let tintedSlope = 0.92

    /// 拟合系统的处理时，第二遍只用离第一遍直线不超过这个值的像素：系统在图标边缘加的描边不是亮度的函数。
    private static let fittingTolerance = 0.03

    /// 去色：灰度 = 0.075 + 0.79 × 亮度；系数按 macOS 27 的 Dock 对包内图标的处理效果拟合。
    /// - Parameter image: 要处理的图标
    /// - Returns: 处理后的图标，像素尺寸与原图相同；建不起位图上下文时为 nil
    static func clear(_ image: CGImage) -> CGImage? {
        recolor(
            image,
            offset: clearOffset,
            slopes: (clearSlope, clearSlope, clearSlope)
        )
    }

    /// 着色：各通道 = 0.08 + 0.92 × 亮度 × 色调颜色的对应通道；系数按 macOS 27 的 Dock 对包内图标的处理效果拟合。
    /// - Parameters:
    ///   - image: 要处理的图标
    ///   - tintColor: 色调颜色；系统颜色这类动态颜色按深色外观取值
    /// - Returns: 处理后的图标，像素尺寸与原图相同；色调颜色转不成 sRGB 或建不起位图上下文时为 nil
    static func tinted(
        _ image: CGImage,
        tintColor: NSColor
    ) -> CGImage? {
        // 系统颜色在深浅外观下取值不同，深色子变体按深色外观取。
        #warning("TODO: 在 “色调 · 深色” 下选定橙色等非蓝色的色调颜色，对照 Dock 中系统 App 的图标，核实色调颜色按深色还是浅色外观解析；只影响色调样式深色子变体的图标颜色。")
        var resolved: NSColor? = nil

        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            resolved = tintColor.usingColorSpace(.sRGB)
        }

        guard let resolved else {
            return nil
        }

        return recolor(
            image,
            offset: tintedOffset,
            slopes: (
                tintedSlope * resolved.redComponent,
                tintedSlope * resolved.greenComponent,
                tintedSlope * resolved.blueComponent
            )
        )
    }

    /// 在系统处理过的包内默认图标上点亮指示灯。
    ///
    /// 亮灯版与包内默认图标只有指示灯不同；不同的像素换成 “系统处理结果 + 亮灯版处理后 − 默认图标处理后”，
    /// 其余像素保持系统的处理结果。透明、色调样式下的 “处理后” 按从系统处理结果拟合出的直线换算，
    /// 原样显示的样式下就是像素本身的颜色。
    /// - Parameters:
    ///   - styled: 系统按当前样式处理过的包内默认图标
    ///   - unlit: 包内默认图标，指示灯灭着
    ///   - lit: 指示灯亮着的默认图标
    ///   - recolorsLights: 系统是否按亮度给图标重新上色：透明、色调样式下为 true
    /// - Returns: 点亮指示灯后的图标，像素尺寸与 styled 相同；建不起位图上下文时为 nil
    static func lightUp(
        _ styled: CGImage,
        unlit: CGImage,
        lit: CGImage,
        recolorsLights: Bool
    ) -> CGImage? {
        let width = styled.width
        let height = styled.height

        // 三张图画进同样大小的位图，逐像素对齐；结果直接写回系统处理结果的位图。
        guard
            let output = bitmap(of: styled, width: width, height: height),
            let unlitBitmap = bitmap(of: unlit, width: width, height: height),
            let litBitmap = bitmap(of: lit, width: width, height: height),
            let outputData = output.data,
            let unlitData = unlitBitmap.data,
            let litData = litBitmap.data
        else {
            return nil
        }

        let pixelCount = width * height
        let styledPixels = outputData.bindMemory(to: UInt8.self, capacity: pixelCount * 4)
        let unlitPixels = unlitData.bindMemory(to: UInt8.self, capacity: pixelCount * 4)
        let litPixels = litData.bindMemory(to: UInt8.self, capacity: pixelCount * 4)

        // 灯的颜色先换算成系统处理后的样子：透明、色调样式下按拟合出的直线，原样显示的样式下不换算。
        let processed: (Pixel) -> [Double]

        if recolorsLights {
            let lines = styleLines(
                unlit: unlitPixels,
                styled: styledPixels,
                pixelCount: pixelCount
            )

            processed = { pixel in
                let brightness = luma(of: pixel)
                return lines.map { min(max($0.offset + $0.slope * brightness, 0), 1) }
            }
        } else {
            processed = { [$0.red, $0.green, $0.blue] }
        }

        for index in 0 ..< pixelCount {
            let base = index * 4

            // 亮灯版与默认图标相同的像素保持系统的处理结果。
            guard
                litPixels[base] != unlitPixels[base]
                || litPixels[base + 1] != unlitPixels[base + 1]
                || litPixels[base + 2] != unlitPixels[base + 2]
                || litPixels[base + 3] != unlitPixels[base + 3]
            else {
                continue
            }

            let styledPixel = pixel(at: index, in: styledPixels)
            let litColor = processed(pixel(at: index, in: litPixels))
            let unlitColor = processed(pixel(at: index, in: unlitPixels))
            let styledColor = [styledPixel.red, styledPixel.green, styledPixel.blue]

            // 只叠上灯亮与灯灭的差别，系统处理结果里按亮度换算不出的部分原样保留。
            for channel in 0 ..< 3 {
                styledPixels[base + channel] = premultipliedByte(
                    styledColor[channel] + litColor[channel] - unlitColor[channel],
                    alpha: styledPixel.alpha
                )
            }
        }

        return output.makeImage()
    }
}

// MARK: - Private

extension AppIconRenderer {
    /// 未预乘透明度的 sRGB 像素，各分量 0–1。
    private typealias Pixel = (red: Double, green: Double, blue: Double, alpha: Double)

    /// 系统对一个通道的处理：通道值 = offset + slope × 亮度。
    private typealias StyleLine = (offset: Double, slope: Double)

    /// 逐像素把颜色换成亮度的线性函数：各通道 = offset + slopes 的对应分量 × 亮度。
    /// - Parameters:
    ///   - image: 要处理的图标
    ///   - offset: 亮度为 0 时各通道的值
    ///   - slopes: 红、绿、蓝各通道随亮度增长的斜率
    /// - Returns: 处理后的图标；建不起位图上下文时为 nil
    private static func recolor(
        _ image: CGImage,
        offset: Double,
        slopes: (red: Double, green: Double, blue: Double)
    ) -> CGImage? {
        guard
            let context = bitmap(of: image, width: image.width, height: image.height),
            let data = context.data
        else {
            return nil
        }

        let pixelCount = image.width * image.height
        let pixels = data.bindMemory(to: UInt8.self, capacity: pixelCount * 4)

        for index in 0 ..< pixelCount {
            let base = index * 4
            let source = pixel(at: index, in: pixels)

            // 全透明的像素（图标四周的透明边）没有颜色可处理。
            guard source.alpha > 0 else {
                continue
            }

            let brightness = luma(of: source)

            // 写回时重新乘上透明度，透明度本身不变。
            pixels[base] = premultipliedByte(offset + slopes.red * brightness, alpha: source.alpha)
            pixels[base + 1] = premultipliedByte(offset + slopes.green * brightness, alpha: source.alpha)
            pixels[base + 2] = premultipliedByte(offset + slopes.blue * brightness, alpha: source.alpha)
        }

        return context.makeImage()
    }

    /// 从包内默认图标与系统处理后的样子，逐通道拟合系统的处理。
    ///
    /// 只用两张图都完全不透明的像素；被夹到 0 或 1 的通道值偏离直线，不计入。先用全部像素拟合一遍，
    /// 再去掉离直线超过 `fittingTolerance` 的像素重新拟合。定不出斜率的通道（例如全被夹住）斜率记为 0，
    /// 灯亮与灯灭在这个通道上就没有差别。
    /// - Parameters:
    ///   - unlit: 包内默认图标的像素
    ///   - styled: 系统处理结果的像素
    ///   - pixelCount: 两张图的像素数
    /// - Returns: 红、绿、蓝三个通道的直线
    private static func styleLines(
        unlit: UnsafeMutablePointer<UInt8>,
        styled: UnsafeMutablePointer<UInt8>,
        pixelCount: Int
    ) -> [StyleLine] {
        var lines: [StyleLine] = []

        for pass in 0 ..< 2 {
            var fits = [LineFit](repeating: LineFit(), count: 3)

            for index in 0 ..< pixelCount {
                let base = index * 4

                guard unlit[base + 3] == 255, styled[base + 3] == 255 else {
                    continue
                }

                let brightness = luma(of: pixel(at: index, in: unlit))

                for channel in 0 ..< 3 {
                    let byte = styled[base + channel]

                    guard byte != 0, byte != 255 else {
                        continue
                    }

                    let value = Double(byte) / 255

                    // 第二遍去掉离第一遍直线太远的像素。
                    if pass > 0 {
                        let line = lines[channel]
                        let residual = value - line.offset - line.slope * brightness

                        guard abs(residual) <= fittingTolerance else {
                            continue
                        }
                    }

                    fits[channel].add(x: brightness, y: value)
                }
            }

            lines = fits.map(\.line)
        }

        return lines
    }

    /// 读出位图里一个像素，除掉透明度还原成未预乘的颜色；全透明的像素颜色记为 0。
    /// - Parameters:
    ///   - index: 像素序号，按行自上而下
    ///   - pixels: 8 位 RGBA、预乘透明度的位图数据
    private static func pixel(
        at index: Int,
        in pixels: UnsafeMutablePointer<UInt8>
    ) -> Pixel {
        let base = index * 4
        let alpha = Double(pixels[base + 3]) / 255
        let scale = alpha > 0 ? 1 / (255 * alpha) : 0

        return (
            red: Double(pixels[base]) * scale,
            green: Double(pixels[base + 1]) * scale,
            blue: Double(pixels[base + 2]) * scale,
            alpha: alpha
        )
    }

    /// 像素的 Rec. 709 亮度（在 sRGB 编码值上计算）。
    private static func luma(of pixel: Pixel) -> Double {
        0.2126 * pixel.red + 0.7152 * pixel.green + 0.0722 * pixel.blue
    }

    /// 把图标画进 8 位 RGBA、预乘透明度的 sRGB 位图：系数都在 sRGB 编码值上，图标原本的色彩空间在这一步统一。
    /// - Parameters:
    ///   - image: 要画的图标
    ///   - width: 位图宽度
    ///   - height: 位图高度
    /// - Returns: 画好图标的位图上下文；建不起时为 nil
    private static func bitmap(
        of image: CGImage,
        width: Int,
        height: Int
    ) -> CGContext? {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context
    }

    /// 把 0–1 的通道值夹进范围、乘上透明度，换成 8 位整数。
    /// - Parameters:
    ///   - value: 未预乘的通道值
    ///   - alpha: 像素的透明度，0–1
    private static func premultipliedByte(
        _ value: Double,
        alpha: Double
    ) -> UInt8 {
        UInt8((min(max(value, 0), 1) * alpha * 255).rounded())
    }
}

// MARK: - LineFit

/// 最小二乘拟合直线 y = offset + slope × x 时逐个样本累加的和。
private struct LineFit {
    /// x 的方差低于这个值时视为 x 全都相同：两组样本的 x 只差 8 位量化的一级（1/255）时，方差约为 3.8e-6。
    private static let minimumVariance = 1e-6

    /// 样本数。
    private var count = 0.0

    /// 样本 x 之和。
    private var sumX = 0.0

    /// 样本 y 之和。
    private var sumY = 0.0

    /// 样本 x² 之和。
    private var sumXX = 0.0

    /// 样本 x × y 之和。
    private var sumXY = 0.0

    /// 拟合出的直线；没有样本或样本的 x 全都相同、定不出斜率时，截距与斜率都记为 0。
    var line: (offset: Double, slope: Double) {
        let denominator = count * sumXX - sumX * sumX

        // x 全都相同时分母只剩舍入误差，算出的斜率没有意义。
        guard count > 0, denominator / (count * count) > Self.minimumVariance else {
            return (0, 0)
        }

        let slope = (count * sumXY - sumX * sumY) / denominator
        return ((sumY - slope * sumX) / count, slope)
    }

    /// 加入一个样本。
    mutating func add(x: Double, y: Double) {
        count += 1
        sumX += x
        sumY += y
        sumXX += x * x
        sumXY += x * y
    }
}
