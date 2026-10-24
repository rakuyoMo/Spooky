import Foundation
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - SyntaxHighlighterTests

/// 语法着色必须识别出常见语言、识别失败时退回纯文本，且每行的片段与原文逐码元对齐，否则颜色会错位。
struct SyntaxHighlighterTests {
    /// 完整文件名、自带的扩展名表、highlight.js 的别名与首行解释器依次决定语言，扩展名不区分大小写。
    @Test("按路径与解释器识别语言")
    func languageFromPath() async {
        #expect(await SyntaxHighlighter.language(forPath: "Sources/App.swift", content: nil) == "swift")
        #expect(await SyntaxHighlighter.language(forPath: "目录 一/Makefile", content: nil) == "makefile")
        #expect(await SyntaxHighlighter.language(forPath: "Gemfile", content: nil) == "ruby")
        #expect(await SyntaxHighlighter.language(forPath: "Info.PLIST", content: nil) == "xml")
        #expect(await SyntaxHighlighter.language(forPath: "Main.xib", content: nil) == "xml")
        #expect(await SyntaxHighlighter.language(forPath: "config.yml", content: nil) == "yaml")

        // highlight.js 把 m 当作另一种语言的别名，仓库里的 .m 文件仍按 Objective-C 着色
        #expect(await SyntaxHighlighter.language(forPath: "AppDelegate.m", content: nil) == "objectivec")

        let script = "#!/usr/bin/env python3\nprint(1)\n"
        #expect(await SyntaxHighlighter.language(forPath: "tool", content: script) == "python")
        #expect(await SyntaxHighlighter.language(forPath: "run", content: "#!/bin/bash -e\n") == "bash")
    }

