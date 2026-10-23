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

/// 用户主题与两种外观的主题选择。
///
/// 用户主题放在 Themes 目录，一个主题一个文件，文件名取主题名称；
/// 浅色、深色外观分别记住所选主题的标识。内置主题来自应用资源，不写进目录。
@MainActor
@Observable
final class ThemeStore {
    /// App 使用的存储：Application Support 下的 `Spooky/Themes` 与标准偏好。
    static let shared = ThemeStore(
        directory: URL.applicationSupportDirectory.appending(path: "Spooky/Themes", directoryHint: .isDirectory),
        defaults: .standard
    )

    /// 用户主题所在的目录，首次写入时创建。
    let directory: URL

    /// 按名称排序的用户主题。
    private(set) var userThemes: [TextTheme] = []

    /// 无法加载的主题文件：无法解码，或名称、标识与已加载的主题重复。
    private(set) var invalidFiles: [URL] = []

    /// 浅色外观所选主题的标识；nil 表示使用 Default。
    private(set) var lightThemeID: String? = nil

    /// 深色外观所选主题的标识；nil 表示使用 Default (Dark)。
    private(set) var darkThemeID: String? = nil

    /// 记录外观选择的偏好域，测试使用临时目录里的独立域。
    @ObservationIgnored
    private let defaults: UserDefaults

    /// 用户主题标识到所在文件的对应；手动放进目录的文件，文件名可能与主题名称不同。
    @ObservationIgnored
    private var files: [String: URL] = [:]

    /// 列表顺序：两套内置主题在前，用户主题随后。
    var themes: [TextTheme] { TextTheme.builtin + userThemes }

    /// 读取偏好里的外观选择与目录里的主题文件。
    ///
    /// - Parameters:
    ///   - directory: 用户主题所在的目录。
    ///   - defaults: 记录外观选择的偏好域。
    init(directory: URL, defaults: UserDefaults) {
        self.directory = directory
        self.defaults = defaults
        lightThemeID = defaults.string(forKey: Self.lightKey)
        darkThemeID = defaults.string(forKey: Self.darkKey)
        reload()
    }

    /// 重新读取 Themes 目录；名称或标识与先读到的主题重复的文件列为无法加载。
    func reload() {
        let urls =
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

        // 内置主题先占用名称与标识，用户文件按文件名顺序依次登记。
        var names = Set(TextTheme.builtin.map { Self.nameKey($0.name) })
        var identifiers = Set(TextTheme.builtin.map(\.id))
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

        userThemes = Self.sorted(loaded)
        invalidFiles = invalid
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

    /// 以这一外观的内置主题为底新建主题，并设为这一外观的所选主题。
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

    /// 修改用户主题的字体或颜色并写回文件；内置主题只读，不做改动。
    func update(_ identifier: String, _ change: (inout TextTheme) -> Void) throws {
        guard
            let index = userThemes.firstIndex(where: { $0.id == identifier }),
            let url = files[identifier]
        else { return }

        var theme = userThemes[index]
        change(&theme)
        try write(theme, to: url)
    }

    /// 改名并把文件移到新名称；名称为空或未变时不做改动。
    func rename(_ identifier: String, to newName: String) throws {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let index = userThemes.firstIndex(where: { $0.id == identifier }),
            let url = files[identifier],
            !name.isEmpty,
            name != userThemes[index].name
        else { return }

        guard !isNameInUse(name, except: identifier) else {
            throw ThemeStoreError.nameInUse(name)
        }

        var theme = userThemes[index]
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

    /// 删除用户主题的文件；选用它的外观回到对应的内置主题。
    func delete(_ identifier: String) throws {
        guard let url = files[identifier] else {
            return
        }

        try FileManager.default.removeItem(at: url)
        files[identifier] = nil
        userThemes.removeAll { $0.id == identifier }

        // 清掉指向它的外观选择，之后导入同标识的主题不会被直接选用。
        if lightThemeID == identifier {
            lightThemeID = nil
            defaults.removeObject(forKey: Self.lightKey)
        }

        if darkThemeID == identifier {
            darkThemeID = nil
            defaults.removeObject(forKey: Self.darkKey)
        }
    }

    /// 导入一份主题文件，复制到 Themes 目录。
    ///
    /// 与用户主题同名时，不覆盖就抛出 `fileExists`；覆盖时沿用被覆盖主题的标识，外观选择不变。
    /// 与内置主题同名时改用带编号的名称；标识与其它主题重复时换成新的标识。
    ///
    /// - Parameters:
    ///   - url: 要导入的文件。
    ///   - replacing: 用户已确认覆盖同名主题。
    @discardableResult
    func importTheme(at url: URL, replacing: Bool) throws -> TextTheme {
        var theme = try TextTheme.decode(Data(contentsOf: url))
        theme.name = theme.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if TextTheme.builtin.contains(where: { Self.nameKey($0.name) == Self.nameKey(theme.name) }) {
            theme.name = uniqueName(theme.name)
        }

        let existing = userThemes.first { Self.nameKey($0.name) == Self.nameKey(theme.name) }
        let destination = existing.flatMap { files[$0.id] }
            ?? directory.appending(path: TextTheme.fileName(for: theme.name))

        // 同名的用户主题与占着这个文件名的无法加载的文件，都要用户确认后才覆盖。
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

    /// 写入主题文件并更新列表；目录不存在时先创建。
    private func write(_ theme: TextTheme, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try theme.encoded().write(to: url, options: .atomic)

        files[theme.id] = url
        userThemes = Self.sorted(userThemes.filter { $0.id != theme.id } + [theme])

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

    /// 名称是否已被其它主题使用，内置主题也算在内；无法加载的文件同样占着它的文件名。
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

    /// 用户主题按名称的自然顺序排列。
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
