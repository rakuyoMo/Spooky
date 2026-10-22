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
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/Spooky")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        let expression = try NSRegularExpression(pattern: #"AppPalette\.(?:color|nsColor)\("([^"]+)"\)"#)

        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let name = (text as NSString).substring(with: match.range(at: 1))
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
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/Spooky")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
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
        let light = BuiltinTheme.current(dark: false)
        let dark = BuiltinTheme.current(dark: true)
        #expect(light.name == "Default")
        #expect(dark.name == "Default (Dark)")
        #expect(light.fontName == "Menlo-Regular" && dark.fontSize == 11)
        #expect(Set(light.colors.keys) == Set(dark.colors.keys))
        #expect(Set(["text", "background", "added", "deleted"]).isSubset(of: Set(light.colors.keys)))
        #expect(light.colors["deleted"]?.hex == "#FF3030")
        #expect(light.colors["deleted"]?.alpha == 0.18)
        #expect(dark.colors["deleted"]?.hex == "#FF453A")
        #expect(dark.colors["deleted"]?.alpha == 0.20)
        let lightBackground = try #require(light.colors["background"]?.nsColor.usingColorSpace(.sRGB))
        let darkBackground = try #require(dark.colors["background"]?.nsColor.usingColorSpace(.sRGB))
        #expect(
            lightBackground.redComponent == 1
                && lightBackground.greenComponent == 1
                && lightBackground.blueComponent == 1
        )
        #expect(
            darkBackground.redComponent == 0
                && darkBackground.greenComponent == 0
                && darkBackground.blueComponent == 0
        )
        #expect(AppPalette.colors["general_background_color"]?.dark.hex == "#323437")
        #expect(AppPalette.colors["blue_file_status_background_color"]?.dark.alpha == 0.70)
    }

    /// 终端候选不能误把 Prompt 的标识映射为 Otty。
    @Test("终端候选和双层命令转义")
    @MainActor
    func terminalCommands() {
        #expect(TerminalApplication.allCases.count == 7)
        #expect(TerminalApplication.prompt.rawValue == "com.panic.prompt.3")
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
