import AppKit
import SpookyKit
import SwiftUI
import Testing

@testable import Spooky

/// 摘要与内联警告直接测量生产视图，不创建窗口或发送辅助功能输入。
@MainActor
struct DiffSummaryLayoutTests {
    /// 原生字体测量需要完整的 AppKit 应用环境。
    init() { _ = NSApplication.shared }

    /// 固定字体、颜色、边距与行高独立于正文主题，文字仍可选中复制；长路径自然折行，不追加末尾换行，原生 Copy 保留完整路径与实际换行。
    @Test("文件头摘要的实际布局、换行与复制")
    func header() throws {
        for lines in [1, 3] {
            try expectHeader(lines: lines)
        }

        // 长路径折行
        let view = DiffFileHeaderView()
        let text = "File renamed from " + String(repeating: "directory/", count: 20) + "old to new\nSecond line"
        view.show(text)
        let wide = view.measure(width: 1800)
        let narrow = view.measure(width: 300)
        #expect(narrow > wide)
        #expect((narrow - 37).truncatingRemainder(dividingBy: 19) == 0)
        #expect(view.document.string == text)

        view.frame = CGRect(x: 0, y: 0, width: 300, height: narrow)
        view.layoutSubtreeIfNeeded()

        // 原生 Copy
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        view.document.setSelectedRange(NSRange(location: 0, length: text.utf16.count))
        let type = try #require(view.document.writablePasteboardTypes.first)
        pasteboard.declareTypes([type], owner: nil)
        #expect(view.document.selectedRange().length == text.utf16.count)
        #expect(view.document.writeSelection(to: pasteboard, type: type))
        #expect(pasteboard.string(forType: type) == text)
    }

    /// 两侧占宽不相等、左侧有刷新内容或摘要很长时，仍只压缩居中的摘要。
    @Test("Diff 底栏摘要对齐整栏")
    func bottomBar() {
        for width in [300.0, 480, 800] {
            for left in [64.0, 84] {
                let sizes = [
                    CGSize(width: left, height: 20),
                    CGSize(width: 600, height: 13),
                    CGSize(width: 110, height: 20),
                ]

                let frames = DiffBottomBarLayout.frames(width: width, sizes: sizes)
                #expect(frames[1].midX == CGFloat(width / 2))
                #expect(frames[1].midY == 16)
                #expect(frames[0].width == left && frames[2].width == 110)
                #expect(frames[1].minX >= frames[0].maxX + 8)
                #expect(frames[1].maxX <= frames[2].minX - 8)
            }
        }
    }

    /// 八语言标题在窄栏自然增高，实际按钮仍位于当前文件单元格之内。
    @Test("内联大 Diff 警告包含完整按钮")
    func inlineWarning() throws {
        let width = 300.0

        for language in AppLocalization.languages {
            let url = try #require(AppLocalization.bundle.url(forResource: language, withExtension: "lproj"))
            let bundle = try #require(Bundle(url: url))
            let title = bundle.localizedString(forKey: "working.largeDiff", value: nil, table: nil)
            let label = bundle.localizedString(forKey: "working.showDiff", value: nil, table: nil)

            var pressed = false

            let root = EmptyStateView(title: title, message: "", symbol: nil, fitsContent: true) {
                EmptyStateButton(label) { pressed = true }
            }
            .frame(width: width)

            let hosting = NSHostingView(rootView: root)
            hosting.frame.size = hosting.fittingSize
            hosting.layoutSubtreeIfNeeded()

            let button = try #require(buttons(in: hosting).first)
            let frame = button.convert(button.bounds, to: hosting)
            #expect(frame.minY >= -1 && frame.maxY <= hosting.bounds.height + 1, "\(language) button \(frame)")
            #expect(frame.minX >= 0 && frame.maxX <= width)
            #expect(hosting.bounds.height >= 180)

            button.performClick(nil)
            #expect(pressed)
        }
    }

    /// 按给定行数显示摘要，核对高度、边距、字体与重设文字后保留的选区。
    private func expectHeader(lines: Int) throws {
        let view = DiffFileHeaderView()
        let text = Array(repeating: "Summary", count: lines).joined(separator: "\n")
        view.show(text)
        let height = view.measure(width: 500)
        #expect(height == CGFloat(37 + (lines - 1) * 19))

        view.frame = CGRect(x: 0, y: 0, width: 500, height: height)
        view.layoutSubtreeIfNeeded()
        #expect(view.document.frame.minX == 20)
        #expect(view.document.frame.minY == 8)
        #expect(view.document.frame.width == 460)
        #expect(view.document.textContainer?.lineFragmentPadding == 0)
        #expect(view.document.isSelectable && !view.document.isEditable)
        #expect(!view.document.drawsBackground)

        let attributes = try #require(view.document.textStorage?.attributes(at: 0, effectiveRange: nil))
        #expect((attributes[.font] as? NSFont)?.pointSize == 11)
        #expect(attributes[.foregroundColor] as? NSColor == .secondaryLabelColor)

        // 同一文字重新显示不清掉选区
        view.document.setSelectedRange(NSRange(location: 0, length: text.utf16.count))
        view.show(text)
        #expect(view.document.selectedRange().length == text.utf16.count)
    }

    /// 只查询当前宿主树，不访问桌面辅助功能层级。
    private func buttons(in view: NSView) -> [NSButton] {
        view.subviews.flatMap { [$0 as? NSButton].compactMap(\.self) + buttons(in: $0) }
    }
}
