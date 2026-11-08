import Foundation
import Testing

@testable import Spooky

// MARK: - ThemeStoreTests

/// 主题的新建、编辑、改名、删除、导入、导出、按外观选择与无法加载时的回退。
///
/// 每个测试在临时目录里放 Themes 目录与偏好文件，测试结束随目录删除，不碰 Application Support 与标准偏好。
@MainActor
struct ThemeStoreTests {
    /// 新主题以所在外观的内置主题为底并立即成为这一外观的主题；字体与颜色的改动写回文件，重新启动后仍然有效。
    @Test("新建主题按外观取底色并立即选用，编辑写回文件")
    func createAndEdit() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        let first = try store.create(named: "New Theme", dark: false)
        let second = try store.create(named: "New Theme", dark: false)
        let night = try store.create(named: "New Theme", dark: true)

        // 重名时依次编号。
        #expect([first.name, second.name, night.name] == ["New Theme", "New Theme 2", "New Theme 3"])
        #expect(first.id != second.id)

        // 浅色外观新建的主题沿用 Default，深色外观沿用 Default (Dark)。
        #expect(first.colors == TextTheme.builtin[0].colors)
        #expect(night.colors == TextTheme.builtin[1].colors)
        #expect(TextTheme.current(dark: true, in: store) == night)

        // 字体与颜色的改动写回以主题名称命名的文件，正在使用这个主题的视图取到的是新值。
        let added = PaletteColor(hex: "#123456", alpha: 0.5)

        try store.update(second.id) {
            $0.colors["added"] = added
            $0.fontName = "Monaco"
            $0.fontSize = 13
        }

        let current = TextTheme.current(dark: false, in: store)
        #expect(current.id == second.id)
        #expect(current.colors["added"] == added)
        #expect(current.fontName == "Monaco" && current.fontSize == 13)

        let file = Self.themes(root).appending(path: "New Theme 2.spookytheme")
        #expect(try TextTheme.decode(Data(contentsOf: file)) == current)

        // 新的存储实例从同一目录与偏好读回全部主题和两种外观的选择。
        let reopened = try Self.store(in: root)
        #expect(reopened.themes.map(\.name) == ["New Theme", "New Theme 2", "New Theme 3"])
        #expect(TextTheme.current(dark: false, in: reopened) == current)
        #expect(TextTheme.current(dark: true, in: reopened) == night)
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

