import AppKit
import Foundation
import Testing

@testable import Spooky

// MARK: - ThemeStoreTests

/// 主题的新建、编辑、改名、删除、导入、导出、按外观选择与无法加载时的回退。
///
/// 每个测试在临时目录里放 Themes 目录与偏好文件，测试结束随目录删除，不碰 Application Support 与标准偏好。
@MainActor
struct ThemeStoreTests {
    /// 新主题以所在外观的内置主题为底，立即成为这一外观的主题，重新启动后仍然有效。
    @Test("新建主题按外观取底色并立即选用")
    func createSelectsForAppearance() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        let first = try store.create(named: "New Theme", dark: false)
        let second = try store.create(named: "New Theme", dark: false)
        let night = try store.create(named: "New Theme", dark: true)

        // 重名时依次编号，文件名取主题名称。
        #expect([first.name, second.name, night.name] == ["New Theme", "New Theme 2", "New Theme 3"])
        #expect(FileManager.default.fileExists(atPath: Self.themes(root).appending(path: "New Theme 2.spookytheme").path))

        // 浅色外观新建的主题沿用 Default，深色外观沿用 Default (Dark)。
        #expect(first.colors == TextTheme.builtin[0].colors)
        #expect(night.colors == TextTheme.builtin[1].colors)
        #expect(!first.isBuiltin && first.id != second.id)

        #expect(TextTheme.current(dark: false, in: store) == second)
        #expect(TextTheme.current(dark: true, in: store) == night)

