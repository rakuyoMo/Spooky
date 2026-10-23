import Foundation
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - SyntaxHighlighterTests

/// 语法着色必须识别出常见语言、识别失败时退回纯文本，且每行的片段与原文逐码元对齐，否则颜色会错位。
struct SyntaxHighlighterTests {
    /// 文件名、扩展名与首行解释器依次决定语言；未知类型的大文件不按内容猜测。
    @Test("识别语言与纯文本回退")
    func languageDetection() {
        #expect(SyntaxHighlighter.language(forPath: "Sources/App.swift", content: nil)?.name == "swift")
        #expect(SyntaxHighlighter.language(forPath: "目录 一/Makefile", content: nil)?.name == "makefile")
        #expect(SyntaxHighlighter.language(forPath: "Info.PLIST", content: nil)?.name == "xml")
        let script = "#!/usr/bin/env python3\nprint(1)\n"
        #expect(SyntaxHighlighter.language(forPath: "tool", content: script)?.name == "python")
        #expect(SyntaxHighlighter.language(forPath: "run", content: "#!/bin/bash -e\n")?.name == "shell")

        // 识别不了的扩展名、没有解释器行和超出大小上限的内容都按纯文本显示
        #expect(SyntaxHighlighter.language(forPath: "notes.unknown", content: "plain text") == nil)
        #expect(SyntaxHighlighter.language(forPath: "data", content: nil) == nil)

        let large = "#!/bin/sh\n" + String(repeating: "x", count: SyntaxHighlighter.unknownFileLimit)
        #expect(SyntaxHighlighter.language(forPath: "data", content: large) == nil)
    }

    /// 关键字、函数、类型、字符串、数字、注解与跨行块注释各自归类，块注释的状态延续到下一行。
    @Test("程序语言的记号与跨行注释")
    func codeTokens() throws {
        let swift = try #require(SyntaxHighlighter.language(forPath: "a.swift", content: nil))
        let text = "@MainActor func run(_ value: Int) {\n  /* 注释\n  继续 */ let s = \"a\\\"b\" + 42\n#if DEBUG\n}"
        let lines = SyntaxHighlighter.highlight(text, as: swift)

        #expect(lines.count == 5)
        #expect(styles(of: "@MainActor func run(_ value: Int) {", lines[0]) == [
            "@MainActor": .preprocessor, "func": .keyword, "run": .function, "Int": .identifier,
        ])
        #expect(styles(of: "  /* 注释", lines[1])["/* 注释"] == .comment)

        let third = styles(of: "  继续 */ let s = \"a\\\"b\" + 42", lines[2])
        #expect(third["  继续 */"] == .comment)
        #expect(third["let"] == .keyword)
        #expect(third["\"a\\\"b\""] == .string)
        #expect(third["42"] == .number)
        #expect(styles(of: "#if DEBUG", lines[3])["#if DEBUG"] == .preprocessor)
    }

    /// 标签、属性、属性值、样式表与 Markdown 的结构各自着色。
    @Test("标记语言、样式表与 Markdown")
    func documentTokens() throws {
        let xml = try #require(SyntaxHighlighter.language(forPath: "a.xib", content: nil))
        let tag = "<view id=\"main\"/><!-- c -->"
        #expect(styles(of: tag, SyntaxHighlighter.highlight(tag, as: xml)[0]) == [
            "<view": .xmlTag, "id": .attributeName, "\"main\"": .attributeValue, "/>": .xmlTag, "<!-- c -->": .comment,
        ])

        let css = try #require(SyntaxHighlighter.language(forPath: "a.css", content: nil))
        let rule = ".box { color: #fff; }"
        let ruleStyles = styles(of: rule, SyntaxHighlighter.highlight(rule, as: css)[0])
        #expect(ruleStyles[".box "] == .cssSelector)
        #expect(ruleStyles["color"] == .attributeName)
        #expect(ruleStyles["#fff"] == .number)

        let markdown = try #require(SyntaxHighlighter.language(forPath: "README.md", content: nil))
        let document = "# 标题\n**粗** 与 `code` [链接](https://example.com)\n```\nlet x\n```"
        let lines = SyntaxHighlighter.highlight(document, as: markdown)
        #expect(styles(of: "# 标题", lines[0])["# 标题"] == .heading)

        let inline = styles(of: "**粗** 与 `code` [链接](https://example.com)", lines[1])
        #expect(inline["**粗**"] == .stronglyEmphasized)
        #expect(inline["`code`"] == .codeBlock)
        #expect(inline["(https://example.com)"] == .url)
        #expect(styles(of: "let x", lines[3])["let x"] == .codeBlock)
    }

    /// 任何输入下片段长度之和都等于该行的 UTF-16 长度，表情、CRLF 与未闭合的字符串也不例外。
    @Test("片段覆盖整行", arguments: ["swift", "py", "json", "html", "css", "md", "sh", "toml"])
    func spansCoverLines(_ pathExtension: String) throws {
        let language = try #require(SyntaxHighlighter.language(forPath: "file." + pathExtension, content: nil))
        let text = "a = \"未闭合 😀\r\n<b x='1'># ${HOME} `t` **s\n[x](y) /* 1.5e3 */ 0x1F @attr\n\n\t- key: [v]"
        let lines = text.components(separatedBy: "\n")
        let spans = SyntaxHighlighter.highlight(text, as: language)

        #expect(spans.count == lines.count)

        for (line, lineSpans) in zip(lines, spans) {
            #expect(lineSpans.reduce(0) { $0 + $1.length } == line.utf16.count)
        }
    }

    /// 删除行取旧版的片段，新增与上下文行取新版；旧版的块注释不影响新版的着色。
    @Test("Diff 两侧全文的着色")
    func diffSyntax() throws {
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
        let syntax = try #require(DiffSyntax.make(from: diff, oldPath: "a.swift", newPath: "a.swift"))
        let lines = try #require(diff.files.first?.hunks.first?.lines)

        #expect(syntax.spans(for: lines[0]) == [SyntaxSpan(length: 6, style: .comment)])
        #expect(syntax.spans(for: lines[1])?.first == SyntaxSpan(length: 3, style: .keyword))

        // 新版里 “end */” 不在注释里
        let context = try #require(syntax.spans(for: lines[2]))
        #expect(!context.contains { $0.style == .comment })
    }

    /// 制表符补齐到下一个 Tab 位置；打开不可见字符时标出制表符、空格与行内回车，关闭时省略回车。
    @Test("Tab 宽度与不可见字符")
    func lineRendering() {
        let theme = BuiltinTheme.current(dark: false)
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
