import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Detection

extension SyntaxHighlighterTests {
    /// 完整文件名、自带的扩展名表、highlight.js 的别名与首行解释器依次决定语言；扩展名表先于语言别名，大小写不会改变语言选择。
    @Test("按路径、扩展名与解释器识别语言")
    func languageFromPath() async {
        #expect(await SyntaxHighlighter.language(forPath: "Sources/App.swift", content: nil) == "swift")
        #expect(await SyntaxHighlighter.language(forPath: "目录 一/Makefile", content: nil) == "makefile")
        #expect(await SyntaxHighlighter.language(forPath: "Gemfile", content: nil) == "ruby")
        #expect(await SyntaxHighlighter.language(forPath: "Info.PLIST", content: nil) == "xml")
        #expect(await SyntaxHighlighter.language(forPath: "config.yml", content: nil) == "yaml")

        // highlight.js 把这些扩展名当作别的语言的别名，仓库里的文件仍按扩展名表着色
        let overrides = [
            ("m", "objectivec"), ("s", "x86asm"), ("pbxproj", "json"), ("php", "php-template"),
            ("strings", "objectivec"), ("svelte", "javascript"),
        ]

        for (pathExtension, language) in overrides {
            let lower = await SyntaxHighlighter.language(forPath: "文件." + pathExtension, content: nil)
            let upper = await SyntaxHighlighter.language(forPath: "文件." + pathExtension.uppercased(), content: nil)
            #expect(lower == language && upper == language)
        }

        // 没有扩展名时看首行解释器
        let script = "#!/usr/bin/env python3\nprint(1)\n"
        #expect(await SyntaxHighlighter.language(forPath: "tool", content: script) == "python")
        #expect(await SyntaxHighlighter.language(forPath: "run", content: "#!/bin/bash -e\n") == "bash")
    }

    /// 扩展名不认识时由 highlight.js 按字符数上限内的内容判断，否则按纯文本显示；头文件在全文中查找区分大小写的 Objective-C 标记，没有标记时用 C++。
    @Test("按内容识别、纯文本回退与头文件")
    func languageFromContent() async {
        let plist = "<?xml version=\"1.0\"?><plist><dict><key>Name</key><string>Spooky</string></dict></plist><!--"
        #expect(await SyntaxHighlighter.language(forPath: "Contents", content: plist + "-->") == "xml")

        // 上限按字符数计，多字节文字不会提前用尽配额；超过上限时首行是 #! 也不判断
        let padding = String(repeating: "字", count: SyntaxHighlighter.unknownFileLimit - plist.count - 3)
        let limit = plist + padding + "-->"
        #expect(limit.count == SyntaxHighlighter.unknownFileLimit && limit.utf8.count > limit.count)
        #expect(await SyntaxHighlighter.language(forPath: "Contents", content: limit) == "xml")
        #expect(await SyntaxHighlighter.language(forPath: "Contents", content: limit + "字") == nil)
        #expect(await SyntaxHighlighter.language(forPath: "data", content: "#!/bin/sh\n" + padding + padding) == nil)

        // 没有内容、扩展名未知或对应纯文本、语言未知时按纯文本显示
        #expect(await SyntaxHighlighter.language(forPath: "data", content: nil) == nil)
        #expect(await SyntaxHighlighter.language(forPath: "notes.unknown", content: nil) == nil)
        #expect(await SyntaxHighlighter.language(forPath: "notes.txt", content: plist) == nil)
        #expect(await SyntaxHighlighter.highlight(plist, as: "unknown-language").isEmpty)

        // 头文件：注释、字符串与超出自动识别上限的文字里的标记都算
        for marker in ["#import", "@class", "@\""] {
            let commented = await SyntaxHighlighter.language(forPath: "Bridge.h", content: "// " + marker)
            let quoted = await SyntaxHighlighter.language(forPath: "Bridge.H", content: "\"" + marker + "\"")
            #expect(commented == "objectivec" && quoted == "objectivec")

            let large = String(repeating: "x", count: 30_000) + marker
            #expect(await SyntaxHighlighter.language(forPath: "Bridge.h", content: large) == "objectivec")
        }

        #expect(await SyntaxHighlighter.language(forPath: "Vector.h", content: nil) == "cpp")
        #expect(await SyntaxHighlighter.language(forPath: "Vector.H", content: "#IMPORT <vector>") == "cpp")
    }

    /// 删除行取旧版的片段，新增与上下文行取新版；两侧分别识别语言，未知路径读取全文参与判断，二进制与纯文本不着色。
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
        #expect(!(await DiffSyntax.mayColor(diff, oldPath: "notes.txt", newPath: "notes.txt")))
        #expect(syntax.spans(for: lines[0]) == [SyntaxSpan(length: 6, style: .comment)])
        #expect(syntax.spans(for: lines[1])?.first == SyntaxSpan(length: 3, style: .keyword))

        // 新版里 “end */” 不在注释里
        let context = try #require(syntax.spans(for: lines[2]))
        #expect(!context.contains { $0.style == .comment })

        try await expectUnknownPath()

        // 删除 Objective-C 标记后，新侧单独按 C++ 识别，不沿用旧侧语言
        let header = "diff --git a/a.h b/a.h\n--- a/a.h\n+++ b/a.h\n@@ -1,2 +1 @@\n-@class X;\n namespace a {}\n"
        let headerDiff = try RepositoryDiff(patch: Data(header.utf8))
        let headerSyntax = try #require(await DiffSyntax.make(from: headerDiff, oldPath: "a.h", newPath: "a.h"))
        #expect(!headerSyntax.old[1].contains { $0.style == .keyword })
        #expect(headerSyntax.new[0].first == SyntaxSpan(length: 9, style: .keyword))

        let binary = try RepositoryDiff(patch: Data("diff --git a/a b/a\nBinary files a/a and b/a differ\n".utf8))
        #expect(!(await DiffSyntax.mayColor(binary, oldPath: "a", newPath: "a")))
    }

    /// 未知路径的 Diff 按全文识别语言；一侧是纯文本扩展名、另一侧可着色时仍着色。
    private func expectUnknownPath() async throws {
        let content = "FROM node:22\nWORKDIR /app\nCOPY . .\nRUN npm install\nCMD [\"node\", \"index.js\"]"

        let patch = "diff --git a/build b/build\nnew file mode 100644\n--- /dev/null\n+++ b/build\n@@ -0,0 +1,5 @@\n"
            + content.components(separatedBy: "\n").map { "+" + $0 + "\n" }.joined()

        let diff = try RepositoryDiff(patch: Data(patch.utf8))
        let syntax = try #require(await DiffSyntax.make(from: diff, oldPath: "build", newPath: "build"))

        #expect(await DiffSyntax.mayColor(diff, oldPath: "build", newPath: "build"))
        #expect(syntax.new.first?.first == SyntaxSpan(length: 4, style: .keyword))
        #expect(!(await DiffSyntax.mayColor(diff, oldPath: "build.txt", newPath: "build.txt")))
        #expect(await DiffSyntax.mayColor(diff, oldPath: "build.txt", newPath: "build.h"))
    }
}
