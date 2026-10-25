import Foundation

// MARK: - HelpLinks

/// Help 菜单与崩溃报告指向的网页：使用说明在项目网站，发行说明与问题反馈在 GitHub。
enum HelpLinks {
    /// 使用说明与帮助。
    static let website = URL(string: "https://spooky.rakuyo.dev/")

    /// 每个版本的发行说明。
    static let releases = URL(string: "https://github.com/rakuyoMo/Spooky/releases")

    /// 问题反馈。
    static let issues = URL(string: "https://github.com/rakuyoMo/Spooky/issues")

    /// 预填正文的上限：GitHub 与浏览器对地址长度有限制，编码后仍要留出余量。
    private static let maximumBodyLength = 6000

    /// 预填标题与正文的新问题页；地址超出浏览器能接受的长度时正文被截短。
    ///
    /// - Parameters:
    ///   - title: 问题标题。
    ///   - body: 问题正文，已脱敏的 Markdown。
    static func newIssue(title: String, body: String) -> URL? {
        var components = URLComponents(string: "https://github.com/rakuyoMo/Spooky/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: String(body.prefix(maximumBodyLength))),
        ]

        return components?.url
    }
}
