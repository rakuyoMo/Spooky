// 生成 Spooky 的静态应用图标：按 macOS 图标网格绘制矢量图形，导出全部尺寸后由 iconutil 合成 .icns。
//
// 用法：swift scripts/make-icon.swift <输出的 .icns 路径>

import AppKit

/// 图标网格的边长，所有坐标都在这一尺寸下给出，导出时按比例缩放。
let canvas: CGFloat = 1024

/// iconset 需要的文件名与像素尺寸。
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

/// sRGB 颜色的简写。
func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

/// 在 1024 网格中绘制完整图标：夜色圆角底板、幽灵与它的影子。
func draw(in context: CGContext) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // 底板沿用 macOS 图标网格：824 pt 圆角方块，下方带柔和投影。
    let plate = CGPath(
        roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
        cornerWidth: 185,
        cornerHeight: 185,
        transform: nil
    )

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0, 0, 0, 0.35))
    context.addPath(plate)
    context.setFillColor(color(42, 34, 114))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(plate)
    context.clip()
    let night = CGGradient(
        colorsSpace: space,
        colors: [color(110, 94, 230), color(42, 34, 114)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(night, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // 幽灵脚下的影子让造型浮在底板上。
    context.setShadow(offset: .zero, blur: 24, color: color(10, 6, 40, 0.55))
    context.setFillColor(color(10, 6, 40, 0.35))
    context.fillEllipse(in: CGRect(x: 342, y: 168, width: 340, height: 44))
    context.restoreGState()

    // 幽灵：半圆头部、竖直两侧，底边由四个向下的圆弧组成。
    let ghost = CGMutablePath()
    ghost.move(to: CGPoint(x: 297, y: 600))
    ghost.addLine(to: CGPoint(x: 297, y: 300))

    for index in 0..<4 {
        let start = 297 + 107.5 * CGFloat(index)
        ghost.addQuadCurve(
            to: CGPoint(x: start + 107.5, y: 300),
            control: CGPoint(x: start + 53.75, y: 214)
        )
    }

    ghost.addLine(to: CGPoint(x: 727, y: 600))
    ghost.addArc(center: CGPoint(x: 512, y: 600), radius: 215, startAngle: 0, endAngle: .pi, clockwise: false)
    ghost.closeSubpath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: color(10, 6, 40, 0.45))
    context.addPath(ghost)
    context.setFillColor(color(255, 255, 255))
    context.fillPath()
    context.restoreGState()

    // 身体自上而下略微变暗，表现体积。
    context.saveGState()
    context.addPath(ghost)
    context.clip()
    let body = CGGradient(
        colorsSpace: space,
        colors: [color(255, 255, 255), color(226, 222, 246)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(body, start: CGPoint(x: 512, y: 815), end: CGPoint(x: 512, y: 214), options: [])
    context.restoreGState()

    // 两只眼睛使用底板的深色。
    context.setFillColor(color(43, 34, 102))
    context.fillEllipse(in: CGRect(x: 412, y: 520, width: 56, height: 80))
    context.fillEllipse(in: CGRect(x: 556, y: 520, width: 56, height: 80))
}

/// 以给定像素尺寸渲染 PNG。
func render(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    let context = graphics.cgContext
    context.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    draw(in: context)
    graphics.flushGraphics()
    return bitmap.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift scripts/make-icon.swift <output.icns>\n".utf8))
    exit(64)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = FileManager.default.temporaryDirectory
    .appending(path: "Spooky-" + UUID().uuidString + ".iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: false)

for variant in variants {
    try render(pixels: variant.pixels).write(to: iconset.appending(path: variant.name + ".png"))
}

// iconutil 按文件名识别各尺寸，合成单个 .icns；临时 iconset 在退出前删除。
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(process.terminationStatus)
