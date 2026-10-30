import AppKit
import SpookyKit
import Testing

@testable import Spooky

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
}
