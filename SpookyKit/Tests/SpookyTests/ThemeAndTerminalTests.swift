import AppKit
import SpookyKit
import Testing

@testable import Spooky

/// 默认主题、命名色和终端参数的产品约定。
struct ThemeAndTerminalTests {
    /// 主题字体和 Diff 颜色从实际交付的资源读取。
    @Test("两套默认主题的字体和透明度")
    func builtinThemes() throws {
        let light = BuiltinTheme.current(dark: false)
        let dark = BuiltinTheme.current(dark: true)
        #expect(light.name == "Default")
        #expect(dark.name == "Default (Dark)")
        #expect(light.fontName == "Menlo-Regular" && dark.fontSize == 11)
        #expect(Set(light.colors.keys) == Set(dark.colors.keys))
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
