import Foundation

// MARK: - SyntaxStyle

/// 语法片段的类别，原始值即主题里的颜色键。
enum SyntaxStyle: String, Sendable {
    /// 关键字、字面量、内置名与类型。
    case keyword

    /// 名称、变量、参数与符号。
    case identifier

    /// 数字。
    case number

    /// 字符串与正则表达式。
    case string

    /// 注释。
    case comment

    /// 预处理指令、注解等元信息。
    case preprocessor

    /// 标记语言的标签与标签名。
    case xmlTag

    /// 属性名、样式表的属性与配置文件的键。
    case attributeName

    /// 样式表的选择器。
    case cssSelector

    /// 运算符、标点与列表符号。
    case delimiter

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

    #warning(
        "TODO: 核实记号类别到颜色键的映射：keyword、params、bullet、attribute、selector 五组各自的成员已确定，每组对应的颜色键与其余类别的取舍是推断；用同一份文件逐类比对记号颜色，影响全部语言的着色"
    )

    /// highlight.js 记号类别对应的颜色，键是类名 `hljs-` 之后、第一个空格之前的部分。
    ///
    /// 表里没有的类别（如字符串里的插值）沿用外层记号的颜色，与样式表的颜色继承一致。
    static let scopes: [String: Self] = [
        "keyword": .keyword,
        "built_in": .keyword,
        "literal": .keyword,
        "type": .keyword,

        "params": .identifier,
        "symbol": .identifier,
        "title": .identifier,
        "variable": .identifier,

        "bullet": .delimiter,
        "operator": .delimiter,
        "punctuation": .delimiter,

        "attribute": .attributeName,
        "attr": .attributeName,

        "selector-attr": .cssSelector,
        "selector-class": .cssSelector,
        "selector-id": .cssSelector,
        "selector-pseudo": .cssSelector,
        "selector-tag": .cssSelector,

        "number": .number,
        "string": .string,
        "regexp": .string,
        "comment": .comment,
        "meta": .preprocessor,
        "tag": .xmlTag,
        "name": .xmlTag,
        "section": .heading,
        "emphasis": .emphasized,
        "strong": .stronglyEmphasized,
        "code": .codeBlock,
        "link": .url,
    ]
}

// MARK: - SyntaxSpan

/// 一行中连续的一段同类文字，长度按 UTF-16 计，没有类别的片段按正文显示。
struct SyntaxSpan: Sendable, Equatable {
    /// 片段长度。
    let length: Int

    /// 片段类别。
    let style: SyntaxStyle?
}

// MARK: - SyntaxActor

/// 语法着色专用的全局 actor：highlight.js 的 JavaScript 上下文只在它的串行队列上使用，着色依次在后台执行。
@globalActor
actor SyntaxActor {
    /// 唯一实例。
    static let shared = SyntaxActor()

    /// 执行全部识别与着色的串行队列。
    private let queue = DispatchSerialQueue(label: "com.rakuyo.spooky.syntax", qos: .userInitiated)

    /// actor 的任务都在串行队列上执行。
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }
}

// MARK: - SyntaxHighlighter

/// 语法着色的入口：按路径与内容识别 highlight.js 的语言，再把整段文本切成每行的片段；Diff、Blame 与原文视图共用。
enum SyntaxHighlighter {
    /// 扩展名无法识别时，只对不超过这个字节数的内容按内容识别语言。
    static let unknownFileLimit = 20_000

    /// highlight.js 不按文件名识别，这些没有扩展名的常见文件按完整文件名对应语言。
    private static let fileNames = [
        "Makefile": "makefile",
        "makefile": "makefile",
        "GNUmakefile": "makefile",
        "Dockerfile": "dockerfile",
        "Containerfile": "dockerfile",
        "Gemfile": "ruby",
        "Rakefile": "ruby",
        "Podfile": "ruby",
        "Fastfile": "ruby",
        "Brewfile": "ruby",
        ".bashrc": "bash",
        ".zshrc": "bash",
        ".profile": "bash",
        ".bash_profile": "bash",
        ".zprofile": "bash",
        ".babelrc": "json",
        ".eslintrc": "json",
        ".gitconfig": "ini",
        ".gitmodules": "ini",
        ".editorconfig": "ini",
    ]

