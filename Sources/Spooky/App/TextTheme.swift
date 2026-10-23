import AppKit
import UniformTypeIdentifiers

// MARK: - TextTheme

/// 文本区主题：Diff 等文本视图的字体与颜色；内置主题与用户主题共用这一结构，也是主题文件的内容。
struct TextTheme: Codable, Identifiable, Sendable, Equatable {
    /// 主题文件里标识的键名为 `identifier`，其余与属性同名。
    private enum CodingKeys: String, CodingKey {
        case id = "identifier"
        case name
        case fontName
        case fontSize
        case colors
    }

    /// 主题文件的扩展名。
    static let fileExtension = "spookytheme"

    /// 主题文件的类型：扩展名为 `spookytheme` 的 JSON。
    static let fileType = UTType(filenameExtension: fileExtension, conformingTo: .json) ?? .json

    /// 随应用交付的 Default 与 Default (Dark)，只读。
    static let builtin: [Self] = {
        guard
            let url = Bundle.module.url(forResource: "BuiltinThemes", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let themes = try? JSONDecoder().decode([Self].self, from: data)
        else { preconditionFailure("内置主题资源无法读取") }
        return themes
    }()

    /// 主题标识：内置主题是固定字符串，用户主题是新建时生成的 UUID；外观的主题选择按它记录。
    var id: String

    /// 列表里显示、也用作文件名的主题名称。
    var name: String

    /// 文本区字体的 PostScript 名称。
    var fontName: String

    /// 文本区字号，单位 pt。
    var fontSize: Double

    /// 正文、背景、选区、不可见字符、增删行及各语法色，键与 `BuiltinThemes.json` 一致。
    var colors: [String: PaletteColor]

    /// 内置主题不能编辑、改名或删除。
    var isBuiltin: Bool { Self.builtin.contains { $0.id == id } }

    /// 文本区使用的字体；字体未安装时用系统等宽字体代替，字号不变。
    var font: NSFont {
        NSFont(name: fontName, size: fontSize) ?? .userFixedPitchFont(ofSize: fontSize)
            ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    /// 按外观取当前主题：所选主题丢失或无法加载时，回退到这一外观对应的内置主题。
    ///
    /// 读取的是可观察的主题存储，视图在 `body` 里调用即可随编辑、切换与外观变化刷新。
    ///
    /// - Parameters:
    ///   - dark: 是否为深色外观。
    ///   - store: 主题存储，测试传入使用临时目录的实例。
    @MainActor
    static func current(dark: Bool, in store: ThemeStore = .shared) -> Self {
        let selected = dark ? store.darkThemeID : store.lightThemeID

        return store.themes.first { $0.id == selected } ?? builtin[dark ? 1 : 0]
    }

    /// 解码并校验一份主题文件：名称与标识不能为空，字号为正，内置主题的每种颜色都要有合法的值。
    static func decode(_ data: Data) throws -> Self {
        let requiredColors = Set(builtin[0].colors.keys)

        // 缺少任一颜色的主题会让文本区出现无色的部分，与无法解码同样处理。
        guard
            let theme = try? JSONDecoder().decode(Self.self, from: data),
            !theme.id.isEmpty,
            !theme.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            theme.fontSize.isFinite,
            theme.fontSize > 0,
            requiredColors.isSubset(of: theme.colors.keys),
            theme.colors.values.allSatisfy(\.isValid)
        else { throw ThemeStoreError.invalidFile }

        return theme
    }

    /// 主题名称对应的文件名；`/` 与 `:` 不能出现在文件名里，换成 `-`。
    static func fileName(for name: String) -> String {
        let safe = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        return safe + "." + fileExtension
    }

    /// 主题文件的内容：键名排序、缩进排版，便于用户查看与比较。
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
