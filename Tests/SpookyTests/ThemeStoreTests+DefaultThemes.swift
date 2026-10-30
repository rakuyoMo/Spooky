import Foundation
import Testing

@testable import Spooky

// MARK: - ThemeStoreTests + DefaultThemes

/// 启动时把 Default 与 Default (Dark) 写进 Themes 目录：只在缺少或无法加载时写入，仍是旧默认配色的换成新配色；
/// 写入后与其它主题一样可以编辑，但不能改名和删除。
extension ThemeStoreTests {
    /// 空目录里写入两套默认主题，内容取自资源；没有选过主题时按名称用的就是这两份文件，编辑后立即生效。
    @Test("首次启动写入两套默认主题并可编辑")
    func installWritesDefaults() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        try store.installDefaultThemes()

        // 文件名取主题名称，内容与资源里的版本一致。
        #expect(Set(try Self.themeFiles(root)) == ["Default.spookytheme", "Default (Dark).spookytheme"])

        let file = Self.themes(root).appending(path: "Default.spookytheme")
        #expect(try TextTheme.decode(Data(contentsOf: file)) == TextTheme.builtin[0])

        // 编辑写回文件，没有选过主题的浅色外观按名称取到编辑后的内容。
        let day = try #require(store.themes.first { $0.name == "Default" })
        try store.update(day.id) { $0.colors["added"] = PaletteColor(hex: "#123456", alpha: 0.5) }

