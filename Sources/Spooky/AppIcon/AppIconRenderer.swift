import AppKit

// MARK: - AppIconRenderer

/// 运行时 App 图标的合成：让 Dock 画出的运行时图标与它画包内图标的样子一致。
///
/// 默认与深色样式下，Dock 把包内图标画成系统处理过的样子（裁成系统的圆角形状、加上亮边与阴影），
/// 运行时设置的图标则原样画出，而且画得小一圈（macOS 27 实测）。
enum AppIconRenderer {
    /// 运行时图标的内容放大的倍数，抵消 Dock 把运行时图标画小的那一圈。
    ///
    /// 按 macOS 27 默认 Dock 尺寸下的 2× 截图，与只带同一张 icns 的 App 的 Dock 图标逐像素对照，取差别最小的倍数。
    static let dockScale = 1.0125

    /// 合成运行时图标：以系统处理过的包内图标为底，叠上目标图标与包内图标的差别，再按 `dockScale` 放大。
    ///
    /// 目标图标与包内图标只有指示灯不同时，结果只有指示灯与系统的处理结果不同。
    /// 系统处理过的图标里亮边比白色还亮，所以在扩展 sRGB 的浮点位图里逐像素相加，超出 1 的部分才放得下。
    /// - Parameters:
    ///   - system: 系统处理过的包内图标，即 `NSWorkspace` 给出的 App 图标
    ///   - bundled: 包内图标
    ///   - target: 要换上的图标，与包内图标同样大小、同一个形状
    /// - Returns: 运行时图标，像素尺寸与 system 相同；建不起位图上下文时为 nil
    static func runtimeIcon(
        system: CGImage,
        bundled: CGImage,
        target: CGImage
    ) -> CGImage? {
        let width = system.width
        let height = system.height
        let rect = scaledRect(width: width, height: height)

        guard
            let scaledSystem = scaledSystemImage(system, in: rect),
            let output = floatBitmap(width: width, height: height, bitsPerComponent: 32),
            let bundledBitmap = byteBitmap(of: bundled, in: rect, width: width, height: height),
            let targetBitmap = byteBitmap(of: target, in: rect, width: width, height: height),
            let outputData = output.data,
            let bundledData = bundledBitmap.data,
            let targetData = targetBitmap.data
        else {
            return nil
        }

        // 尺寸相同，原样拷进 32 位浮点位图逐像素计算。
        output.draw(scaledSystem, in: CGRect(x: 0, y: 0, width: width, height: height))

        let count = width * height * 4
        let outputPixels = outputData.bindMemory(to: Float.self, capacity: count)
        let bundledPixels = bundledData.bindMemory(to: UInt8.self, capacity: count)
        let targetPixels = targetData.bindMemory(to: UInt8.self, capacity: count)

        // 预乘透明度的分量直接相加；透明度夹在 0–1，颜色不小于 0，亮边超出 1 的部分保留。
        for index in 0 ..< count {
            let difference = (Float(targetPixels[index]) - Float(bundledPixels[index])) / 255
            let value = max(outputPixels[index] + difference, 0)
            outputPixels[index] = index % 4 == 3 ? min(value, 1) : value
        }

        return output.makeImage()
    }
}

// MARK: - Private

extension AppIconRenderer {
    /// 图标按 `dockScale` 放大后在位图里的位置：以位图中心为中心。
    /// - Parameters:
    ///   - width: 位图宽度
    ///   - height: 位图高度
    private static func scaledRect(
        width: Int,
        height: Int
    ) -> CGRect {
        let scaledWidth = Double(width) * dockScale
        let scaledHeight = Double(height) * dockScale

        return CGRect(
            x: (Double(width) - scaledWidth) / 2,
            y: (Double(height) - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )
    }

    /// 把系统处理过的图标按 `dockScale` 放大，画进 16 位浮点位图；建不起位图时为 nil。
    ///
    /// 这张图标带着高于白色的亮度余量，画进 8 位位图会被整体压暗（白色 255 → 249），画进扩展 sRGB 的浮点位图才原样保留。
    /// 缩放放在 16 位浮点位图里做：同样的缩放在 32 位浮点位图里做，Dock 里与包内图标的差别更大（2× 截图实测）。
    /// - Parameters:
    ///   - image: 系统处理过的图标
    ///   - rect: 画在位图里的位置
    private static func scaledSystemImage(
        _ image: CGImage,
        in rect: CGRect
    ) -> CGImage? {
        guard
            let context = floatBitmap(
                width: image.width,
                height: image.height,
                bitsPerComponent: 16
            )
        else {
            return nil
        }

        context.draw(image, in: rect)
        return context.makeImage()
    }

    /// 浮点、预乘透明度的扩展 sRGB 位图：分量可以大于 1；建不起时为 nil。
    /// - Parameters:
    ///   - width: 位图宽度
    ///   - height: 位图高度
    ///   - bitsPerComponent: 每个分量的位数，32 或 16
    private static func floatBitmap(
        width: Int,
        height: Int,
        bitsPerComponent: Int
    ) -> CGContext? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB) else {
            return nil
        }

        let byteOrder: CGImageByteOrderInfo = bitsPerComponent == 16 ? .order16Little : .order32Little

        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: width * bitsPerComponent / 2,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.floatComponents.rawValue
                | byteOrder.rawValue
        )

        context?.interpolationQuality = .high
        return context
    }

    /// 把图标画进 8 位 RGBA、预乘透明度的 sRGB 位图；建不起时为 nil。
    /// - Parameters:
    ///   - image: 要画的图标
    ///   - rect: 画在位图里的位置
    ///   - width: 位图宽度
    ///   - height: 位图高度
    private static func byteBitmap(
        of image: CGImage,
        in rect: CGRect,
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

        context.interpolationQuality = .high
        context.draw(image, in: rect)
        return context
    }
}