    /// highlight.js 的别名没有覆盖、或对应到其它语言的小写扩展名，先于它的别名查找。
    private static let extensions = [
        "m": "objectivec",
        "pch": "objectivec",
        "sc": "scala",
        "pyw": "python",
        "pyi": "python",
        "rake": "ruby",
        "t": "perl",
        "ksh": "bash",
        "command": "bash",
        "geojson": "json",
        "webmanifest": "json",
        "cfg": "ini",
        "conf": "ini",
        "editorconfig": "ini",
        "xib": "xml",
        "storyboard": "xml",
        "xcscheme": "xml",
        "xcworkspacedata": "xml",
        "xslt": "xml",
        "entitlements": "xml",
        "stringsdict": "xml",
        "csproj": "xml",
        "resx": "xml",
        "htm": "xml",
        "vue": "xml",
        "sass": "css",
        "mdown": "markdown",
    ]

    /// 首行 `#!` 中的解释器对应的语言。
    private static let interpreters = [
        "node": "javascript",
        "python": "python",
        "ruby": "ruby",
        "php": "php",
        "perl": "perl",
        "lua": "lua",
        "sh": "bash",
        "bash": "bash",
        "zsh": "bash",
        "ksh": "bash",
        "dash": "bash",
    ]

    /// 首次识别或着色时才载入的 highlight.js。
    @SyntaxActor
    private static var runtime: HighlightRuntime?

    /// 识别文件的语言；识别不了时为空，调用方按纯文本显示。
    ///
    /// 依次按完整文件名、扩展名、首行 `#!` 的解释器识别；都不认识时由 highlight.js 按内容判断。
    /// 扩展名对应纯文本时不着色，也不再按内容判断。
    ///
    /// - Parameters:
    ///   - path: 仓库内的路径。
    ///   - content: 文件内容；为空或超过 `unknownFileLimit` 时不按内容识别。
    /// - Returns: highlight.js 的语言名，如 `swift`。
    @SyntaxActor
    static func language(forPath path: String, content: String?) -> String? {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        let pathExtension = name.lastIndex(of: ".").map { name[name.index(after: $0)...].lowercased() } ?? ""

        // 没有扩展名的常见文件按完整文件名识别
        if let language = fileNames[name] {
            return language
        }

        // 自带的扩展名表先于 highlight.js 的别名；扩展名对应纯文本时直接按纯文本显示
        if !pathExtension.isEmpty {
            if let language = extensions[pathExtension] {
                return language
            }

            if let language = loadedRuntime().language(named: pathExtension) {
                return language == HighlightRuntime.plaintext ? nil : language
            }
        }

        // 扩展名不认识时才看内容：先看首行的 `#!`，再由 highlight.js 判断
        guard let content, content.utf8.count <= unknownFileLimit else {
            return nil
        }

        return interpreterLanguage(of: content) ?? loadedRuntime().detectLanguage(in: content)
    }

    /// 给整段文本着色。
    ///
    /// 着色在串行队列上排队执行；排到时所在任务已经取消（视图换掉了内容），直接跳过。
    ///
    /// - Parameters:
    ///   - text: 以 `\n` 分行的全文。
    ///   - language: `language(forPath:content:)` 识别出的语言。
    /// - Returns: 与文本行一一对应的片段，每行的片段依次覆盖整行；任务已取消或着色失败时为空。
    @SyntaxActor
    static func highlight(_ text: String, as language: String) -> [[SyntaxSpan]] {
        guard !Task.isCancelled else {
            return []
        }

        return loadedRuntime().highlight(text, as: language) ?? []
    }

    /// 首次使用时载入 highlight.js，之后一直复用同一个上下文。
    @SyntaxActor
    private static func loadedRuntime() -> HighlightRuntime {
        if let runtime {
            return runtime
        }

        let loaded = HighlightRuntime()
        runtime = loaded
        return loaded
    }

    /// 按首行 `#!` 的解释器识别，`/usr/bin/env python3` 与 `/bin/bash` 都能对应。
    private static func interpreterLanguage(of content: String) -> String? {
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

        return program
            .map { $0.trimmingCharacters(in: versionCharacters) }
            .flatMap { interpreters[$0] }
    }
}