        #expect(TextTheme.current(dark: false, in: store).colors["added"]?.hex == "#123456")
        #expect(try TextTheme.decode(Data(contentsOf: file)).colors["added"]?.hex == "#123456")
        #expect(TextTheme.current(dark: true, in: store).name == "Default (Dark)")
    }

    /// 再次启动时文件已经存在，编辑过的内容保持不变；同名主题放在别的文件里时也不再写入第二份。
    @Test("已有的默认主题文件不被覆盖")
    func installKeepsExistingFiles() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        try store.installDefaultThemes()

        let day = try #require(store.themes.first { $0.name == "Default" })
        try store.update(day.id) { $0.fontSize = 20 }

        let file = Self.themes(root).appending(path: "Default.spookytheme")
        let edited = try Data(contentsOf: file)

        // 新的存储实例模拟下次启动。
        let relaunched = try Self.store(in: root)
        try relaunched.installDefaultThemes()

        #expect(try Data(contentsOf: file) == edited)
        #expect(TextTheme.current(dark: false, in: relaunched).fontSize == 20)
        #expect(relaunched.themes.count == 2)

        // 名为 Default (Dark) 的主题放在另一个文件名下时，它已经占着这个名称，不再写入重名的文件。
        var night = try #require(relaunched.themes.first { $0.name == "Default (Dark)" })
        let nightFile = Self.themes(root).appending(path: "Default (Dark).spookytheme")
        try FileManager.default.removeItem(at: nightFile)

        night.id = UUID().uuidString
        try night.encoded().write(to: Self.themes(root).appending(path: "Night.spookytheme"))

        let third = try Self.store(in: root)
        try third.installDefaultThemes()

        #expect(Set(try Self.themeFiles(root)) == ["Default.spookytheme", "Night.spookytheme"])
        #expect(third.invalidFiles.isEmpty)
    }

    /// 默认主题的文件损坏后，下次启动在原位置写回资源里的内容，之后能正常加载与选用；另一份编辑过的文件不受影响。
    @Test("损坏的默认主题文件在启动时恢复")
    func installRestoresUnloadableFile() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        try store.installDefaultThemes()

        let day = try #require(store.themes.first { $0.name == "Default" })
        try store.update(day.id) { $0.fontSize = 20 }

        let dayFile = Self.themes(root).appending(path: "Default.spookytheme")
        let edited = try Data(contentsOf: dayFile)

        // 写坏 Default (Dark)：下次启动时它列为无法加载，深色外观暂时用资源里的版本。
        let nightFile = Self.themes(root).appending(path: "Default (Dark).spookytheme")
        try Data("{".utf8).write(to: nightFile)

        let relaunched = try Self.store(in: root)
        #expect(relaunched.invalidFiles.map(\.lastPathComponent) == ["Default (Dark).spookytheme"])

        try relaunched.installDefaultThemes()

        // 原位置写回资源里的内容，不再列为无法加载；编辑过的 Default 原样保留。
        #expect(Set(try Self.themeFiles(root)) == ["Default.spookytheme", "Default (Dark).spookytheme"])
        #expect(try TextTheme.decode(Data(contentsOf: nightFile)) == TextTheme.builtin[1])
        #expect(relaunched.invalidFiles.isEmpty)
        #expect(try Data(contentsOf: dayFile) == edited)

        // 恢复的主题可以选用，再次启动时从文件加载。
        let night = try #require(relaunched.themes.first { $0.name == "Default (Dark)" })
        relaunched.select(night.id, dark: false)
        #expect(TextTheme.current(dark: false, in: relaunched) == night)

        let reopened = try Self.store(in: root)
        #expect(reopened.invalidFiles.isEmpty)
        #expect(TextTheme.current(dark: false, in: reopened) == night)
        #expect(TextTheme.current(dark: true, in: reopened) == night)
    }

    /// 在 Finder 里删掉默认主题的文件后，下次启动按名称发现缺少，重新写入；
    /// 另一个主题文件仍用着资源里的标识时，新写入的那份换成新标识，两份文件不共用标识。
    @Test("在 Finder 里删掉后下次启动重新写入")
    func installRestoresDeletedFiles() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        try store.installDefaultThemes()

        let day = try #require(store.themes.first { $0.name == "Default" })
        store.select(day.id, dark: false)

        // 手动复制 Default 的文件并改掉文件里的名称，再在 Finder 里删掉两份默认主题的文件。
        var mine = day
        mine.name = "Mine"
        try mine.encoded().write(to: Self.themes(root).appending(path: "Mine.spookytheme"))
        try FileManager.default.removeItem(at: Self.themes(root).appending(path: "Default.spookytheme"))
        try FileManager.default.removeItem(at: Self.themes(root).appending(path: "Default (Dark).spookytheme"))

        let relaunched = try Self.store(in: root)
        try relaunched.installDefaultThemes()

        #expect(
            Set(try Self.themeFiles(root)) == [
                "Default.spookytheme",
                "Default (Dark).spookytheme",
                "Mine.spookytheme",
            ]
        )

        // Mine 留着资源里的标识，浅色外观的选择随标识落在它上面；新写入的 Default 换成新标识。
        let restored = try #require(relaunched.themes.first { $0.name == "Default" })
        #expect(restored.id != day.id)
        #expect(restored.colors == TextTheme.builtin[0].colors)
        #expect(TextTheme.current(dark: false, in: relaunched).name == "Mine")

        // Default (Dark) 的标识没有被占用，重新写入时沿用资源里的标识。
        #expect(relaunched.themes.first { $0.name == "Default (Dark)" }?.id == TextTheme.builtin[1].id)
        #expect(TextTheme.current(dark: true, in: relaunched).name == "Default (Dark)")
    }

    /// 两套内置主题按名称认出，标识换成了 UUID 的也一样：改名、删除都不动文件，字体与颜色仍可以编辑；
    /// 自建的主题照旧能改名、删除。
    @Test("内置主题不能改名、删除，仍可以编辑")
    func builtinThemesKeepNames() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // Default 用资源里的标识，Default (Dark) 用 UUID，模拟写入时标识被占用的那一份。
        var night = TextTheme.builtin[1]
        night.id = UUID().uuidString
        try Self.writeTheme(TextTheme.builtin[0], in: root)
        try Self.writeTheme(night, in: root)

        let store = try Self.store(in: root)
        let files = try Self.themeFiles(root)
        #expect(store.themes.allSatisfy { ThemeStore.isBuiltin($0) })

        try store.rename(TextTheme.builtin[0].id, to: "Mine")
        try store.delete(night.id)

        #expect(try Self.themeFiles(root) == files)
        #expect(Set(store.themes.map(\.name)) == ["Default", "Default (Dark)"])

        // 编辑照常写回文件。
        try store.update(night.id) { $0.fontSize = 14 }

        let nightFile = Self.themes(root).appending(path: "Default (Dark).spookytheme")
        #expect(try TextTheme.decode(Data(contentsOf: nightFile)).fontSize == 14)

        // 自建的主题不是内置主题，可以改名、删除。
        let custom = try store.create(named: "Custom", dark: false)
        #expect(!ThemeStore.isBuiltin(custom))

        try store.rename(custom.id, to: "Ours")
        #expect(store.themes.contains { $0.name == "Ours" })

        try store.delete(custom.id)
        #expect(try Self.themeFiles(root) == files)
    }

    /// 目录里是换配色之前写入的两份默认主题：启动时换成资源里的配色，标识、名称、文件名与外观选择都不变。
    @Test("旧默认配色在启动时换成新配色")
    func installReplacesLegacyColors() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // Default 用资源里的标识，Default (Dark) 用 UUID。
        var night = Self.legacyTheme(1)
        night.id = UUID().uuidString
        try Self.writeTheme(Self.legacyTheme(0), in: root)
        try Self.writeTheme(night, in: root)

        let store = try Self.store(in: root)
        store.select(night.id, dark: true)
        try store.installDefaultThemes()

        #expect(Set(try Self.themeFiles(root)) == ["Default.spookytheme", "Default (Dark).spookytheme"])

        let dayFile = Self.themes(root).appending(path: "Default.spookytheme")
        let nightFile = Self.themes(root).appending(path: "Default (Dark).spookytheme")
        #expect(try TextTheme.decode(Data(contentsOf: dayFile)) == TextTheme.builtin[0])

        // 只换颜色：标识仍是原来的 UUID，深色外观照旧选着它。
        let replaced = try TextTheme.decode(Data(contentsOf: nightFile))
        #expect(replaced.id == night.id)
        #expect(replaced.name == "Default (Dark)")
        #expect(replaced.colors == TextTheme.builtin[1].colors)
        #expect(TextTheme.current(dark: true, in: store) == replaced)
    }

    /// 旧默认配色里改过一种颜色或字号的，是用户编辑过的主题，启动时原样保留。
    @Test("改过的旧默认配色保持原样")
    func installKeepsEditedLegacyColors() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        var day = Self.legacyTheme(0)
        day.colors["keyword"] = PaletteColor(hex: "#123456", alpha: 1)

        var night = Self.legacyTheme(1)
        night.fontSize = 12

        try Self.writeTheme(day, in: root)
        try Self.writeTheme(night, in: root)

        let dayFile = Self.themes(root).appending(path: "Default.spookytheme")
        let nightFile = Self.themes(root).appending(path: "Default (Dark).spookytheme")
        let dayData = try Data(contentsOf: dayFile)
        let nightData = try Data(contentsOf: nightFile)

        let store = try Self.store(in: root)
        try store.installDefaultThemes()

        #expect(try Data(contentsOf: dayFile) == dayData)
        #expect(try Data(contentsOf: nightFile) == nightData)
    }

    /// 所选主题的文件被移走后，按名称回到目录里的 Default (Dark)，而不是资源里的版本。
    @Test("所选主题丢失时按名称回退")
    func missingSelectionFallsBackByName() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        try store.installDefaultThemes()

        let night = try #require(store.themes.first { $0.name == "Default (Dark)" })
        try store.update(night.id) { $0.fontSize = 15 }

        try store.create(named: "Dusk", dark: true)
        try FileManager.default.removeItem(at: Self.themes(root).appending(path: "Dusk.spookytheme"))

        let reopened = try Self.store(in: root)
        let current = TextTheme.current(dark: true, in: reopened)

        #expect(current.id == night.id)
        #expect(current.fontSize == 15)
    }
}

