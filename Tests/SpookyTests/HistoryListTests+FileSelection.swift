import AppKit
import Foundation
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - FileSelection

extension HistoryListTests {
    /// 变更文件行的选区：单击、⇧ 单击、⌘ 单击、↑ ↓ 与 ⇧ ↑ ↓ 各自从哪一行开始、选到哪一行，变更集重读后去掉不在的文件。
    @Test("变更文件行的点选与方向键")
    func fileSelection() {
        let order = ["a", "b", "c", "d", "e"]

        // 还没有点过时，↓ 从第一行开始，↑ 从最后一行开始
        var down = ChangesetFileSelection()
        down.move(by: 1, extending: false, order: order)
        #expect(down.paths == ["a"])

        var up = ChangesetFileSelection()
        up.move(by: -1, extending: true, order: order)
        #expect(up.paths == ["e"])

        // 单击选中一行；⇧ 单击从这一行连续选到点中的行，再按 ⇧ 单击时从同一个锚点重新算
        var selection = ChangesetFileSelection()
        selection.click("b", extending: false, toggling: false, order: order)
        #expect(selection.paths == ["b"])

        selection.click("d", extending: true, toggling: false, order: order)
        #expect(selection.paths == ["b", "c", "d"])

        selection.click("a", extending: true, toggling: false, order: order)
        #expect(selection.paths == ["a", "b"])

        // ⌘ 单击只切换点中的那一行
        selection.click("d", extending: false, toggling: true, order: order)
        #expect(selection.paths == ["a", "b", "d"])

        selection.click("a", extending: false, toggling: true, order: order)
        #expect(selection.paths == ["b", "d"])

        // ↓ 从最近点中的行移到下一行，只选中它；⇧ ↓ ⇧ ↑ 从这一行连续选到移到的行
        selection.move(by: 1, extending: false, order: order)
        #expect(selection.paths == ["b"])

        selection.move(by: 1, extending: true, order: order)
        selection.move(by: 1, extending: true, order: order)
        #expect(selection.paths == ["b", "c", "d"])

        selection.move(by: -1, extending: true, order: order)
        selection.move(by: -1, extending: true, order: order)
        selection.move(by: -1, extending: true, order: order)
        #expect(selection.paths == ["a", "b"])

        // 到了第一行或最后一行就停在那里
        selection.move(by: -1, extending: false, order: order)
        #expect(selection.paths == ["a"])

        selection.click("e", extending: false, toggling: false, order: order)
        selection.move(by: 1, extending: false, order: order)
        #expect(selection.paths == ["e"])

        // 重读后锚点不在了：只留下仍在的文件，⇧ ↓ 按不带 ⇧ 从第一行开始
        selection.click("c", extending: false, toggling: true, order: order)
        #expect(selection.paths == ["c", "e"])

        var retained = selection.retaining(["a", "b", "e"])
        #expect(retained.paths == ["e"])

        retained.move(by: 1, extending: true, order: ["a", "b", "e"])
        #expect(retained.paths == ["a"])
    }

    /// 选中文件行不展开它，展开与 Expand All 不改选区，换选提交时选区清空。
    @Test("变更文件行的选区与展开分开")
    func fileSelectionLifecycle() async throws {
        let fixture = try await Self.makeSession(commits: ["a", "b", "c"])
        defer { fixture.close() }

        let history = fixture.session.history
        let commits = history.commits

        history.selectedIDs = [commits[1].id]
        await untilFinished { history.activeTasks }

        let order = history.changes.map(\.path)
        #expect(order == ["file.txt"])

        // 选中不展开
        history.fileSelection.click("file.txt", extending: false, toggling: false, order: order)
        #expect(history.fileSelection.paths == ["file.txt"])
        #expect(history.expandedPaths.isEmpty)

        // Expand All 展开与收起都不改选区
        history.expandAll(true)
        #expect(history.expandedPaths == ["file.txt"])
        #expect(history.fileSelection.paths == ["file.txt"])

        history.expandAll(false)
        #expect(history.fileSelection.paths == ["file.txt"])

        // 换选提交时清空
        history.selectedIDs = [commits[2].id]
        #expect(history.fileSelection == ChangesetFileSelection())

        await untilFinished { history.activeTasks }
    }

    /// 选中的文件行填满上下两条分隔线之间的整行，左右到列表边缘、直角；展开时只垫在文件行下面，不延伸到 Diff。
    @Test("变更文件行选中底的范围")
    func fileRowSelectionFill() throws {
        let collapsed = try Self.renderFileRow(expanded: false)
        let rows = try #require(Self.selectedRows(in: collapsed, x: collapsed.pixelsWide / 2))

        // 收起时从上面的分隔线下方一直填到下面的分隔线上方，两条线各 1 pt
        #expect(rows == 2 ..< collapsed.pixelsHigh - 2)

        // 左右两边到边缘，四角不留圆角
        #expect(Self.selectedRows(in: collapsed, x: 0) == rows)
        #expect(Self.selectedRows(in: collapsed, x: collapsed.pixelsWide - 1) == rows)

        // 展开时选中底的高度不变，下面的 Diff 不垫
        let expanded = try Self.renderFileRow(expanded: true)

        #expect(Self.selectedRows(in: expanded, x: expanded.pixelsWide / 2) == rows)
        #expect(expanded.pixelsHigh > collapsed.pixelsHigh)
    }

