import AppKit
import SwiftUI
import Testing

@testable import Spooky

// MARK: - CommitMessageEditorTests

/// 提交信息的文本视图：正文的两种折行方式，以及标题框收到多行文字时的写入。
@MainActor
struct CommitMessageEditorTests {
    /// 软折行按视图宽度折行、只标出超出上限的部分；切到硬折行后正文不折行、可以横向滚动，超长的行整行铺警告底色；
    /// 切回软折行后回到可见宽度。
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

    /// 标题框只有一行：整段提交信息贴进去时，换行不能写进标题，其余的行也不能丢，要接到已有正文的后面；
    /// 不含换行的文字照常写入，不动正文。
    @Test("贴进标题框的多行文字第一行留在标题，其余接到正文后面")
    func multilineSubjectInput() throws {
        let session = RepositorySession()
        session.commitBody = "已有的正文"

        let host = NSHostingView(rootView: WorkingCopyCommitView(session: session))
        host.frame = NSRect(x: 0, y: 0, width: 480, height: 400)
        host.layoutSubtreeIfNeeded()

        let subject = try #require(
            SettingsWindowTests.subviews(CommitMessageTextView.self, in: host)
                .first { $0.accessibilityIdentifier() == "commit-subject" }
        )

        // 不含换行的文字照常写入
        subject.insertText("fix:  done", replacementRange: NSRange(location: 0, length: 0))
        #expect(session.commitSubject == "fix:  done")
        #expect(session.commitBody == "已有的正文")

        // 粘贴走的是从剪贴板读入选区；用单独的剪贴板，不碰系统的那一块
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        pasteboard.setString("第一行\n\n第二行\n第三行", forType: .string)
        subject.setSelectedRange(NSRange(location: 5, length: 0))

        // 多行文字的第一行写在光标处，其余的行另起一行接到正文后面
        #expect(subject.readSelection(from: pasteboard, type: .string))
        #expect(subject.string == "fix: 第一行 done")
        #expect(session.commitSubject == "fix: 第一行 done")
        #expect(session.commitBody == "已有的正文\n第二行\n第三行")
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
