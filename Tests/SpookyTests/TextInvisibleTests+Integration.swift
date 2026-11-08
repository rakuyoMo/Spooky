import AppKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

extension TextInvisibleTests {
    /// 逐行追溯协议补齐的 LF 不能成为原文件的行尾；两种正文都使用同一 blob。
    @Test("真实 blob 与 Blame 共用末行信息")
    func blame() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        let views = RepositoryFileViews(runner: fixture.runner)

        // 空文件、无 LF 末行、CRLF 与混合行尾依次提交到同一文件
        for sample in ["", "a", "a\r\n", "a\r\nb\n\rc"] {
            try fixture.write(sample)
            _ = try await fixture.runner.run(["add", "--all"])
            _ = try await fixture.runner.run(["commit", "-qm", "line endings"])

            let revision = try await fixture.head()
            let content = try await FileRevisionContent.load("a b.txt", at: revision, views: views)
            let blame = try await views.blame(content.path, at: revision)
            let blameLines = blame.lines.map(FileRevisionContent.displayLine)
            #expect(content.data == Data(sample.utf8))
            #expect(content.source == sample)
            #expect(blameLines == content.lines)

            let identities = try [content.lines, blameLines].map { lines in
                try markerIdentities(lines: lines, source: content.source)
            }

            #expect(identities[0] == identities[1])
        }
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

        let view = { (theme: TextTheme) in
            FileTextView(contentID: "file", path: "file.txt", lines: lines, source: source, theme: theme)
                .defaultAppStorage(defaults)
        }

        let host = NSHostingView(rootView: view(theme))
        host.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        let helper = DiffHeaderTests()
        await helper.settle(host)

        let document = try #require(helper.descendants(FileTextDocumentView.self, in: host).first)
        let manager = try #require(document.layoutManager as? TextInvisibleLayoutManager)

        // 打开不可见字符
        defaults.set(true, forKey: TextPreferences.showsInvisiblesKey)

        await until {
            host.layoutSubtreeIfNeeded()
            return document.rendering?.showsInvisibles ?? false
        }

        // 只改标记色
        theme.colors["invisible"] = PaletteColor(hex: "#123456", alpha: 0.8)
        host.rootView = view(theme)
        await helper.settle(host)
        manager.ensureLayout(for: try #require(document.textContainer))

        let marks = manager.markers(in: NSRange(location: 0, length: manager.numberOfGlyphs))
        let invisible = theme.colors["invisible"]?.calibratedNSColor
        #expect(marks.filter { $0.text.string == "¬" }.count == 1)
        #expect(!marks.isEmpty)
        #expect(marks.allSatisfy { mark in
            mark.text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == invisible
        })
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

        // 打开后每行都有 LF 标记
        defaults.set(true, forKey: TextPreferences.showsInvisiblesKey)

        await until {
            host.layoutSubtreeIfNeeded()
            return preview.style?.showsInvisibles ?? false
        }

        let marks = manager.markers(in: NSRange(location: 0, length: manager.numberOfGlyphs))
        #expect(marks.contains { $0.text.string == "·" })
        #expect(marks.filter { $0.text.string == "¬" }.count == preview.content?.rows.count)
        #expect(preview.gutter.readOnly)

        // 关闭后标记清空
        defaults.set(false, forKey: TextPreferences.showsInvisiblesKey)

        await until {
            host.layoutSubtreeIfNeeded()
            return !(preview.style?.showsInvisibles ?? true)
        }

        #expect(manager.markers(in: NSRange(location: 0, length: manager.numberOfGlyphs)).isEmpty)
        #expect(host.window == nil)
    }

    /// 用给定的显示行排出原文，返回标记所在的字符位置，并核对复制仍得到原串。
    private func markerIdentities(lines: [String], source: String) throws -> [Int] {
        let theme = TextTheme.builtin[0]
        let document = FileTextDocumentView.make()

        document.show(
            lines,
            source: source,
            style: FileTextStyle(theme: theme),
            rendering: TextStyle(theme: theme, tabWidth: 4, showsInvisibles: true),
            spans: nil
        )

        let manager = try #require(document.layoutManager as? TextInvisibleLayoutManager)
        manager.ensureLayout(for: try #require(document.textContainer))
        #expect(document.copiedText(in: NSRange(location: 0, length: document.string.utf16.count)) == source)
        return manager.markers(in: NSRange(location: 0, length: manager.numberOfGlyphs)).map(\.characterIndex)
    }
}
