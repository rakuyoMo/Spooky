import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Detection

extension SyntaxHighlighterTests {
    /// 文件扩展名表先于语言别名，大小写不会改变语言选择。
    @Test("扩展名覆盖语言别名", arguments: [
        ("adb", "ada"), ("ads", "ada"), ("aj", "aspectj"), ("asm", "x86asm"), ("s", "x86asm"),
        ("bas", "basic"), ("cljc", "clojure"), ("cljs", "clojure"), ("csx", "csharp"), ("jl", "julia"),
        ("lhs", "haskell"), ("litcoffee", "coffeescript"), ("ma", "mathematica"), ("ml", "ocaml"),
        ("mli", "ocaml"), ("p", "prolog"), ("pro", "prolog"), ("pbxproj", "json"), ("php", "php-template"),
        ("rslib", "rust"), ("scpt", "applescript"), ("scptd", "applescript"), ("shtm", "xml"), ("shtml", "xml"),
        ("xht", "xml"), ("xhtm", "xml"), ("ss", "scheme"), ("strings", "objectivec"), ("svelte", "javascript"),
        ("vbe", "vbscript"), ("wsc", "vbscript"), ("wsf", "vbscript"), ("vhd", "vhdl"),
    ])
    func extensionOverrides(_ pathExtension: String, _ language: String) async {
        #expect(await SyntaxHighlighter.language(forPath: "文件." + pathExtension, content: nil) == language)
        #expect(await SyntaxHighlighter.language(forPath: "文件." + pathExtension.uppercased(), content: nil) == language)
    }

    /// 头文件在全文中查找区分大小写的 Objective-C 标记，注释和超出自动识别上限的文字同样参与。
    @Test("头文件的语言标记", arguments: ["#import", "@class", "@interface", "@protocol", "@import", "@\""])
    func headerMarkers(_ marker: String) async {
        #expect(await SyntaxHighlighter.language(forPath: "Bridge.h", content: "// " + marker) == "objectivec")
        #expect(await SyntaxHighlighter.language(forPath: "Bridge.H", content: "\"" + marker + "\"") == "objectivec")

        let large = String(repeating: "x", count: 30_000) + marker
        #expect(await SyntaxHighlighter.language(forPath: "Bridge.h", content: large) == "objectivec")
    }

    /// 未出现标记的头文件使用 C++，不把标记当作不区分大小写的关键字。
    @Test("头文件默认使用 C++")
    func cppHeaders() async {
        #expect(await SyntaxHighlighter.language(forPath: "Vector.h", content: nil) == "cpp")
        #expect(await SyntaxHighlighter.language(forPath: "Vector.H", content: "#IMPORT <vector>") == "cpp")
        #expect(await SyntaxHighlighter.language(forPath: "Vector.h", content: "namespace geo {}") == "cpp")
    }

    /// 自动识别按字符数限制，多字节文字不会提前用尽配额。
    @Test("自动识别的字符数边界")
    func detectionCharacterLimit() async {
        let prefix = "<?xml version=\"1.0\"?><plist><dict><key>Name</key><string>Spooky</string></dict></plist><!--"
        let suffix = "-->"
        let padding = String(repeating: "字", count: SyntaxHighlighter.unknownFileLimit - prefix.count - suffix.count)
        let content = prefix + padding + suffix

        #expect(content.count == 20_000)
        #expect(content.utf8.count > 20_000)
        #expect(await SyntaxHighlighter.language(forPath: "Contents", content: content) == "xml")
        #expect(await SyntaxHighlighter.language(forPath: "Contents", content: content + "字") == nil)
    }

    /// 自动识别使用扩展语言，Diff 的未知路径也读取全文参与判断。
    @Test("未知路径的 Diff 按全文识别语言")
    func unknownDiffLanguage() async throws {
        let content = "FROM node:22\nWORKDIR /app\nCOPY . .\nRUN npm install\nCMD [\"node\", \"index.js\"]"
        #expect(await SyntaxHighlighter.language(forPath: "build", content: content) == "dockerfile")

        let patch = "diff --git a/build b/build\nnew file mode 100644\n--- /dev/null\n+++ b/build\n@@ -0,0 +1,5 @@\n"
            + content.components(separatedBy: "\n").map { "+" + $0 + "\n" }.joined()
        let diff = try RepositoryDiff(patch: Data(patch.utf8))
        let syntax = try #require(await DiffSyntax.make(from: diff, oldPath: "build", newPath: "build"))

        #expect(await DiffSyntax.mayColor(diff, oldPath: "build", newPath: "build"))
        #expect(syntax.new.first?.first == SyntaxSpan(length: 4, style: .keyword))
        #expect(!(await DiffSyntax.mayColor(diff, oldPath: "build.txt", newPath: "build.txt")))
        #expect(await DiffSyntax.mayColor(diff, oldPath: "build.txt", newPath: "build.h"))

        let binary = try RepositoryDiff(patch: Data("diff --git a/a b/a\nBinary files a/a and b/a differ\n".utf8))
        #expect(!(await DiffSyntax.mayColor(binary, oldPath: "a", newPath: "a")))
    }

    /// 删除 Objective-C 标记后，新侧单独按 C++ 识别，不沿用旧侧语言。
    @Test("Diff 两侧分别识别头文件")
    func headerDiffLanguages() async throws {
        let patch = "diff --git a/a.h b/a.h\n--- a/a.h\n+++ b/a.h\n@@ -1,2 +1 @@\n-@class X;\n namespace a {}\n"
        let diff = try RepositoryDiff(patch: Data(patch.utf8))
        let syntax = try #require(await DiffSyntax.make(from: diff, oldPath: "a.h", newPath: "a.h"))

        #expect(await DiffSyntax.mayColor(diff, oldPath: "a.h", newPath: "a.h"))
        #expect(!syntax.old[1].contains { $0.style == .keyword })
        #expect(syntax.new[0].first == SyntaxSpan(length: 9, style: .keyword))
    }

    /// JSON 中非法的工程文件记号让整份文件回退，仍保留全部行与 UTF-16 长度。
    @Test("非法记号让整个文件显示纯文本")
    func illegalTokens() async throws {
        let text = "// !$*UTF8*$!\n{\n  archiveVersion = 1;\n  value = \"中文😀\";\n}"
        let language = try #require(await SyntaxHighlighter.language(forPath: "project.pbxproj", content: text))
        let spans = await SyntaxHighlighter.highlight(text, as: language)
        let lines = text.components(separatedBy: "\n")

        #expect(spans.count == lines.count)

        for (line, lineSpans) in zip(lines, spans) {
            #expect(lineSpans == [SyntaxSpan(length: line.utf16.count, style: nil)])
        }
    }
}
