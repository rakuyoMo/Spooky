import Foundation
import Testing

@testable import Spooky

// MARK: - ThemeStoreTests + DefaultThemes

/// 启动时把 Default 与 Default (Dark) 写进 Themes 目录：只在缺少或无法加载时写入，写入后与其它主题一样可以编辑、改名和删除。
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

    /// 改名或删除后，下次启动按名称发现缺少，重新写入；改了名的那份仍用资源里的标识，新写入的换成新标识。
    @Test("删除或改名后下次启动重新写入")
    func installRestoresRenamedAndDeleted() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        try store.installDefaultThemes()

        let day = try #require(store.themes.first { $0.name == "Default" })
        let night = try #require(store.themes.first { $0.name == "Default (Dark)" })

        // 浅色外观选着 Default，改名后选择跟着它走。
        store.select(day.id, dark: false)
        try store.rename(day.id, to: "Mine")
        try store.delete(night.id)

        #expect(try Self.themeFiles(root) == ["Mine.spookytheme"])

        let relaunched = try Self.store(in: root)
        try relaunched.installDefaultThemes()

        #expect(Set(relaunched.themes.map(\.name)) == ["Default", "Default (Dark)", "Mine"])

        // 两份文件不共用标识：改了名的 Mine 留着资源里的标识，新写入的 Default 换成新标识。
        let restored = try #require(relaunched.themes.first { $0.name == "Default" })
        let mine = try #require(relaunched.themes.first { $0.name == "Mine" })
        #expect(mine.id == day.id)
        #expect(restored.id != mine.id)
        #expect(restored.colors == TextTheme.builtin[0].colors)

        // 删掉的 Default (Dark) 标识已经空出来，重新写入时沿用资源里的标识。
        #expect(relaunched.themes.first { $0.name == "Default (Dark)" }?.id == TextTheme.builtin[1].id)

        #expect(TextTheme.current(dark: false, in: relaunched) == mine)
        #expect(TextTheme.current(dark: true, in: relaunched).name == "Default (Dark)")
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