        // 其它主题的名称不能再用，比较时不区分大小写。
        #expect(throws: ThemeStoreError.nameInUse("other")) {
            try store.rename(theme.id, to: "other")
        }

        // 只改大小写时文件随之改名，不会丢失。
        try store.rename(theme.id, to: "night owl")
        #expect(try Self.themeFiles(root) == ["night owl.spookytheme", "Other.spookytheme"])

        // 空白名称不生效；`/` 在文件名里换成 `-`，主题名称保持原样。
        try store.rename(theme.id, to: "   ")
        try store.rename(theme.id, to: "Light/Dark")

        #expect(store.themes.map(\.name) == ["Light/Dark", "Other"])
        #expect(try Self.themeFiles(root) == ["Light-Dark.spookytheme", "Other.spookytheme"])

        // 重新读取后名称与选择不变。
        let reopened = try Self.store(in: root)
        #expect(TextTheme.current(dark: false, in: reopened).name == "Other")
        #expect(reopened.themes.map(\.id).contains(theme.id))
    }

    /// 浅色、深色外观各自记住所选主题，Default 与 Default (Dark) 可以跨外观选用；
    /// 删掉所选主题后，删除时所在的外观改选列表第一行，另一外观选的也是它时按名称回到目录里编辑过的 Default。
    @Test("两种外观各自选择主题，删除所选主题后改选")
    func selectAndDelete() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        try store.installDefaultThemes()

        let edited = try #require(store.themes.first { $0.name == "Default" })
        try store.update(edited.id) { $0.fontSize = 15 }

        let day = try #require(store.themes.first { $0.name == "Default" })
        let night = try #require(store.themes.first { $0.name == "Default (Dark)" })

        // 两种外观各选一套，重新启动后互不影响。
        let dusk = try store.create(named: "Dusk", dark: true)
        store.select(night.id, dark: false)

        #expect(TextTheme.current(dark: false, in: store) == night)
        #expect(TextTheme.current(dark: true, in: store) == dusk)

        store.select(day.id, dark: true)

        let reopened = try Self.store(in: root)
        #expect(TextTheme.current(dark: false, in: reopened) == night)
        #expect(TextTheme.current(dark: true, in: reopened) == day)

        // Aurora 排在列表第一行，Dusk 同时是两种外观的所选主题，在深色外观删掉它。
        let aurora = try store.create(named: "Aurora", dark: false)
        store.select(dusk.id, dark: false)
        store.select(dusk.id, dark: true)

        try store.delete(dusk.id, dark: true)
        #expect(!(try Self.themeFiles(root).contains("Dusk.spookytheme")))

        // 深色外观改选第一行的 Aurora，重新启动后仍然有效。
        #expect(store.themes.first?.id == aurora.id)
        #expect(TextTheme.current(dark: true, in: store) == aurora)
        #expect(TextTheme.current(dark: true, in: try Self.store(in: root)) == aurora)

        // 浅色外观按名称回到目录里编辑过的 Default。
        #expect(TextTheme.current(dark: false, in: store) == day)
        #expect(TextTheme.current(dark: false, in: try Self.store(in: root)) == day)
    }

    /// 导出的文件只含颜色、字体与名称标识，导入后与原主题一致；同名时必须确认覆盖，
    /// 标识与已有主题重复时换成新标识，无效文件不导入。
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

        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: exported)) as? [String: Any]
        )
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

        // 名称不同、标识与已有主题相同的文件换成新标识，两个主题并存。
        var twin = replaced
        twin.name = "Twin"
        try twin.encoded().write(to: exported)
        #expect(try store.importTheme(at: exported, replacing: false).id != theme.id)

        // 无法解码与缺少颜色的文件都算无效，不写入 Themes 目录。
        try Data("not json".utf8).write(to: exported)
        #expect(throws: ThemeStoreError.invalidFile) {
            try store.importTheme(at: exported, replacing: false)
        }

        var incomplete = twin
        incomplete.name = "Incomplete"
        incomplete.colors["added"] = nil
        try incomplete.encoded().write(to: exported)

        #expect(throws: ThemeStoreError.invalidFile) {
            try store.importTheme(at: exported, replacing: false)
        }
        #expect(try Self.themeFiles(root) == ["Harbor.spookytheme", "Twin.spookytheme"])
    }

    /// 所选主题丢失、损坏或与其它主题重复时，按名称回退到目录里的 Default 或 Default (Dark)，而不是资源里的版本；
    /// 它们的文件也损坏时用资源里的版本，损坏的文件列为无法加载。
    @Test("所选主题无法加载时按外观回退")
    func unloadableThemesFallBack() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try Self.store(in: root)
        try store.installDefaultThemes()

        // 编辑过的 Default (Dark) 与资源里的版本不同，回退时能分辨取的是哪一份。
        let edited = try #require(store.themes.first { $0.name == "Default (Dark)" })
        try store.update(edited.id) { $0.fontSize = 15 }

        let day = try #require(store.themes.first { $0.name == "Default" })
        let night = try #require(store.themes.first { $0.name == "Default (Dark)" })
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

        // 所选主题的文件损坏后，深色外观回到目录里编辑过的 Default (Dark)，浅色外观不受影响。
        try Data("{".utf8).write(to: file)

        var reopened = try Self.store(in: root)
        #expect(reopened.invalidFiles.map(\.lastPathComponent) == ["Ember.spookytheme"])
        #expect(TextTheme.current(dark: true, in: reopened) == night)
        #expect(TextTheme.current(dark: false, in: reopened) == day)

        // Default (Dark) 的文件也损坏时，深色外观用资源里的版本。
        try Data("{".utf8).write(to: Self.themes(root).appending(path: "Default (Dark).spookytheme"))
        reopened = try Self.store(in: root)
        #expect(TextTheme.current(dark: true, in: reopened) == TextTheme.builtin[1])

        // 偏好里记着已不存在的标识时同样按名称回退。
        reopened.select("missing", dark: false)
        #expect(TextTheme.current(dark: false, in: reopened) == day)

        // 新建主题不会覆盖占着文件名的损坏文件。
        #expect(try reopened.create(named: "Ember", dark: false).name == "Ember 2")
        #expect(try Data(contentsOf: file) == Data("{".utf8))
    }
}

// MARK: - Helpers

extension ThemeStoreTests {
    /// 新建一个临时目录，测试结束时由调用方删除。
    static func makeRoot() throws -> URL {
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
    static func themes(_ root: URL) -> URL {
        root.appending(path: "Themes", directoryHint: .isDirectory)
    }

    /// 使用临时目录里的 Themes 目录与偏好文件的存储；偏好以文件路径作 suite 名，随目录删除。
    static func store(in root: URL) throws -> ThemeStore {
        let defaults = try #require(UserDefaults(suiteName: root.appending(path: "defaults").path))
        return ThemeStore(directory: themes(root), defaults: defaults)
    }

    /// Themes 目录里的文件名，按名称排序。
    static func themeFiles(_ root: URL) throws -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: themes(root).path)) ?? []
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