// MARK: - Helpers

extension ThemeStoreTests {
    /// 换配色之前写进目录的默认主题：0 是 Default，1 是 Default (Dark)；与资源里的版本只差这几种颜色。
    private static func legacyTheme(_ index: Int) -> TextTheme {
        let changed: [[String: PaletteColor]] = [
            [
                "invisible": PaletteColor(hex: "#000000", alpha: 1),
                "added": PaletteColor(hex: "#28CD41", alpha: 0.18),
                "deleted": PaletteColor(hex: "#FF3030", alpha: 0.18),
            ],
            [
                "background": PaletteColor(hex: "#000000", alpha: 1),
                "selection": PaletteColor(hex: "#FBD1AD", alpha: 1),
                "added": PaletteColor(hex: "#32D74B", alpha: 0.18),
                "deleted": PaletteColor(hex: "#FF453A", alpha: 0.2),
            ],
        ]

        var theme = TextTheme.builtin[index]
        theme.colors.merge(changed[index]) { $1 }

        return theme
    }

    /// 把主题按名称写进临时目录的 Themes 目录，模拟之前写入或用户放进去的文件。
    private static func writeTheme(_ theme: TextTheme, in root: URL) throws {
        try FileManager.default.createDirectory(at: themes(root), withIntermediateDirectories: true)
        try theme.encoded().write(to: themes(root).appending(path: TextTheme.fileName(for: theme.name)))
    }
}
