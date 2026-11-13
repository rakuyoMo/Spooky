import AppKit
import Foundation
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Selection

extension HistoryListTests {
    /// 选中底的颜色随焦点与窗口状态变化：窗口是 key 时，列表有焦点用强调色、没有焦点用未强调的选中色；
    /// 窗口不是 key 时不看焦点，一律取未强调的选中色与列表底色各半。
    /// 形状保持系统的 inset 样式：左右各缩进 10 pt、四角圆角，相邻的选中行连成一片。
    @Test("历史列表的选中底")
    func rowSelection() async throws {
        let fixture = try await Self.makeSession(commits: ["a", "b", "c"])
        defer { fixture.close() }

        let history = fixture.session.history
        history.rows = history.commits.map { .commit($0) }

        // 窗口是 key 时只看列表有没有焦点
        let background = NSColor.controlBackgroundColor

        #expect(
            HistoryRowView.selectionColor(emphasized: true, key: true, background: background)
                == .controlAccentColor
        )

        #expect(
            HistoryRowView.selectionColor(emphasized: false, key: true, background: background)
                == .unemphasizedSelectedContentBackgroundColor
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        defer { window.close() }

        // 测试窗口当不了 key window：列表有焦点时，选中的第一行也画成未强调的选中色与底色各半
        let rows = try await Self.rowViews(in: window, session: fixture.session, small: true)
        let table = try #require(rows[0].superview as? NSTableView)

        #expect(window.makeFirstResponder(table))
        table.selectRowIndexes([0], byExtendingSelection: false)

        let expected = try Self.inactiveSelectionPixel(of: table)
        let single = try Self.selectionPixels(of: rows[0])
        let middle = single.height / 2

        // 左右各缩进 10 pt，四角是圆角
        try Self.expectPixel(single, x: 5, y: middle, isClear: true)
        try Self.expectPixel(single, x: single.width - 5, y: middle, isClear: true)
        try Self.expectPixel(single, x: 10.5, y: 0.5, isClear: true)
        try Self.expectPixel(single, x: 10.5, y: single.height - 0.5, isClear: true)
        try Self.expectPixel(single, x: 10.5, y: middle, color: expected)
        try Self.expectPixel(single, x: single.width / 2, y: middle, color: expected)
        try Self.expectPixel(single, x: single.width - 10.5, y: middle, color: expected)

        // 相邻两行都选中时，相接的一边不留圆角
        table.selectRowIndexes([0, 1], byExtendingSelection: false)

        let upper = try Self.selectionPixels(of: rows[0])
        let lower = try Self.selectionPixels(of: rows[1])

        try Self.expectPixel(upper, x: 10.5, y: 0.5, isClear: true)
        try Self.expectPixel(upper, x: 10.5, y: upper.height - 0.5, color: expected)
        try Self.expectPixel(lower, x: 10.5, y: 0.5, color: expected)
        try Self.expectPixel(lower, x: 10.5, y: lower.height - 0.5, isClear: true)
    }
}

// MARK: - Steps

extension HistoryListTests {
    /// 只画出一行的选中底：单元格与分隔线先藏起来，画完放回。
    private static func selectionPixels(of row: HistoryRowView) throws -> RenderedPixels {
        let cell = try #require(row.view(atColumn: 0) as? NSView)

        cell.isHidden = true
        row.separator.isHidden = true

        defer {
            cell.isHidden = false
            row.separator.isHidden = row.separatorInset == nil
        }

        return try RenderedPixels(view: row)
    }

    /// 窗口不是 key 时的选中色画出来的像素：按列表的外观取色，填满一块色板后经同样的方式画出。
    private static func inactiveSelectionPixel(of table: NSTableView) throws -> NSColor {
        var resolved: NSColor? = nil

        table.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = HistoryRowView.selectionColor(
                emphasized: true,
                key: false,
                background: table.backgroundColor
            )
        }

        let swatch = ColorSwatch(color: try #require(resolved))

        return try #require(RenderedPixels(view: swatch).color(x: 2, y: 2))
    }

    /// `(x, y)`（pt，左上角为原点）处是透明，或是与 `color` 相差不到两个色阶的不透明颜色。
    private static func expectPixel(
        _ pixels: RenderedPixels,
        x: CGFloat,
        y: CGFloat,
        isClear: Bool = false,
        color: NSColor? = nil
    ) throws {
        let pixel = try #require(pixels.color(x: x, y: y))

        if isClear {
            #expect(pixel.alphaComponent < 0.05, "(\(x), \(y))")
            return
        }

        let expected = try #require(color)
        let tolerance = 2.0 / 255

        #expect(pixel.alphaComponent > 0.95, "(\(x), \(y))")
        #expect(abs(pixel.redComponent - expected.redComponent) <= tolerance, "(\(x), \(y))")
        #expect(abs(pixel.greenComponent - expected.greenComponent) <= tolerance, "(\(x), \(y))")
        #expect(abs(pixel.blueComponent - expected.blueComponent) <= tolerance, "(\(x), \(y))")
    }
}

// MARK: - RenderedPixels

/// 按 2 倍像素画出的视图，按 pt 坐标取色；经同一种位图画出的颜色可以直接比较。
@MainActor
struct RenderedPixels {
    /// 视图画出的位图。
    let bitmap: NSBitmapImageRep

    /// 视图的尺寸（pt）。
    let size: NSSize

    /// 视图的宽（pt）。
    var width: CGFloat { size.width }

    /// 视图的高（pt）。
    var height: CGFloat { size.height }

    /// 把视图画进一张 2 倍像素的位图；视图之外与没画到的地方是透明的。
    ///
    /// - Parameter view: 已排好版的视图。
    init(view: NSView) throws {
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(view.bounds.width) * 2,
                pixelsHigh: Int(view.bounds.height) * 2,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )

        bitmap.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: bitmap)

        self.bitmap = bitmap
        size = view.bounds.size
    }

    /// `(x, y)` 处像素的颜色；位图的原点在左上角。
    func color(x: CGFloat, y: CGFloat) -> NSColor? {
        bitmap.colorAt(x: Int(x * 2), y: Int(y * 2))
    }
}

// MARK: - ColorSwatch

/// 填满一种颜色的 4 × 4 pt 色板，作为取色的参照。
private final class ColorSwatch: NSView {
    /// 填充的颜色。
    let color: NSColor

    /// 建立填满 `color` 的色板。
    ///
    /// - Parameter color: 已按外观取好的颜色。
    init(color: NSColor) {
        self.color = color
        super.init(frame: NSRect(x: 0, y: 0, width: 4, height: 4))
    }

    /// 色板只由代码创建。
    required init?(coder _: NSCoder) { nil }

    /// 用 `color` 填满自身。
    override func draw(_: NSRect) {
        color.setFill()
        bounds.fill()
    }
}
