import Foundation

// MARK: - SyntaxStyle

/// 语法片段的类别，原始值即主题里的颜色键。
enum SyntaxStyle: String, Sendable {
    /// 关键字与字面量。
    case keyword

    /// 类型等其它标识符。
    case identifier

    /// 函数名与调用。
    case function

    /// 数字。
    case number

    /// 字符串。
    case string

    /// 注释。
    case comment

    /// 预处理指令与注解。
    case preprocessor

    /// 标记语言的标签名。
    case xmlTag

    /// 标记语言的属性名、配置文件的键。
    case attributeName

    /// 标记语言的属性值。
    case attributeValue

    /// 样式表的选择器。
    case cssSelector

    /// 文档标题。
    case heading

    /// 斜体强调。
    case emphasized

    /// 粗体强调。
    case stronglyEmphasized

    /// 行内代码与代码块。
    case codeBlock

    /// 链接地址。
    case url
}

// MARK: - SyntaxSpan

/// 一行中连续的一段同类文字，长度按 UTF-16 计，没有类别的片段按正文显示。
struct SyntaxSpan: Sendable, Equatable {
    /// 片段长度。
    let length: Int

    /// 片段类别。
    let style: SyntaxStyle?
}

// MARK: - SyntaxLanguage

/// 一种语言的着色规则，数据来自资源 `SyntaxLanguages.json`。
struct SyntaxLanguage: Decodable, Sendable {
    /// 扫描方式。
    enum Kind: String, Decodable, Sendable {
        /// 程序语言与配置文件：注释、字符串、数字与关键字。
        case code

        /// XML 与 HTML：标签、属性与注释。
        case markup

        /// 样式表：选择器、属性与值。
        case css

        /// Markdown：标题、强调、代码与链接。
        case markdown
    }

    /// 资源中的字段名。
    private enum CodingKeys: String, CodingKey {
        case name
        case kind
        case extensions
        case fileNames
        case interpreters
        case lineComments
        case blockComments
        case strings
        case preprocessor
        case attributePrefix
        case variablePrefix
        case capitalizedTypes
        case caseInsensitiveKeywords
        case keys
        case sections
        case keywords
    }

    /// 语言名。
    let name: String

    /// 扫描方式。
    let kind: Kind

    /// 小写的文件扩展名。
    let extensions: [String]

    /// 没有扩展名时按完整文件名识别，如 `Makefile`。
    let fileNames: [String]

    /// 首行 `#!` 中的解释器名，如 `python`。
    let interpreters: [String]

    /// 行注释的起始标记。
    let lineComments: [String]

    /// 块注释的起止标记。
    let blockComments: [[String]]

    /// 字符串的定界符，起止相同；较长的定界符排在前面。
    let strings: [String]

    /// 位于行首时整行是预处理指令的字符，如 C 的 `#`。
    let preprocessor: String?

    /// 注解的前缀，如 Swift 的 `@`。
    let attributePrefix: String?

    /// 变量的前缀，如 Shell 的 `$`。
    let variablePrefix: String?

    /// 首字母大写的标识符按类型着色。
    let capitalizedTypes: Bool

    /// 关键字不区分大小写。
    let caseInsensitiveKeywords: Bool

    /// 键的写法：`string` 是冒号前的字符串，`colon` 是行首冒号前的词，`equals` 是行首等号前的词。
    let keys: String?

    /// 行首方括号是分节标题，如 INI 的 `[core]`。
    let sections: Bool

    /// 关键字与字面量。
    let keywords: Set<String>

