import Foundation
import JavaScriptCore

// MARK: - HighlightRuntime

/// 载入了 highlight.js 全部语言的 JavaScript 上下文，负责语言名查找、按内容识别与着色。
///
/// 只在 `SyntaxActor` 上创建和使用，同一个上下文不会被多个线程同时使用。
@SyntaxActor
final class HighlightRuntime {
    /// highlight.js 里纯文本的语言名，按它着色没有任何记号。
    static let plaintext = "plaintext"

    /// 运行脚本的上下文。
    private let context: JSContext

    /// 脚本里的全局对象 `hljs`。
    private let hljs: JSValue

    /// 小写的语言名与别名对应的语言名。
    private let names: [String: String]

    /// 按内容识别时参与比较的语言：核心脚本自带的常用语言。
    ///
    /// 全部语言一起比较时，常见代码也常被判成冷门语言，耗时也成倍增加。
    private let detectionCandidates: [String]

    /// 依次执行核心脚本与其余各语言的脚本；随应用交付的脚本无法执行时直接终止。
    init() {
        guard
            let directory = Bundle.module.url(forResource: "HighlightJS", withExtension: nil),
            let context = JSContext()
        else { preconditionFailure("highlight.js 无法载入") }

        let core = directory.appending(path: "highlight.min.js")
        let languages = (try? FileManager.default.contentsOfDirectory(
            at: directory.appending(path: "languages"),
            includingPropertiesForKeys: nil
        )) ?? []

        Self.evaluate(core, in: context)

        let hljs: JSValue = context.objectForKeyedSubscript("hljs")
        detectionCandidates = Self.languageList(of: hljs)

        // 其余语言各有一个脚本，执行时注册到同一个 hljs
        for file in languages.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            Self.evaluate(file, in: context)
        }

        self.context = context
        self.hljs = hljs
        names = Self.languageNames(of: hljs)
    }

    /// 按语言名或别名查找语言，不区分大小写，规则与 highlight.js 的 `getLanguage` 相同。
    func language(named name: String) -> String? {
        names[name.lowercased()]
    }

    /// 由 highlight.js 在常用语言中按内容判断语言；判断不出时为空。
    func detectLanguage(in text: String) -> String? {
        let result = hljs.invokeMethod("highlightAuto", withArguments: [text, detectionCandidates])

        defer { context.exception = nil }

        guard
            context.exception == nil,
            let language = result?.forProperty("language"),
            language.isString
        else { return nil }

        return language.toString()
    }

    /// 给整段文本着色，把 highlight.js 输出的 HTML 按行还原成片段。
    ///
    /// - Returns: 与文本行一一对应的片段；脚本出错时为空。
    func highlight(_ text: String, as language: String) -> [[SyntaxSpan]]? {
        let options: [String: Any] = ["language": language, "ignoreIllegals": true]
        let result = hljs.invokeMethod("highlight", withArguments: [text, options])

        // 未知语言等异常按纯文本处理
        guard
            context.exception == nil,
            let html = result?.forProperty("value"),
            html.isString,
            let string = JSValueToStringCopy(context.jsGlobalContextRef, html.jsValueRef, nil)
        else {
            context.exception = nil
            return nil
        }

        defer { JSStringRelease(string) }

        // 直接读取脚本字符串的 UTF-16 码元，不再转成 Swift 字符串
        let units = UnsafeBufferPointer(
            start: JSStringGetCharactersPtr(string),
            count: JSStringGetLength(string)
        )

        return HighlightMarkup.lines(of: units)
    }
}

// MARK: - Loading

extension HighlightRuntime {
    /// 执行一个随应用交付的脚本；读不到或执行出错时直接终止。
    private static func evaluate(_ file: URL, in context: JSContext) {
        guard let script = try? String(contentsOf: file, encoding: .utf8) else {
            preconditionFailure("highlight.js 无法载入")
        }

        context.evaluateScript(script, withSourceURL: file)

        guard context.exception == nil else {
            preconditionFailure("highlight.js 无法载入")
        }
    }

    /// 已注册的全部语言名。
    private static func languageList(of hljs: JSValue) -> [String] {
        hljs.invokeMethod("listLanguages", withArguments: [])?.toArray() as? [String] ?? []
    }

    /// 按 highlight.js 的规则建立名称表：后注册语言的别名覆盖先注册的，语言名优先于别名。
    private static func languageNames(of hljs: JSValue) -> [String: String] {
        let languages = languageList(of: hljs)
        var names: [String: String] = [:]

        for language in languages {
            let definition = hljs.invokeMethod("getLanguage", withArguments: [language])
            let aliases = definition?.forProperty("aliases")?.toArray() as? [String] ?? []

            for alias in aliases {
                names[alias.lowercased()] = language
            }
        }

        for language in languages {
            names[language] = language
        }

        return names
    }
}
