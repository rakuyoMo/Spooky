import Foundation
import Observation

// MARK: - ThemeStoreError

/// 主题文件读写中需要单独提示用户的失败。
enum ThemeStoreError: Error, Equatable {
    /// 文件不是可用的主题：无法解码，或缺少名称、标识与颜色。
    case invalidFile

    /// 另一个主题已经使用这个名称（按文件名比较，不区分大小写）。
    case nameInUse(String)

    /// 导入的目标位置已有同名主题文件，需要用户确认是否覆盖。
    case fileExists(URL)
}

// MARK: - ThemeStore

/// Themes 目录里的主题与两种外观的主题选择。
///
/// 一个主题一个文件，文件名取主题名称；浅色、深色外观分别记住所选主题的标识。
/// Default 与 Default (Dark) 在 App 启动时从资源写入，之后与其它主题一样可以编辑，但不能改名和删除。
@MainActor
@Observable
final class ThemeStore {
    /// App 使用的存储：Application Support 下的 `Spooky/Themes` 与标准偏好。
    static let shared = ThemeStore(
        directory: URL.applicationSupportDirectory.appending(path: "Spooky/Themes", directoryHint: .isDirectory),
        defaults: .standard
    )

    /// 主题所在的目录，首次写入时创建。
    let directory: URL

    /// 列表顺序：按名称排序的全部主题。
    private(set) var themes: [TextTheme] = []

    /// 无法加载的主题文件：无法解码，或名称、标识与已加载的主题重复。
    private(set) var invalidFiles: [URL] = []

    /// 浅色外观所选主题的标识；nil 表示按名称使用 Default。
    private(set) var lightThemeID: String? = nil

    /// 深色外观所选主题的标识；nil 表示按名称使用 Default (Dark)。
    private(set) var darkThemeID: String? = nil

    /// 记录外观选择的偏好域，测试使用临时目录里的独立域。
    @ObservationIgnored
    private let defaults: UserDefaults

    /// 主题标识到所在文件的对应；手动放进目录的文件，文件名可能与主题名称不同。
    @ObservationIgnored
    private var files: [String: URL] = [:]

    /// 读取偏好里的外观选择与目录里的主题文件。
    ///
    /// - Parameters:
    ///   - directory: 主题所在的目录。
    ///   - defaults: 记录外观选择的偏好域。
    init(directory: URL, defaults: UserDefaults) {
        self.directory = directory
        self.defaults = defaults
        lightThemeID = defaults.string(forKey: Self.lightKey)
        darkThemeID = defaults.string(forKey: Self.darkKey)
        reload()
    }

    /// 主题是否为 Default 或 Default (Dark)：按名称认出，不看标识；这两套可以编辑，不能改名、删除。
    static func isBuiltin(_ theme: TextTheme) -> Bool {
        TextTheme.builtin.contains { nameKey($0.name) == nameKey(theme.name) }
    }

    /// 重新读取 Themes 目录；名称或标识与先读到的主题重复的文件列为无法加载。
    func reload() {
        let urls =
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

        // 按文件名顺序依次登记，先读到的文件占用名称与标识。
        var names: Set<String> = []
        var identifiers: Set<String> = []
        var loaded: [TextTheme] = []
        var invalid: [URL] = []
        files = [:]

        let candidates = urls
            .filter { $0.pathExtension.lowercased() == TextTheme.fileExtension }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        for url in candidates {
            guard
                let data = try? Data(contentsOf: url),
                let theme = try? TextTheme.decode(data),
                !names.contains(Self.nameKey(theme.name)),
                !identifiers.contains(theme.id)
            else {
                invalid.append(url)
                continue
            }

            names.insert(Self.nameKey(theme.name))
            identifiers.insert(theme.id)
            files[theme.id] = url
            loaded.append(theme)
        }

        themes = Self.sorted(loaded)
        invalidFiles = invalid
    }

