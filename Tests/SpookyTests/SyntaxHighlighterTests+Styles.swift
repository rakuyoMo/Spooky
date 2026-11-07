import Foundation
import Testing

@testable import Spooky

// MARK: - Styles

extension SyntaxHighlighterTests {
    /// 函数调用的分层类别覆盖名称色，类名仍保持标识符色。
    @Test("分层函数类别与普通标识符")
    func layeredStyles() async throws {
        let rust = "fn main() { run(); }"
        let rustSpans = try #require(await SyntaxHighlighter.highlight(rust, as: "rust").first)
        let rustStyles = styles(of: rust, rustSpans)
        #expect(rustStyles["main"] == .function)
        #expect(rustStyles["run"] == .function)

        let swift = "class A: B {}"
        let swiftSpans = try #require(await SyntaxHighlighter.highlight(swift, as: "swift").first)
        let swiftStyles = styles(of: swift, swiftSpans)
        #expect(swiftStyles["A"] == .identifier)
        #expect(swiftStyles["B"] == .identifier)
    }

    /// XML 及嵌入的 XML 属性值使用独立颜色，声明与其它语法里的字符串保留字符串色。
    @Test("属性值的语法与直接父类别", arguments: [
        ("xml", "<a title=\"Home\">link</a>", "\"Home\"", SyntaxStyle.attributeValue),
        ("javascript", "render(<div className=\"a\">{run()}</div>);", "\"a\"", .attributeValue),
        ("markdown", "link <a href=\"url\">text</a>", "\"url\"", .attributeValue),
        ("php-template", "<a title=\"Home\"><?php echo 1; ?></a>", "\"Home\"", .attributeValue),
        ("xml", "<?xml version=\"1.0\"?>", "\"1.0\"", .string),
        ("haml", "%a(title=\"Home\") link", "\"Home\"", .string),
        ("javascript", "const value = \"Home\";", "\"Home\"", .string),
    ])
    func attributeValueStyles(_ sample: (String, String, String, SyntaxStyle)) async throws {
        let spans = try #require(await SyntaxHighlighter.highlight(sample.1, as: sample.0).first)
        #expect(styles(of: sample.1, spans)[sample.2] == sample.3)
    }

    /// 没有颜色规则的正则与名称沿用正文；标点使用符号色。
    @Test("正文回退与符号色")
    func inheritedStyles() async throws {
        let javascript = "const re = /a+b/g;"
        let jsSpans = try #require(await SyntaxHighlighter.highlight(javascript, as: "javascript").first)
        #expect(styles(of: javascript, jsSpans)["/a+b/g"] == nil)

        let clojure = "(println \"x\")"
        let clojureSpans = try #require(await SyntaxHighlighter.highlight(clojure, as: "clojure").first)
        #expect(styles(of: clojure, clojureSpans)["println"] == nil)

        let json = "{\"a\": [1, true, null]}"
        let jsonSpans = try #require(await SyntaxHighlighter.highlight(json, as: "json").first)
        let jsonStyles = styles(of: json, jsonSpans)
        #expect(jsonStyles["{"] == .symbol)
        #expect(jsonStyles[","] == .symbol)
    }
}
