import AppKit
import SpookyKit
import SwiftUI
import Testing

@testable import Spooky

// MARK: - ThemeAndTerminalTests

/// 默认主题、命名色和终端参数的产品约定。
struct ThemeAndTerminalTests {
    /// 命名色缺失会在窗口绘制时崩溃，检查实际 Swift 界面引用。
    @Test("界面命名色均存在")
    func referencedColors() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/Spooky")

        // 界面源码分在各功能子目录中，逐层列出
        let files = try FileManager.default.subpathsOfDirectory(atPath: sources.path)
            .map { sources.appending(path: $0) }
            .filter { $0.pathExtension == "swift" }

        let expression = try NSRegularExpression(pattern: #"AppPalette\.(?:color|nsColor)\("([^"]+)"\)"#)

        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let range = try #require(Range(match.range(at: 1), in: text))
                let name = String(text[range])
                #expect(AppPalette.colors[name] != nil, "缺少界面颜色：\(name)")
            }
        }
        for prefix in ["blue", "gray", "yellow", "selected"] {
            #expect(AppPalette.colors[prefix + "_badge_text_color"] != nil)
            #expect(AppPalette.colors[prefix + "_badge_background_color"] != nil)
        }

        // 提交图的泳道颜色按名称拼接，逐个检查十种颜色。
        for lane in ["gray", "blue", "pink", "green", "yellow", "orange", "indigo", "red", "teal", "purple"] {
            #expect(AppPalette.colors[lane + "_history_graph_line_color"] != nil)
        }
    }

    /// 界面颜色只来自命名色资源与系统语义色，源码中没有写死的十六进制或 RGB 数值。
    @Test("界面源码不写死颜色数值")
    func noHardCodedColors() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/Spooky")

        // 界面源码分在各功能子目录中，逐层列出
        let files = try FileManager.default.subpathsOfDirectory(atPath: sources.path)
            .map { sources.appending(path: $0) }
            .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "AppPalette.swift" }

        let expression = try NSRegularExpression(
            pattern: ##""#[0-9A-Fa-f]{6}"|NSColor\((?:white|srgbRed|red|calibratedRed|deviceRed):|Color\((?:red|white):"##
        )

        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let matches = expression.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
            #expect(matches == 0, "写死的颜色：\(file.lastPathComponent)")
        }
    }

    /// 主题字体和 Diff 颜色从实际交付的资源读取。
    @Test("两套默认主题的字体和透明度")
    func builtinThemes() throws {
        let light = TextTheme.builtin[0]
        let dark = TextTheme.builtin[1]
        #expect(light.name == "Default")
        #expect(dark.name == "Default (Dark)")
        #expect(light.fontName == "Menlo-Regular" && dark.fontSize == 11)
        #expect(Set(light.colors.keys) == Set(dark.colors.keys))
        #expect(Set(["text", "background", "added", "deleted"]).isSubset(of: Set(light.colors.keys)))

        // 浅色的增删底色与不可见字符。
        #expect(light.colors["added"] == PaletteColor(hex: "#28CD41", alpha: 0.12))
        #expect(light.colors["deleted"] == PaletteColor(hex: "#FF3030", alpha: 0.12))
        #expect(light.colors["invisible"] == PaletteColor(hex: "#000000", alpha: 0.3))

        // 深色的背景、选区与增删底色。
        #expect(dark.colors["background"] == PaletteColor(hex: "#161819", alpha: 1))
        #expect(dark.colors["selection"] == PaletteColor(hex: "#515B70", alpha: 1))
        #expect(dark.colors["added"] == PaletteColor(hex: "#32D74B", alpha: 0.10))
        #expect(dark.colors["deleted"] == PaletteColor(hex: "#FF453A", alpha: 0.10))

        let lightBackground = try #require(light.colors["background"]?.nsColor.usingColorSpace(.sRGB))
        #expect(
            lightBackground.redComponent == 1
                && lightBackground.greenComponent == 1
                && lightBackground.blueComponent == 1
        )

        #expect(AppPalette.colors["general_background_color"]?.dark.hex == "#323437")
        #expect(AppPalette.colors["blue_file_status_background_color"]?.dark.alpha == 0.70)
    }

    /// Themes 页的 Diff 预览是一段固定补丁的唯一一块：上下文、删除、新增、上下文，删除与新增两行配对显示行内高亮。
    @Test("Diff 预览的补丁解析成一块四行")
    @MainActor
    func themePreviewHunk() throws {
        let hunk = try #require(ThemesSettingsView.previewHunk())

        #expect(hunk.lines.map(\.prefix) == [32, 45, 43, 32])
        #expect(hunk.lines.map(\.oldNumber) == [1, 2, nil, 3])
        #expect(hunk.lines.map(\.newNumber) == [1, nil, 2, 3])

        // 两行上下文是同一段文字，删除与新增两行的文字取各自的资源。
        let texts = hunk.lines.map { String(decoding: $0.content, as: UTF8.self) }
        #expect(texts[0] == texts[3])
        #expect(texts[1] == AppLocalization.text("themes.preview.deleted"))
        #expect(texts[2] == AppLocalization.text("themes.preview.added"))
        #expect(InlineDiff.ranges(in: hunk).keys.sorted() == [1, 2])
    }

    /// 字体框写 PostScript 名与一位小数的字号，字体没有安装时同样照写。
    @Test("字体框的字体名与字号")
    @MainActor
    func themeFontDescription() {
        var theme = TextTheme.builtin[0]
        #expect(ThemesSettingsView.fontDescription(theme) == "Menlo-Regular 11.0")

        theme.fontName = "Missing-Font"
        theme.fontSize = 12.5
        #expect(ThemesSettingsView.fontDescription(theme) == "Missing-Font 12.5")
    }

    /// 主题的每种颜色在 Themes 页都有且只有一处可改：记号类别列表的 20 行与 Font Color 之后的四个色块。
    @Test("记号类别列表与色块覆盖主题的全部颜色")
    @MainActor
    func themeTokenKeys() {
        let tokens = ThemeTokenList.keys
        let wells = ThemesSettingsView.colorWellKeys

        #expect(tokens.count == 20)
        #expect(Set(tokens).count == tokens.count)
        #expect(Set(tokens).isDisjoint(with: wells))

        // 两套内置主题的颜色键相同，主题文件也必须含有这些键。
        for theme in TextTheme.builtin {
            #expect(Set(tokens + wells) == Set(theme.colors.keys))
        }
    }

    /// Font Color 色块编辑记号类别列表里选中的那种颜色：选中 Keyword 后调色写进 `keyword`，正文色不变。
    @Test("选中的记号类别决定 Font Color 写回的颜色")
    @MainActor
    func tokenSelectionDrivesFontColor() async throws {
        let root = try ThemeStoreTests.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try ThemeStoreTests.store(in: root)
        let theme = try store.create(named: "Paper", dark: false)
        let window = Self.host(ThemesSettingsView(store: store).environment(\.colorScheme, .light))
        let hosting = try #require(window.contentView)

        let tokens = try #require(
            Self.subviews(NSTableView.self, in: hosting).first { $0.delegate is ThemeTokenListCoordinator }
        )

        let fontColor = try #require(
            Self.subviews(NSColorWell.self, in: hosting).first {
                $0.accessibilityLabel() == AppLocalization.text("themes.text")
            }
        )

        // 打开页面时选中 Plain Text，Font Color 是正文色。
        #expect(tokens.selectedRow == 0)
        #expect(PaletteColor(nsColor: fontColor.color, colorSpace: .genericRGB) == theme.colors["text"])

        // 用户选中 Keyword 后，Font Color 换成 keyword 的颜色。
        let keyword = try #require(theme.colors["keyword"])
        let row = try #require(ThemeTokenList.keys.firstIndex(of: "keyword"))
        tokens.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)

        try await FileViewsTests.wait {
            hosting.layoutSubtreeIfNeeded()
            return PaletteColor(nsColor: fontColor.color, colorSpace: .genericRGB) == keyword
        }

        // 颜色面板调出的颜色经色块的动作写回主题。
        let picked = PaletteColor(hex: "#123456", alpha: 0.5)
        fontColor.color = picked.calibratedNSColor
        _ = (fontColor.target as? NSObject)?.perform(fontColor.action, with: fontColor)

        let saved = try #require(store.themes.first { $0.id == theme.id })
        #expect(saved.colors["keyword"] == picked)
        #expect(saved.colors["text"] == theme.colors["text"])

        // 切回正文时色块回填正文色，不把刚编辑的关键字色写到其它记号。
        tokens.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        try await FileViewsTests.wait {
            hosting.layoutSubtreeIfNeeded()
            return PaletteColor(nsColor: fontColor.color, colorSpace: .genericRGB) == theme.colors["text"]
        }
    }

    /// 终端候选固定为六个程序，靠 Bundle Identifier 认出；路径与主机别名里的引号不能逃出转义。
    @Test("终端候选和双层命令转义")
    @MainActor
    func terminalCommands() {
        #expect(TerminalApplication.allCases.count == 6)
        #expect(TerminalApplication.otty.rawValue == "io.appmakes.otty")
        let local = RepositoryLocation.local(path: "/tmp/仓 库'\"$HOME")
        #expect(local.terminalCommand == "cd -- '/tmp/仓 库'\\''\"$HOME'")
        let remote = RepositoryLocation.remote(host: "alias'quoted", path: "/tmp/repo ' name")
        #expect(remote.terminalCommand.contains("'-t'"))
        #expect(remote.terminalCommand.contains("'ForwardAgent=no'"))
        #expect(remote.terminalCommand.contains("'--' 'alias'\\''quoted'"))
        #expect(remote.localURL == nil)
        #expect(TerminalLauncher.appleString("quoted\"\\\n") == "\"quoted\\\"\\\\\\n\"")
    }

    /// 在终端里打开仓库时尽量用已有的窗口：Terminal 有两个以上窗口时在最前面的窗口里执行，
    /// iTerm 已在运行且有窗口时在第一个窗口里新建标签页；命令经转义后才进入脚本。
    @Test("Terminal 与 iTerm 按已有的窗口决定在哪里执行")
    @MainActor
    func terminalScripts() {
        let command = "cd -- '/tmp/仓 库\"'"
        let quoted = TerminalLauncher.appleString(command)

        let terminal = TerminalLauncher.terminalScript(command)
        #expect(terminal.contains("if (count of windows) > 1 and (exists front window) then"))
        #expect(terminal.contains("do script \(quoted) in front window\n"))
        #expect(terminal.contains("else\n        do script \(quoted)\n"))
        #expect(!terminal.contains(command))

        let iTerm = TerminalLauncher.iTermScript(command)
        #expect(iTerm.hasPrefix("set wasRunning to application id \"com.googlecode.iterm2\" is running\n"))
        #expect(iTerm.contains("if (count of windows) is 0 then\n        create window with default profile"))
        #expect(iTerm.contains("if wasRunning then\n            tell first window to create tab with default profile"))
        #expect(iTerm.contains("delay 1\n    tell current session of first window to write text \(quoted)"))
        #expect(!iTerm.contains(command))
    }
}

// MARK: - Helpers

extension ThemeAndTerminalTests {
    /// 把页面放进不显示的窗口并完成一次布局，原生控件随之建立；窗口由调用方持有到测试结束。
    @MainActor
    private static func host(_ view: some View) -> NSWindow {
        let hosting = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        return window
    }

    /// 视图层级里给定类型的全部视图，按深度优先的顺序。
    @MainActor
    private static func subviews<Element: NSView>(_: Element.Type, in root: NSView) -> [Element] {
        root.subviews.flatMap { child in
            [child as? Element].compactMap(\.self) + subviews(Element.self, in: child)
        }
    }
}