    /// 把资源里的 Default 与 Default (Dark) 写进 Themes 目录，App 启动时调用。
    ///
    /// 这个名称的文件缺少，或者读不出、解码失败时，用资源里的内容写入原位置。
    /// 已有这个名称的主题时不另写一份：内容仍是旧的默认配色就换成资源里的配色，用户改过的不动。
    /// 文件名被一份能加载、名称不同的主题占着时跳过；文件在 Finder 里被删掉后，下次启动重新写入。
    func installDefaultThemes() throws {
        for var theme in TextTheme.builtin {
            // 已有这个名称的主题时只核对它的配色，不另写一份。
            if let existing = themes.first(where: { Self.nameKey($0.name) == Self.nameKey(theme.name) }) {
                try replaceLegacyColors(of: existing, with: theme)
                continue
            }

            let standard = directory.appending(path: TextTheme.fileName(for: theme.name))

            // 无法加载的同名文件沿用它原来的文件名覆盖，文件名只差大小写时也不另起一份。
            let url = invalidFiles.first { Self.sameFile($0, standard) } ?? standard
            let loadable = (try? Data(contentsOf: url)).flatMap { try? TextTheme.decode($0) } != nil

            guard !loadable else {
                continue
            }

            // 目录里另一个主题仍用着资源里的标识时，新写入的这份换一个标识，两份文件不共用标识。
            if themes.contains(where: { $0.id == theme.id }) {
                theme.id = UUID().uuidString
            }

            try write(theme, to: url)
        }
    }

    /// 把主题设为一种外观的所选主题。
    func select(_ identifier: String, dark: Bool) {
        if dark {
            darkThemeID = identifier
        } else {
            lightThemeID = identifier
        }

        defaults.set(identifier, forKey: dark ? Self.darkKey : Self.lightKey)
    }

    /// 以资源里这一外观的内置主题为底新建主题，并设为这一外观的所选主题。
    ///
    /// - Parameters:
    ///   - baseName: 新主题的默认名称；已被占用时依次加上 2、3……
    ///   - dark: 新建时所在的外观。
    @discardableResult
    func create(named baseName: String, dark: Bool) throws -> TextTheme {
        var theme = TextTheme.builtin[dark ? 1 : 0]
        theme.id = UUID().uuidString
        theme.name = uniqueName(baseName)

        try write(theme, to: directory.appending(path: TextTheme.fileName(for: theme.name)))
        select(theme.id, dark: dark)
        return theme
    }

    /// 修改主题的字体或颜色并写回文件；目录里没有这个主题时不做改动。
    func update(_ identifier: String, _ change: (inout TextTheme) -> Void) throws {
        guard
            let index = themes.firstIndex(where: { $0.id == identifier }),
            let url = files[identifier]
        else { return }

        var theme = themes[index]
        change(&theme)
        try write(theme, to: url)
    }

    /// 改名并把文件移到新名称；内置主题、名称为空或未变时不做改动。
    func rename(_ identifier: String, to newName: String) throws {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let index = themes.firstIndex(where: { $0.id == identifier }),
            let url = files[identifier],
            !Self.isBuiltin(themes[index]),
            !name.isEmpty,
            name != themes[index].name
        else { return }

        guard !isNameInUse(name, except: identifier) else {
            throw ThemeStoreError.nameInUse(name)
        }

        var theme = themes[index]
        theme.name = name

        // 先在原文件写入新名称，再移动文件：只改大小写时新旧路径指向同一个文件，不能写新删旧。
        try write(theme, to: url)

        let destination = directory.appending(path: TextTheme.fileName(for: name))

        guard destination.lastPathComponent != url.lastPathComponent else {
            return
        }

        try FileManager.default.moveItem(at: url, to: destination)
        files[identifier] = destination
    }

    /// 删除主题的文件，删除时所在的外观改选列表的第一个主题；内置主题不做改动。
    ///
    /// 另一种外观选的也是它时，按名称回到 Default 或 Default (Dark)；列表删空时两种外观都按名称回退。
    ///
    /// - Parameters:
    ///   - identifier: 要删除的主题。
    ///   - dark: 删除时所在的外观。
    func delete(_ identifier: String, dark: Bool) throws {
        guard
            let url = files[identifier],
            let theme = themes.first(where: { $0.id == identifier }),
            !Self.isBuiltin(theme)
        else { return }

        try FileManager.default.removeItem(at: url)
        files[identifier] = nil
        themes.removeAll { $0.id == identifier }

        // 清掉指向它的外观选择，之后导入同标识的主题不会被直接选用。
        if lightThemeID == identifier {
            lightThemeID = nil
            defaults.removeObject(forKey: Self.lightKey)
        }

        if darkThemeID == identifier {
            darkThemeID = nil
            defaults.removeObject(forKey: Self.darkKey)
        }

        // 列表里选中的行被删掉后，所在外观改选第一行。
        if let first = themes.first {
            select(first.id, dark: dark)
        }
    }