    /// 扩展名不认识时由 highlight.js 按内容判断；超过大小上限、没有内容、扩展名对应纯文本或语言未知时按纯文本显示。
    @Test("按内容识别与纯文本回退")
    func languageFromContent() async {
        let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0">
            <dict>
              <key>Name</key>
              <string>Spooky</string>
            </dict>
            </plist>

            """

        #expect(await SyntaxHighlighter.language(forPath: "Contents", content: plist) == "xml")

        // 超过大小上限的未知类型文件不按内容判断，首行是 #! 也一样
        let padding = String(repeating: "x", count: SyntaxHighlighter.unknownFileLimit)
        #expect(await SyntaxHighlighter.language(forPath: "Contents", content: plist + padding) == nil)
        #expect(await SyntaxHighlighter.language(forPath: "data", content: "#!/bin/sh\n" + padding) == nil)

        #expect(await SyntaxHighlighter.language(forPath: "data", content: nil) == nil)
        #expect(await SyntaxHighlighter.language(forPath: "notes.unknown", content: nil) == nil)
        #expect(await SyntaxHighlighter.language(forPath: "notes.txt", content: plist) == nil)
        #expect(await SyntaxHighlighter.highlight(plist, as: "unknown-language").isEmpty)
    }

    /// 记号按类别映射到主题的颜色键；块注释切到所跨的每一行，字符串里的转义沿用字符串的颜色。
    @Test("程序语言的记号与跨行注释")
    func codeTokens() async throws {
        let text = "@MainActor func run(_ value: Int) {\n  /* 注释\n  继续 */ let s = \"a\\\"b\" + 42\n#if DEBUG\n}"
        let lines = await SyntaxHighlighter.highlight(text, as: "swift")

        try #require(lines.count == 5)

        #expect(styles(of: "@MainActor func run(_ value: Int) {", lines[0]) == [
            "@MainActor": .preprocessor,
            "func": .keyword,
            "run": .identifier,
            "_": .keyword,
            "value": .identifier,
            "Int": .keyword,
        ])
        #expect(styles(of: "  /* 注释", lines[1]) == ["/* 注释": .comment])

        let third = styles(of: "  继续 */ let s = \"a\\\"b\" + 42", lines[2])
        #expect(third["  继续 */"] == .comment)
        #expect(third["let"] == .keyword)
        #expect(third["="] == .delimiter)
        #expect(third["\"a\\\"b\""] == .string)
        #expect(third["42"] == .number)
        #expect(styles(of: "#if DEBUG", lines[3]) == ["#if": .keyword, "DEBUG": .keyword])
        #expect(lines[4] == [SyntaxSpan(length: 1, style: nil)])
    }

    /// 标签、属性、样式表、Markdown 与 JSON 的结构各自着色，代码块跨行延续。
    @Test("标记语言、样式表、Markdown 与 JSON")
    func documentTokens() async throws {
        let tag = "<view id=\"main\"/><!-- c -->"
        let xml = await SyntaxHighlighter.highlight(tag, as: "xml")
        try #require(xml.count == 1)

        #expect(styles(of: tag, xml[0]) == [
            "<view ": .xmlTag,
            "id": .attributeName,
            "=": .xmlTag,
            "\"main\"": .string,
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

        let object = "{\"a\": [1, true, null]}"
        let json = await SyntaxHighlighter.highlight(object, as: "json")
        try #require(json.count == 1)

        let jsonStyles = styles(of: object, json[0])
        #expect(jsonStyles["\"a\""] == .attributeName)
        #expect(jsonStyles["{"] == .delimiter)
        #expect(jsonStyles["1"] == .number)
        #expect(jsonStyles["true"] == .keyword)
    }

    /// 中文与表情占的 UTF-16 码元数不同于字符数，片段长度按码元计，后面的记号才不会错位。
    @Test("多字节字符的 UTF-16 偏移")
    func utf16Offsets() async throws {
        let line = "let 名 = \"中文😀\"; let x = 1 // 注释 😀"
        let lines = await SyntaxHighlighter.highlight(line, as: "swift")
        try #require(lines.count == 1)

        let result = styles(of: line, lines[0])
        #expect(result["\"中文😀\""] == .string)
        #expect(result["1"] == .number)
        #expect(result["// 注释 😀"] == .comment)
        #expect(lines[0].reduce(0) { $0 + $1.length } == line.utf16.count)
    }

    /// highlight.js 把 `&`、`<`、`>` 与引号写成实体，每个实体还原成原文的一个码元。
    @Test("HTML 实体还原成原文")
    func entities() async throws {
        let line = "if (a < b && c > \"d\") { e = 'f' }"
        let lines = await SyntaxHighlighter.highlight(line, as: "javascript")
        try #require(lines.count == 1)

        let result = styles(of: line, lines[0])
        #expect(result["\"d\""] == .string)
        #expect(result["'f'"] == .string)
        #expect(lines[0].reduce(0) { $0 + $1.length } == line.utf16.count)
    }

    /// 任何输入下片段长度之和都等于该行的 UTF-16 长度，表情、CRLF 与未闭合的字符串也不例外。
    @Test("片段覆盖整行", arguments: ["swift", "py", "json", "html", "css", "md", "sh", "toml", "m", "rb", "sql", "yml"])
    func spansCoverLines(_ pathExtension: String) async throws {
        let language = try #require(await SyntaxHighlighter.language(forPath: "file." + pathExtension, content: nil))
        let text = "a = \"未闭合 😀\r\n<b x='1'># ${HOME} `t` **s\n[x](y) /* 1.5e3 */ 0x1F @attr\n\n\t- key: [v] & &amp;"
        let lines = text.components(separatedBy: "\n")
        let spans = await SyntaxHighlighter.highlight(text, as: language)

        #expect(spans.count == lines.count)

        for (line, lineSpans) in zip(lines, spans) {
            #expect(lineSpans.reduce(0) { $0 + $1.length } == line.utf16.count)
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

    /// 删除行取旧版的片段，新增与上下文行取新版；旧版的块注释不影响新版的着色。
    @Test("Diff 两侧全文的着色")
    func diffSyntax() async throws {
        let patch = """
            diff --git a/a.swift b/a.swift
            index 1111111..2222222 100644
            --- a/a.swift
            +++ b/a.swift
            @@ -1,2 +1,2 @@
            -/* old
            +let new = 1
             end */

            """
        let diff = try RepositoryDiff(patch: Data(patch.utf8))
        let syntax = try #require(await DiffSyntax.make(from: diff, oldPath: "a.swift", newPath: "a.swift"))
        let lines = try #require(diff.files.first?.hunks.first?.lines)

        #expect(await DiffSyntax.mayColor(diff, oldPath: "a.swift", newPath: "a.swift"))
        #expect(!(await DiffSyntax.mayColor(diff, oldPath: "notes", newPath: "notes")))

        #expect(syntax.spans(for: lines[0]) == [SyntaxSpan(length: 6, style: .comment)])
        #expect(syntax.spans(for: lines[1])?.first == SyntaxSpan(length: 3, style: .keyword))

        // 新版里 “end */” 不在注释里
        let context = try #require(syntax.spans(for: lines[2]))
        #expect(!context.contains { $0.style == .comment })
    }

    /// 制表符补齐到下一个 Tab 位置；打开不可见字符时标出制表符、空格与行内回车，关闭时省略回车。
    @Test("Tab 宽度与不可见字符")
    func lineRendering() {
        let theme = TextTheme.builtin[0]
        let plain = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false)
        let marked = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: true)

        #expect(String(TextLineRenderer.attributed("ab\tc\r", spans: nil, style: plain).characters) == "ab  c")
        #expect(String(TextLineRenderer.attributed("\tx y\r", spans: nil, style: marked).characters) == "→   x·y␍")

        // 片段比行短时剩余部分按正文显示，不丢字
        let short = [SyntaxSpan(length: 1, style: .keyword)]
        #expect(String(TextLineRenderer.attributed("let", spans: short, style: plain).characters) == "let")
    }
}

// MARK: - Helpers

extension SyntaxHighlighterTests {
    /// 把一行的片段还原成 “文字 → 类别”，只保留有类别的片段。
    private func styles(of line: String, _ spans: [SyntaxSpan]) -> [String: SyntaxStyle] {
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
