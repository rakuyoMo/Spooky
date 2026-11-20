import Foundation
import Testing

@testable import Spooky

// MARK: - HelpArticleTests

/// 帮助按钮打开的官网文章与官网的手册对得上。
struct HelpArticleTests {
    /// 每个帮助按钮的地址都指向官网手册里的一页，页里写明了这个锚点：官网改了页面路径或锚点，帮助按钮就会打开不存在的位置。
    @Test("帮助按钮的地址指向手册里存在的页面与锚点")
    func articlesExistInManual() throws {
        let docs = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "website/src/content/docs")

        for article in HelpArticle.allCases {
            let url = try #require(article.url)
            let anchor = try #require(url.fragment(), "\(article) 的地址没有锚点")

            #expect(url.host() == HelpLinks.website?.host())

            // 英文页在根目录，路径去掉首尾的 “/” 就是手册里的文件名
            let page = url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            let file = try #require(
                ["md", "mdx"]
                    .map { docs.appending(path: page + "." + $0) }
                    .first { FileManager.default.fileExists(atPath: $0.path) },
                "\(article) 指向的 \(page) 不在手册里"
            )

            let source = try String(contentsOf: file, encoding: .utf8)

            #expect(source.contains("{#\(anchor)}"), "\(page) 里没有 \(article) 的锚点 \(anchor)")
        }
    }
}