    /// 导入一份主题文件，复制到 Themes 目录。
    ///
    /// 与已有主题同名时，不覆盖就抛出 `fileExists`；覆盖时沿用被覆盖主题的标识，外观选择不变。
    /// 标识与其它主题重复时换成新的标识。
    ///
    /// - Parameters:
    ///   - url: 要导入的文件。
    ///   - replacing: 用户已确认覆盖同名主题。
    @discardableResult
    func importTheme(at url: URL, replacing: Bool) throws -> TextTheme {
        var theme = try TextTheme.decode(Data(contentsOf: url))
        theme.name = theme.name.trimmingCharacters(in: .whitespacesAndNewlines)

        let existing = themes.first { Self.nameKey($0.name) == Self.nameKey(theme.name) }
        let destination = existing.flatMap { files[$0.id] }
            ?? directory.appending(path: TextTheme.fileName(for: theme.name))

        // 同名的主题与占着这个文件名的无法加载的文件，都要用户确认后才覆盖。
        let occupied = existing != nil || invalidFiles.contains { Self.sameFile($0, destination) }

        if occupied, !replacing {
            throw ThemeStoreError.fileExists(destination)
        }

        if let existing {
            theme.id = existing.id
        } else if themes.contains(where: { $0.id == theme.id }) {
            theme.id = UUID().uuidString
        }

        try write(theme, to: destination)
        return theme
    }

    /// 内置主题的内容仍是旧的默认配色时，换成资源里的配色写回原文件；标识、名称、文件名与外观选择不变。
    ///
    /// 字体、字号与全部颜色都等于旧配色才换，有任何一项不同就是用户改过，不动。
    ///
    /// - Parameters:
    ///   - theme: 目录里与内置主题同名的主题。
    ///   - builtin: 资源里的这一套内置主题。
    private func replaceLegacyColors(of theme: TextTheme, with builtin: TextTheme) throws {
        guard
            let changed = Self.legacyColors[builtin.id],
            let url = files[theme.id]
        else { return }

        // 旧配色只记了与资源不同的几种颜色，其余取资源里的值拼出完整的旧配色。
        let legacy = builtin.colors.merging(changed) { $1 }

        guard
            theme.fontName == builtin.fontName,
            theme.fontSize == builtin.fontSize,
            theme.colors == legacy
        else { return }

        var replaced = theme
        replaced.colors = builtin.colors
        try write(replaced, to: url)
    }

    /// 写入主题文件并更新列表；目录不存在时先创建。
    private func write(_ theme: TextTheme, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try theme.encoded().write(to: url, options: .atomic)

        files[theme.id] = url
        themes = Self.sorted(themes.filter { $0.id != theme.id } + [theme])

        // 覆盖了无法加载的文件时，它已换成可用的主题。
        invalidFiles.removeAll { Self.sameFile($0, url) }
    }

    /// 在名称后依次加上 2、3……直到不与任何主题重名。
    private func uniqueName(_ base: String) -> String {
        var name = base
        var number = 2

        while isNameInUse(name, except: nil) {
            name = base + " " + String(number)
            number += 1
        }

        return name
    }

    /// 名称是否已被其它主题使用；无法加载的文件同样占着它的文件名。
    private func isNameInUse(_ name: String, except identifier: String?) -> Bool {
        let key = Self.nameKey(name)
        let usedByTheme = themes.contains { $0.id != identifier && Self.nameKey($0.name) == key }
        let usedByFile = invalidFiles.contains { $0.lastPathComponent.lowercased() == key }

        return usedByTheme || usedByFile
    }
}

// MARK: - Helpers

extension ThemeStore {
    /// 浅色外观所选主题的偏好键。
    private static let lightKey = "lightTheme"

    /// 深色外观所选主题的偏好键。
    private static let darkKey = "darkTheme"

    /// 换用现在的默认配色之前写进 Themes 目录的内置主题里，与资源不同的那几种颜色，按内置主题的标识分组。
    private static let legacyColors: [String: [String: PaletteColor]] = {
        guard
            let url = Bundle.module.url(forResource: "LegacyBuiltinThemeColors", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let colors = try? JSONDecoder().decode([String: [String: PaletteColor]].self, from: data)
        else { preconditionFailure("内置主题的旧配色资源无法读取") }

        return colors
    }()

    /// 主题按名称的自然顺序排列。
    private static func sorted(_ themes: [TextTheme]) -> [TextTheme] {
        themes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 比较重名用的键：主题名称对应的文件名，不区分大小写，与 APFS 默认的文件名规则一致。
    private static func nameKey(_ name: String) -> String {
        TextTheme.fileName(for: name.trimmingCharacters(in: .whitespacesAndNewlines)).lowercased()
    }

    /// 同一目录下的两个文件名是否指向同一个文件，不区分大小写。
    private static func sameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.lastPathComponent.lowercased() == rhs.lastPathComponent.lowercased()
    }
}