    /// 文件行里三角以外的任何位置都算点在这一行上：行的上下边缘、三角的上下左右、文件名一栏与右侧的空白；
    /// 点三角只切换展开，不点选。文件名一栏与提交详情里一样带右键菜单与拖动。
    @Test("变更文件行整行都能点选")
    func fileRowClickTargets() async throws {
        var clicks = 0
        var expanded = false

        let row = ChangesetFileRow(
            isExpanded: Binding(
                get: { expanded },
                set: { expanded = $0 }
            ),
            selection: nil,
            select: { clicks += 1 }
        ) {
            Text("file.txt")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .contextMenu { Button("Open") { } }
                .onDrag { NSItemProvider() }
        } diff: {
            Color.clear.frame(height: 20)
        }

        let host = ClickableHostingView(rootView: row.frame(width: 200))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)

        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }

        host.layoutSubtreeIfNeeded()

        let height = host.bounds.height
        let middle = height / 2

        // 行的上下边缘、三角的左侧与上下、三角与文件名一栏之间、文件名一栏、右侧的空白
        let targets = [
            CGPoint(x: 100, y: 1),
            CGPoint(x: 100, y: height - 1),
            CGPoint(x: 2, y: middle),
            CGPoint(x: 11, y: 2),
            CGPoint(x: 11, y: height - 2),
            CGPoint(x: 19, y: middle),
            CGPoint(x: 100, y: middle),
            CGPoint(x: 198, y: middle),
        ]

        for (index, target) in targets.enumerated() {
            try Self.click(at: target, in: host)
            await until { clicks == index + 1 }
        }

        // 三角是 AppKit 的按钮，点在它上面由它自己接收：展开，不点选
        let center = host.convert(CGPoint(x: 11, y: middle), to: host.superview)
        let triangle = try #require(host.hitTest(center) as? NSButton)

        triangle.performClick(nil)

        #expect(expanded)
        #expect(clicks == targets.count)

        // 展开后点在文件行上照样点选
        try Self.click(at: CGPoint(x: 2, y: 1), in: host)
        await until { clicks == targets.count + 1 }
    }
}

// MARK: - Steps

extension HistoryListTests {
    /// 按 2 倍像素画出夹在两条分隔线之间、选中的一个文件行，选中底是红色。
    ///
    /// - Parameter expanded: 文件行是否展开。
    private static func renderFileRow(expanded: Bool) throws -> NSBitmapImageRep {
        let content = VStack(spacing: 0) {
            Divider()

            ChangesetFileRow(
                isExpanded: .constant(expanded),
                selection: .systemRed,
                select: { }
            ) {
                Color.clear
            } diff: {
                Color.clear.frame(height: 20)
            }

            Divider()
        }
        .frame(width: 200)

        let host = NSHostingView(rootView: content)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()

        return try RenderedPixels(view: host).bitmap
    }

    /// 在 `point`（pt，视图左上角为原点）处按下再松开左键，经窗口发给视图。
    ///
    /// 只用于点在 SwiftUI 视图上：AppKit 的按钮按下后在自己的跟踪循环里等真实的松开，不能这样点。
    ///
    /// - Parameters:
    ///   - point: 点击的位置。
    ///   - view: 点击所在的视图，已放进窗口。
    private static func click(at point: CGPoint, in view: NSView) throws {
        let window = try #require(view.window)
        let location = view.convert(point, to: nil)

        window.sendEvent(try mouseEvent(.leftMouseDown, at: location, in: window))
        window.sendEvent(try mouseEvent(.leftMouseUp, at: location, in: window))
    }

    /// 窗口里 `location` 处的一次左键事件。
    ///
    /// - Parameters:
    ///   - type: 按下或松开。
    ///   - location: 窗口坐标。
    ///   - window: 事件所在的窗口。
    private static func mouseEvent(
        _ type: NSEvent.EventType,
        at location: NSPoint,
        in window: NSWindow
    ) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type,
                location: location,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
    }

    /// `x` 这一列上选中底覆盖的像素行；不连续时为 nil。
    ///
    /// - Parameters:
    ///   - bitmap: 画出的文件行。
    ///   - x: 像素列。
    private static func selectedRows(in bitmap: NSBitmapImageRep, x: Int) -> Range<Int>? {
        let red = (0 ..< bitmap.pixelsHigh).filter { y in
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
                return false
            }

            return color.alphaComponent > 0.9 && color.redComponent > 0.8 && color.greenComponent < 0.5
        }

        guard let first = red.first, let last = red.last, red.count == last - first + 1 else {
            return nil
        }

        return first ..< last + 1
    }
}

// MARK: - ClickableHostingView

/// 第一下点击也交给 SwiftUI 视图的托管视图。
///
/// 测试进程的窗口成不了 key，点在里面的第一下默认只用来激活窗口；接受第一下点击后，点击的结果与 App 里点 key 窗口相同。
private final class ClickableHostingView<Content: View>: NSHostingView<Content> {
    /// 总是接受。
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }
}
