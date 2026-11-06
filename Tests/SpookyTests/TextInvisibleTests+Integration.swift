import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

extension TextInvisibleTests {
    /// 逐行追溯协议补齐的 LF 不能成为原文件的行尾；两种正文都使用同一 blob。
    @Test("真实 blob 与 Blame 共用末行信息", arguments: endings)
    func blame(sample: (String, Int, Int)) async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        try fixture.write(sample.0)
        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-qm", "line endings"])
        let views = RepositoryFileViews(runner: fixture.runner)
        let revision = try await fixture.head()
        let content = try await FileRevisionContent.load("a b.txt", at: revision, views: views)
        let blame = try await views.blame(content.path, at: revision)
        #expect(content.data == Data(sample.0.utf8))
        #expect(content.source == sample.0)
        #expect(blame.lines.map(FileRevisionContent.displayLine) == content.lines)
        let theme = TextTheme.builtin[0]
        var identities: [[Int]] = []
        for lines in [content.lines, blame.lines.map(FileRevisionContent.displayLine)] {
            let document = FileTextDocumentView.make()
            document.show(
                lines,
                source: content.source,
                style: FileTextStyle(theme: theme),
                rendering: TextStyle(theme: theme, tabWidth: 4, showsInvisibles: true),
                spans: nil
            )
            let manager = try #require(document.layoutManager as? TextInvisibleLayoutManager)
            manager.ensureLayout(for: try #require(document.textContainer))
            identities.append(manager.markers(in: NSRange(location: 0, length: manager.numberOfGlyphs)).map(\.characterIndex))
            #expect(document.copiedText(in: NSRange(location: 0, length: document.string.utf16.count)) == sample.0)
        }
        #expect(identities[0] == identities[1])
    }

    /// 原文视图的标记开关与单独编辑标记色都通过真实桥接更新，不改变复制源。
    @Test("原文视图即时更新标记和主题色")
    func fileView() async throws {
        let root = try ThemeStoreTests.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = try #require(UserDefaults(suiteName: root.appending(path: "file-defaults").path))
        defaults.set(false, forKey: TextPreferences.syntaxColoringKey)
        let source = "a\t b\r\nc\n"
        let lines = FileRevisionContent.displayLines(Data(source.utf8))
        var theme = TextTheme.builtin[0]
        let host = NSHostingView(rootView: FileTextView(
            contentID: "file",
            path: "file.txt",
            lines: lines,
            source: source,
            theme: theme
        ).defaultAppStorage(defaults))
        host.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        let helper = DiffHeaderTests()
        await helper.settle(host)
        let document = try #require(helper.descendants(FileTextDocumentView.self, in: host).first)
        let manager = try #require(document.layoutManager as? TextInvisibleLayoutManager)
        defaults.set(true, forKey: TextPreferences.showsInvisiblesKey)
        try await FileViewsTests.wait {
            host.layoutSubtreeIfNeeded()
            return document.rendering?.showsInvisibles ?? false
        }
        theme.colors["invisible"] = PaletteColor(hex: "#123456", alpha: 0.8)
        host.rootView = FileTextView(contentID: "file", path: "file.txt", lines: lines, source: source, theme: theme)
            .defaultAppStorage(defaults)
        await helper.settle(host)
        manager.ensureLayout(for: try #require(document.textContainer))
        let marks = manager.markers(in: NSRange(location: 0, length: manager.numberOfGlyphs))
        #expect(marks.filter { $0.text.string == "¬" }.count == 1)
        #expect(!marks.isEmpty)
        #expect(
            marks
                .allSatisfy {
                    $0.text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == theme.colors["invisible"]?
                        .calibratedNSColor
                }
        )
        #expect(document.copiedText(in: NSRange(location: 0, length: document.string.utf16.count)) == source)
        #expect(host.window == nil)
    }

    /// 实际 Themes 入口使用已有的偏好并即时重画，测试存储和偏好都位于独立临时目录。
    @Test("Themes 预览即时跟随不可见字符偏好")
    func preview() async throws {
        let root = try ThemeStoreTests.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try ThemeStoreTests.store(in: root)
        let defaults = try #require(UserDefaults(suiteName: root.appending(path: "preview-defaults").path))
        let host = NSHostingView(rootView: ThemesSettingsView(store: store).defaultAppStorage(defaults))
        host.frame = NSRect(x: 0, y: 0, width: 900, height: 800)
        let helper = DiffHeaderTests()
        await helper.settle(host)
        let preview = try #require(helper.descendants(DiffHunkTextContainer.self, in: host).first)
        let manager = try #require(preview.document.layoutManager as? TextInvisibleLayoutManager)
        #expect(!(preview.style?.showsInvisibles ?? true))
        #expect(manager.markers(in: NSRange(location: 0, length: manager.numberOfGlyphs)).isEmpty)
        defaults.set(true, forKey: TextPreferences.showsInvisiblesKey)
        try await FileViewsTests.wait {
            host.layoutSubtreeIfNeeded()
            return preview.style?.showsInvisibles ?? false
        }
        let marks = manager.markers(in: NSRange(location: 0, length: manager.numberOfGlyphs))
        #expect(marks.contains { $0.text.string == "·" })
        #expect(marks.filter { $0.text.string == "¬" }.count == preview.content?.rows.count)
        #expect(preview.gutter.readOnly)
        defaults.set(false, forKey: TextPreferences.showsInvisiblesKey)
        try await FileViewsTests.wait {
            host.layoutSubtreeIfNeeded()
            return !(preview.style?.showsInvisibles ?? true)
        }
        #expect(manager.markers(in: NSRange(location: 0, length: manager.numberOfGlyphs)).isEmpty)
        #expect(host.window == nil)
    }
}
