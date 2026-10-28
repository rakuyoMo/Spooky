import AppKit
import Testing

@testable import Spooky

// MARK: - CommitMessageEditorTests

/// 提交正文的折行方式：软折行按视图宽度折行、只标出超出上限的部分；硬折行只改显示，不折行、超长的行整行标出。
@MainActor
struct CommitMessageEditorTests {
    /// 切到硬折行后正文不折行、可以横向滚动，超长的行整行铺警告底色；切回软折行后回到可见宽度。
    @Test("硬折行不折行，超长的行整行标出")
    func hardWrapDisplay() throws {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let text = CommitMessageTextView(usingTextLayoutManager: false)
        text.isVerticallyResizable = true
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.autoresizingMask = [.width]
        scroll.documentView = text
        text.frame = NSRect(origin: .zero, size: scroll.contentSize)
        text.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        text.string = "short\n" + String(repeating: "x", count: 100)
        text.characterLimit = 10

        let layoutManager = try #require(text.layoutManager)
        let container = try #require(text.textContainer)
        var range = NSRange()

        // 软折行：超出上限的部分铺底色，长行按视图宽度折成多行
        #expect(layoutManager.temporaryAttribute(.backgroundColor, atCharacterIndex: 6, effectiveRange: nil) == nil)
        #expect(layoutManager.temporaryAttribute(.backgroundColor, atCharacterIndex: 16, effectiveRange: nil) != nil)
        #expect(Self.lineCount(layoutManager, container) > 2)

        text.hardWrap = true
        #expect(text.isHorizontallyResizable)
        #expect(scroll.hasHorizontalScroller)
        #expect(!container.widthTracksTextView)
        #expect(Self.lineCount(layoutManager, container) == 2)
        #expect(layoutManager.temporaryAttribute(.backgroundColor, atCharacterIndex: 0, effectiveRange: nil) == nil)
        #expect(
            layoutManager.temporaryAttribute(
                .backgroundColor,
                atCharacterIndex: 6,
                longestEffectiveRange: &range,
                in: NSRange(location: 0, length: text.string.utf16.count)
            ) != nil
        )
        #expect(range == NSRange(location: 6, length: 100))

        text.hardWrap = false
        #expect(!text.isHorizontallyResizable)
        #expect(container.widthTracksTextView)
        #expect(text.frame.width == scroll.contentSize.width)
    }
}

// MARK: - Helpers

extension CommitMessageEditorTests {
    /// 排版后的行数。
    private static func lineCount(_ layoutManager: NSLayoutManager, _ container: NSTextContainer) -> Int {
        layoutManager.ensureLayout(for: container)

        var count = 0
        let glyphs = layoutManager.glyphRange(for: container)

        layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { _, _, _, _, _ in count += 1 }
        return count
    }
}
