import Foundation

// MARK: - HostingIssue

/// 托管服务上一个打开着的 Issue，提交信息里的 `#` 补全列出它们。
public struct HostingIssue: Sendable, Hashable, Identifiable {
    /// 项目内的编号。
    public let number: Int

    /// 标题。
    public let title: String

    /// 以编号区分。
    public var id: Int { number }

    /// 创建 Issue；解析与测试使用。
    public init(number: Int, title: String) {
        self.number = number
        self.title = title
    }
}

// MARK: - Issues

extension HostingClient {
    /// 最近更新的一百个打开着的 Issue；GitHub 的 Issue 列表里混有 Pull Request，去掉它们。
    ///
    /// - Parameter project: 项目路径。
    public func openIssues(in project: String) async throws -> [HostingIssue] {
        switch instance.service {
        case .github:
            let response: HostingResponse<[GitHubIssue]> = try await send(
                "GET",
                Self.githubRepository(project) + "/issues",
                query: [
                    URLQueryItem(name: "state", value: "open"),
                    URLQueryItem(name: "sort", value: "updated"),
                    URLQueryItem(name: "per_page", value: "100"),
                ]
            )

            return response.value
                .filter { $0.pullRequest == nil }
                .map { HostingIssue(number: $0.number, title: $0.title) }

        case .gitlab:
            let response: HostingResponse<[GitLabIssue]> = try await send(
                "GET",
                Self.gitlabProject(project) + "/issues",
                query: [
                    URLQueryItem(name: "state", value: "opened"),
                    URLQueryItem(name: "order_by", value: "updated_at"),
                    URLQueryItem(name: "per_page", value: "100"),
                ]
            )

            return response.value.map { HostingIssue(number: $0.iid, title: $0.title) }
        }
    }
}

// MARK: - GitHubIssue

/// GitHub 的 Issue；Pull Request 也在这个列表里，带着 `pull_request` 字段。
private struct GitHubIssue: Decodable, Sendable {
    /// Pull Request 才有的字段，只用来判断有没有。
    struct PullRequestLink: Decodable, Sendable { }

    /// 编号。
    let number: Int

    /// 标题。
    let title: String

    /// 是 Pull Request 时不为 nil。
    let pullRequest: PullRequestLink?
}

// MARK: - GitLabIssue

/// GitLab 的 Issue。
private struct GitLabIssue: Decodable, Sendable {
    /// 项目内编号。
    let iid: Int

    /// 标题。
    let title: String
}