    /// 资源里省略的字段按空值或否处理。
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(Kind.self, forKey: .kind)
        extensions = try container.decodeIfPresent([String].self, forKey: .extensions) ?? []
        fileNames = try container.decodeIfPresent([String].self, forKey: .fileNames) ?? []
        interpreters = try container.decodeIfPresent([String].self, forKey: .interpreters) ?? []
        lineComments = try container.decodeIfPresent([String].self, forKey: .lineComments) ?? []
        blockComments = try container.decodeIfPresent([[String]].self, forKey: .blockComments) ?? []
        strings = try container.decodeIfPresent([String].self, forKey: .strings) ?? []
        preprocessor = try container.decodeIfPresent(String.self, forKey: .preprocessor)
        attributePrefix = try container.decodeIfPresent(String.self, forKey: .attributePrefix)
        variablePrefix = try container.decodeIfPresent(String.self, forKey: .variablePrefix)
        capitalizedTypes = try container.decodeIfPresent(Bool.self, forKey: .capitalizedTypes) ?? false
        caseInsensitiveKeywords = try container.decodeIfPresent(Bool.self, forKey: .caseInsensitiveKeywords) ?? false
        keys = try container.decodeIfPresent(String.self, forKey: .keys)
        sections = try container.decodeIfPresent(Bool.self, forKey: .sections) ?? false

        // 不区分大小写的语言统一按小写比较
        let words = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        keywords = Set(caseInsensitiveKeywords ? words.map { $0.lowercased() } : words)
    }
}

// MARK: - SyntaxHighlighter

/// 语法着色的入口：按路径与内容识别语言，再把整段文本切成每行的片段；Diff、Blame 与原文视图共用。
enum SyntaxHighlighter {
    /// 扩展名无法识别时，只对不超过这个字节数的内容按首行判断语言。
    static let unknownFileLimit = 20_000

    /// 随应用交付的全部语言。
    static let languages: [SyntaxLanguage] = {
        guard
            let url = Bundle.module.url(forResource: "SyntaxLanguages", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let languages = try? JSONDecoder().decode([SyntaxLanguage].self, from: data)
        else { preconditionFailure("语法着色资源无法读取") }

        return languages
    }()

    /// 识别文件的语言；识别不了时为空，调用方按纯文本显示。
    ///
    /// - Parameters:
    ///   - path: 仓库内的路径，先按文件名，再按扩展名识别。
    ///   - content: 文件内容，扩展名无法识别时读取首行的 `#!`；为空时不按内容识别。
    static func language(forPath path: String, content: String?) -> SyntaxLanguage? {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        let pathExtension = name.lastIndex(of: ".").map { name[name.index(after: $0)...].lowercased() } ?? ""

        if let language = languages.first(where: { $0.fileNames.contains(name) }) {
            return language
        }

        if
            !pathExtension.isEmpty,
            let language = languages.first(where: { $0.extensions.contains(pathExtension) })
        {
            return language
        }

        guard let content, content.utf8.count <= unknownFileLimit else {
            return nil
        }

        return interpreterLanguage(of: content)
    }

    /// 给整段文本着色。
    ///
    /// - Parameters:
    ///   - text: 以 `\n` 分行的全文。
    ///   - language: 已识别的语言。
    /// - Returns: 与文本行一一对应的片段，每行的片段依次覆盖整行。
    static func highlight(_ text: String, as language: SyntaxLanguage) -> [[SyntaxSpan]] {
        var scanner = SyntaxScanner(units: Array(text.utf16), language: language)
        scanner.scan()
        return scanner.lines
    }

    /// 按首行 `#!` 的解释器识别，`/usr/bin/env python3` 与 `/bin/bash` 都能对应。
    private static func interpreterLanguage(of content: String) -> SyntaxLanguage? {
        guard content.hasPrefix("#!") else {
            return nil
        }

        let firstLine = content.dropFirst(2).prefix { $0 != "\n" }
        let words = firstLine
            .split(separator: " ")
            .map { $0.split(separator: "/").last.map(String.init) ?? "" }

        // env 之后的第一个非选项参数才是解释器
        let program = words.first == "env" ? words.dropFirst().first { !$0.hasPrefix("-") } : words.first

        // python3、python3.12 这类带版本号的名字按去掉版本号后的名字匹配
        let versionCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
        let interpreter = program?.trimmingCharacters(in: versionCharacters)

        return languages.first { language in
            language.interpreters.contains { $0 == interpreter }
        }
    }
}
