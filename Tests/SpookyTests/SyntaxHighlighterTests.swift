import Foundation
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - SyntaxHighlighterTests

/// 语法着色必须识别出常见语言、识别失败时退回纯文本，且每行的片段与原文逐码元对齐，否则颜色会错位。
struct SyntaxHighlighterTests {
    /// 记号按类别映射到主题的颜色键；块注释切到所跨的每一行，字符串里的转义沿用字符串的颜色；分层的函数类别覆盖名称色，没有颜色规则的记号沿用正文。
    @Test("程序语言的记号、跨行注释与类别回退")
    func codeTokens() async throws {
        let text = "@MainActor func run(_ value: Int) {\n  /* 注释\n  继续 */ let s = \"a\\\"b\" + 42\n#if DEBUG\n}"
        let lines = await SyntaxHighlighter.highlight(text, as: "swift")

        try #require(lines.count == 5)

        #expect(styles(of: "@MainActor func run(_ value: Int) {", lines[0]) == [
            "@MainActor": .preprocessor,
            "func": .keyword,
            "run": .function,
            "_": .keyword,
            "value": .identifier,
            "Int": .keyword,
        ])

        #expect(styles(of: "  /* 注释", lines[1]) == ["/* 注释": .comment])

        let third = styles(of: "  继续 */ let s = \"a\\\"b\" + 42", lines[2])
        #expect(third["  继续 */"] == .comment)
        #expect(third["let"] == .keyword)
        #expect(third["="] == .symbol)
        #expect(third["\"a\\\"b\""] == .string)
        #expect(third["42"] == .number)
        #expect(styles(of: "#if DEBUG", lines[3]) == ["#if": .keyword, "DEBUG": .keyword])
        #expect(lines[4] == [SyntaxSpan(length: 1, style: nil)])

        // 函数调用的分层类别覆盖名称色，类名仍保持标识符色
        let rust = "fn main() { run(); }"
        let rustStyles = styles(of: rust, try #require(await SyntaxHighlighter.highlight(rust, as: "rust").first))
        #expect(rustStyles["main"] == .function)
        #expect(rustStyles["run"] == .function)

        let swift = "class A: B {}"
        let swiftStyles = styles(of: swift, try #require(await SyntaxHighlighter.highlight(swift, as: "swift").first))
        #expect(swiftStyles["A"] == .identifier)
        #expect(swiftStyles["B"] == .identifier)

        // 没有颜色规则的正则与名称沿用正文
        let javascript = "const re = /a+b/g;"
        let jsSpans = try #require(await SyntaxHighlighter.highlight(javascript, as: "javascript").first)
        #expect(styles(of: javascript, jsSpans)["/a+b/g"] == nil)

        let clojure = "(println \"x\")"
        let clojureSpans = try #require(await SyntaxHighlighter.highlight(clojure, as: "clojure").first)
        #expect(styles(of: clojure, clojureSpans)["println"] == nil)
    }

    /// 标签、属性、样式表、Markdown 与 JSON 的结构各自着色，代码块跨行延续；属性值按直接父类别取色。
    @Test("标记语言、样式表、Markdown 与 JSON")
    func documentTokens() async throws {
        let tag = "<view id=\"main\"/><!-- c -->"
        let xml = await SyntaxHighlighter.highlight(tag, as: "xml")
        try #require(xml.count == 1)

        #expect(styles(of: tag, xml[0]) == [
            "<view ": .xmlTag,
            "id": .attributeName,
            "=": .xmlTag,
            "\"main\"": .attributeValue,
            "/>": .xmlTag,
            "<!-- c -->": .comment,
        ])

        let rule = ".box { color: #fff; }"
        let css = await SyntaxHighlighter.highlight(rule, as: "css")
        try #require(css.count == 1)
        #expect(styles(of: rule, css[0]) == [".box": .cssSelector, "color": .attributeName, "#fff": .number])

        let document = "# 标题\n**粗** 与 `code` [链接](https://example.com)\n```\nlet x\n```"
        let markdown = await SyntaxHighlighter.highlight(document, as: "markdown")
        try #require(markdown.count == 5)
        #expect(styles(of: "# 标题", markdown[0]) == ["# 标题": .heading])

        let inline = styles(of: "**粗** 与 `code` [链接](https://example.com)", markdown[1])
        #expect(inline["**粗**"] == .stronglyEmphasized)
        #expect(inline["`code`"] == .codeBlock)
        #expect(inline["https://example.com"] == .url)
        #expect(styles(of: "let x", markdown[3]) == ["let x": .codeBlock])

        // JSON 的键、标点与字面量
        let object = "{\"a\": [1, true, null]}"
        let json = await SyntaxHighlighter.highlight(object, as: "json")
        try #require(json.count == 1)

        let jsonStyles = styles(of: object, json[0])
        #expect(jsonStyles["\"a\""] == .attributeName)
        #expect(jsonStyles["{"] == .symbol)
        #expect(jsonStyles[","] == .symbol)
        #expect(jsonStyles["1"] == .number)
        #expect(jsonStyles["true"] == .keyword)

        // XML 及嵌入的 XML 属性值使用独立颜色，声明与其它语法里的字符串保留字符串色
        let attributes: [(String, String, String, SyntaxStyle)] = [
            ("javascript", "render(<div className=\"a\">{run()}</div>);", "\"a\"", .attributeValue),
            ("xml", "<?xml version=\"1.0\"?>", "\"1.0\"", .string),
            ("javascript", "const value = \"Home\";", "\"Home\"", .string),
        ]

        for (language, line, token, style) in attributes {
            let spans = try #require(await SyntaxHighlighter.highlight(line, as: language).first)
            #expect(styles(of: line, spans)[token] == style)
        }
    }

    /// 任何输入下片段长度之和都等于该行的 UTF-16 长度：多字节字符、HTML 实体、CRLF、未闭合的字符串与回退成纯文本的文件都不例外。
    @Test("片段按 UTF-16 码元覆盖整行")
    func spanCoverage() async throws {
        // 中文与表情占的码元数不同于字符数，后面的记号不错位
        let line = "let 名 = \"中文😀\"; let x = 1 // 注释 😀"
        let swift = try #require(await SyntaxHighlighter.highlight(line, as: "swift").first)
        #expect(styles(of: line, swift)["\"中文😀\""] == .string)
        #expect(styles(of: line, swift)["1"] == .number)
        #expect(styles(of: line, swift)["// 注释 😀"] == .comment)
        #expect(swift.reduce(0) { $0 + $1.length } == line.utf16.count)

        // highlight.js 写成实体的 `&`、`<`、`>` 与引号各还原成原文的一个码元
        let condition = "if (a < b && c > \"d\") { e = 'f' }"
        let javascript = try #require(await SyntaxHighlighter.highlight(condition, as: "javascript").first)
        #expect(styles(of: condition, javascript)["'f'"] == .string)
        #expect(javascript.reduce(0) { $0 + $1.length } == condition.utf16.count)

        // 同一段混杂文本交给不同语言
        let text = "a = \"未闭合 😀\r\n<b x='1'># ${HOME} `t` **s\n"
            + "[x](y) /* 1.5e3 */ 0x1F @attr\n\n\t- key: [v] & &amp;"

        for pathExtension in ["swift", "py", "html", "md", "sh", "yml"] {
            let detected = await SyntaxHighlighter.language(forPath: "file." + pathExtension, content: nil)
            let language = try #require(detected)
            await expectCoverage(text, as: language)
        }

        // JSON 中非法的工程文件记号让整份文件回退成纯文本，仍保留全部行与长度
        let project = "// !$*UTF8*$!\n{\n  archiveVersion = 1;\n  value = \"中文😀\";\n}"
        let language = try #require(await SyntaxHighlighter.language(forPath: "project.pbxproj", content: project))
        let spans = await SyntaxHighlighter.highlight(project, as: language)
        let lines = project.components(separatedBy: "\n")
        #expect(spans.count == lines.count)

        for (line, lineSpans) in zip(lines, spans) {
            #expect(lineSpans == [SyntaxSpan(length: line.utf16.count, style: nil)])
        }
    }

    /// 视图换掉内容时任务被取消，排队中的着色直接跳过，不再占用串行队列。
    @Test("取消的着色直接跳过")
    func cancelledHighlight() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await SyntaxHighlighter.highlight("let x = 1", as: "swift")
        }

        #expect(await task.value.isEmpty)
        #expect(await SyntaxHighlighter.highlight("let x = 1", as: "swift").count == 1)
    }

    /// 一种语言下每行都有片段，长度之和等于该行的 UTF-16 长度。
    private func expectCoverage(_ text: String, as language: String) async {
        let lines = text.components(separatedBy: "\n")
        let spans = await SyntaxHighlighter.highlight(text, as: language)
        #expect(spans.count == lines.count)

        for (line, lineSpans) in zip(lines, spans) {
            #expect(lineSpans.reduce(0) { $0 + $1.length } == line.utf16.count)
        }
    }
}

// MARK: - Helpers

extension SyntaxHighlighterTests {
    /// 把一行的片段还原成 “文字 → 类别”，只保留有类别的片段。
    func styles(of line: String, _ spans: [SyntaxSpan]) -> [String: SyntaxStyle] {
        let units = Array(line.utf16)
        var offset = 0
        var result: [String: SyntaxStyle] = [:]

        for span in spans {
            let end = min(units.count, offset + span.length)

            if let style = span.style {
                result[String(decoding: units[offset ..< end], as: UTF16.self)] = style
            }

            offset = end
        }

        return result
    }
}