        // 新的存储实例从同一目录与偏好读回全部主题和两种外观的选择。
        let reopened = try Self.store(in: root)
        #expect(reopened.userThemes.map(\.name) == ["New Theme", "New Theme 2", "New Theme 3"])
        #expect(TextTheme.current(dark: false, in: reopened) == second)
        #expect(TextTheme.current(dark: true, in: reopened) == night)
    }

    /// 字体与颜色的改动写回主题文件，正在使用这个主题的视图取到的是新值；内置主题不被改动。
    @Test("编辑字体与颜色写回文件，内置主题只读")
    func editWritesThemeFile() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        let theme = try store.create(named: "Paper", dark: false)
        let added = PaletteColor(hex: "#123456", alpha: 0.5)

        try store.update(theme.id) {
            $0.colors["added"] = added
            $0.fontName = "Monaco"
            $0.fontSize = 13
        }

        let current = TextTheme.current(dark: false, in: store)
        #expect(current.colors["added"] == added)
        #expect(current.fontName == "Monaco" && current.fontSize == 13)

        // 文件内容与内存中的主题一致。
        let data = try Data(contentsOf: Self.themes(root).appending(path: "Paper.spookytheme"))
        #expect(try TextTheme.decode(data) == current)

        // 内置主题没有文件，改动请求不产生任何写入。
        try store.update(TextTheme.builtin[0].id) { $0.fontSize = 30 }
        #expect(TextTheme.builtin[0].fontSize == 11)
        #expect(try Self.themeFiles(root) == ["Paper.spookytheme"])

        // 色板选出的颜色换算成六位十六进制与两位小数的不透明度，再读回时不变。
        let picked = PaletteColor(hex: "#336699", alpha: 0.25)
        #expect(PaletteColor(nsColor: picked.nsColor) == picked)
    }

    /// 改名移动文件；与其它主题重名、只改大小写和名称含 `/` 的情况都按文件名规则处理。
    @Test("改名移动主题文件并拒绝重名")
    func renameMovesFile() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        let theme = try store.create(named: "New Theme", dark: false)
        try store.create(named: "Other", dark: false)

        try store.rename(theme.id, to: "  Night Owl  ")
        #expect(try Self.themeFiles(root) == ["Night Owl.spookytheme", "Other.spookytheme"])

        // 内置主题与其它用户主题的名称都不能再用，比较时不区分大小写。
        #expect(throws: ThemeStoreError.nameInUse("Default")) { try store.rename(theme.id, to: "Default") }
        #expect(throws: ThemeStoreError.nameInUse("other")) { try store.rename(theme.id, to: "other") }

        // 只改大小写时文件随之改名，不会丢失。
        try store.rename(theme.id, to: "night owl")
        #expect(try Self.themeFiles(root) == ["night owl.spookytheme", "Other.spookytheme"])

        // 空白名称不生效；`/` 在文件名里换成 `-`，主题名称保持原样。
        try store.rename(theme.id, to: "   ")
        try store.rename(theme.id, to: "Light/Dark")
        #expect(store.userThemes.map(\.name) == ["Light/Dark", "Other"])
        #expect(try Self.themeFiles(root) == ["Light-Dark.spookytheme", "Other.spookytheme"])

        // 重新读取后名称与选择不变。
        let reopened = try Self.store(in: root)
        #expect(TextTheme.current(dark: false, in: reopened).name == "Other")
        #expect(reopened.userThemes.map(\.id).contains(theme.id))
    }

    /// 删除所选主题后，这一外观回到对应的内置主题。
    @Test("删除所选主题后回到内置主题")
    func deleteFallsBack() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        let theme = try store.create(named: "Dusk", dark: true)
        #expect(TextTheme.current(dark: true, in: store) == theme)

        try store.delete(theme.id)

        #expect(try Self.themeFiles(root).isEmpty)
        #expect(TextTheme.current(dark: true, in: store) == TextTheme.builtin[1])
        #expect(TextTheme.current(dark: true, in: try Self.store(in: root)) == TextTheme.builtin[1])
    }

    /// 浅色、深色外观各选一套，内置主题也可以跨外观选用，选择互不影响。
    @Test("浅色与深色外观各自记住所选主题")
    func appearancesSelectIndependently() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        let theme = try store.create(named: "Midnight", dark: true)
        store.select(TextTheme.builtin[1].id, dark: false)

        #expect(TextTheme.current(dark: false, in: store) == TextTheme.builtin[1])
        #expect(TextTheme.current(dark: true, in: store) == theme)

        store.select(TextTheme.builtin[0].id, dark: true)
        let reopened = try Self.store(in: root)
        #expect(TextTheme.current(dark: false, in: reopened) == TextTheme.builtin[1])
        #expect(TextTheme.current(dark: true, in: reopened) == TextTheme.builtin[0])
    }

    /// 导出的文件只含颜色、字体与名称标识，导入后与原主题一致；同名时必须确认覆盖。
    @Test("导出与导入主题文件")
    func importAndExport() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        let theme = try store.create(named: "Harbor", dark: false)
        try store.update(theme.id) { $0.colors["text"] = PaletteColor(hex: "#0A0B0C", alpha: 1) }
        let edited = TextTheme.current(dark: false, in: store)

        // 导出的内容只有标识、名称、字体与颜色。
        let exported = root.appending(path: "Harbor.spookytheme")
        try edited.encoded().write(to: exported)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: exported)) as? [String: Any])
        #expect(Set(object.keys) == ["identifier", "name", "fontName", "fontSize", "colors"])

        // 在另一份存储里导入，内容与原主题一致，原文件保留在原处。
        let other = try Self.store(in: Self.makeRoot(cleanedBy: root))
        #expect(try other.importTheme(at: exported, replacing: false) == edited)
        #expect(FileManager.default.fileExists(atPath: exported.path))

        // 同名时不覆盖就报告目标位置；确认后覆盖内容，标识与外观选择不变。
        let destination = Self.themes(root).appending(path: "Harbor.spookytheme")
        #expect(throws: ThemeStoreError.fileExists(destination)) {
            try store.importTheme(at: exported, replacing: false)
        }

        var renamed = edited
        renamed.id = UUID().uuidString
        renamed.colors["text"] = PaletteColor(hex: "#FFFFFF", alpha: 1)
        try renamed.encoded().write(to: exported)

        let replaced = try store.importTheme(at: exported, replacing: true)
        #expect(replaced.id == theme.id)
        #expect(TextTheme.current(dark: false, in: store).colors["text"]?.hex == "#FFFFFF")
    }

    /// 导入的名称与内置主题相同时改用编号名称，标识重复时换成新标识；无效文件不导入。
    @Test("导入时避开内置主题与重复标识")
    func importAvoidsCollisions() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        let source = root.appending(path: "incoming.spookytheme")

        // 导出的内置主题再导入，得到可编辑的副本，不会冒充内置主题。
        try TextTheme.builtin[0].encoded().write(to: source)
        let copy = try store.importTheme(at: source, replacing: false)
        #expect(copy.name == "Default 2")
        #expect(copy.id != TextTheme.builtin[0].id && !copy.isBuiltin)

        // 名称不同、标识与已有主题相同的文件换成新标识，两个主题并存。
        var twin = copy
        twin.name = "Twin"
        try twin.encoded().write(to: source)
        let imported = try store.importTheme(at: source, replacing: false)
        #expect(imported.id != copy.id)
        #expect(store.userThemes.map(\.name) == ["Default 2", "Twin"])

        // 无法解码与缺少颜色的文件都算无效，不写入 Themes 目录。
        try Data("not json".utf8).write(to: source)
        #expect(throws: ThemeStoreError.invalidFile) { try store.importTheme(at: source, replacing: false) }

        var incomplete = twin
        incomplete.name = "Incomplete"
        incomplete.colors["added"] = nil
        try incomplete.encoded().write(to: source)
        #expect(throws: ThemeStoreError.invalidFile) { try store.importTheme(at: source, replacing: false) }
        #expect(try Self.themeFiles(root) == ["Default 2.spookytheme", "Twin.spookytheme"])
    }

    /// 所选主题丢失、损坏或与其它主题重复时，按外观回退到内置主题，损坏的文件列为无法加载。
    @Test("所选主题无法加载时按外观回退")
    func unloadableThemesFallBack() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        let theme = try store.create(named: "Ember", dark: true)
        let file = Self.themes(root).appending(path: "Ember.spookytheme")

        // 与已有主题同标识的另一份文件无法加载，按文件名先读到的主题不受影响。
        var duplicate = theme
        duplicate.name = "Other Ember"
        let duplicateFile = Self.themes(root).appending(path: "Other Ember.spookytheme")
        try duplicate.encoded().write(to: duplicateFile)
        store.reload()
        #expect(store.invalidFiles.map(\.lastPathComponent) == ["Other Ember.spookytheme"])
        #expect(TextTheme.current(dark: true, in: store) == theme)
        try FileManager.default.removeItem(at: duplicateFile)

        // 所选主题的文件损坏后，深色外观回到 Default (Dark)，浅色外观不受影响。
        try Data("{".utf8).write(to: file)
        let reopened = try Self.store(in: root)
        #expect(reopened.invalidFiles.map(\.lastPathComponent) == ["Ember.spookytheme"])
        #expect(TextTheme.current(dark: true, in: reopened) == TextTheme.builtin[1])
        #expect(TextTheme.current(dark: false, in: reopened) == TextTheme.builtin[0])

        // 偏好里记着已不存在的标识时同样回退。
        reopened.select("missing", dark: false)
        #expect(TextTheme.current(dark: false, in: reopened) == TextTheme.builtin[0])

        // 新建主题不会覆盖占着文件名的损坏文件。
        #expect(try reopened.create(named: "Ember", dark: false).name == "Ember 2")
        #expect(try Data(contentsOf: file) == Data("{".utf8))
    }
}

// MARK: - Helpers

extension ThemeStoreTests {
    /// 新建一个临时目录，测试结束时由调用方删除。
    private static func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "spooky-themes-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }

    /// 在已有的临时目录里再建一个子目录，随外层目录一起删除。
    private static func makeRoot(cleanedBy root: URL) throws -> URL {
        let nested = root.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
        return nested
    }

    /// 临时目录里的 Themes 目录。
    private static func themes(_ root: URL) -> URL {
        root.appending(path: "Themes", directoryHint: .isDirectory)
    }

    /// 使用临时目录里的 Themes 目录与偏好文件的存储；偏好以文件路径作 suite 名，随目录删除。
    private static func store(in root: URL) throws -> ThemeStore {
        let defaults = try #require(UserDefaults(suiteName: root.appending(path: "defaults").path))
        return ThemeStore(directory: themes(root), defaults: defaults)
    }

    /// Themes 目录里的文件名，按名称排序。
    private static func themeFiles(_ root: URL) throws -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: themes(root).path)) ?? []
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
