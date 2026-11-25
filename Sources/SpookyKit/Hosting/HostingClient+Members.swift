import Foundation

// MARK: - Members

extension HostingClient {
    /// 项目的全部成员，逐页读完，评论里的 `@` 补全列出他们。
    ///
    /// GitHub 取能被指派的用户，没有显示名；GitLab 取能访问项目的用户，去掉已停用的。
    ///
    /// - Parameter project: 项目路径。
    public func members(of project: String) async throws -> [HostingUser] {
        var members: [HostingUser] = []
        var page: Int? = 1

        while let current = page {
            let query = [URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "page", value: String(current))]

            switch instance.service {
            case .github:
                let response: HostingResponse<[GitHubUserReference]> = try await send(
                    "GET",
                    Self.githubRepository(project) + "/assignees",
                    query: query
                )

                members += response.value.map { GitHubUserReference.user($0) }
                page = response.nextPage

            case .gitlab:
                let response: HostingResponse<[GitLabMember]> = try await send(
                    "GET",
                    Self.gitlabProject(project) + "/users",
                    query: query
                )

                members += response.value
                    .filter { $0.state == "active" }
                    .map { HostingUser(username: $0.username, name: $0.name, avatarURL: $0.avatarURL) }

                page = response.nextPage
            }
        }

        return members
    }
}

// MARK: - GitLabMember

/// GitLab 项目成员列表里的一个用户。
private struct GitLabMember: Decodable, Sendable {
    /// 字段名：解码器先把蛇形字段转成驼峰，`avatar_url` 转成 `avatarUrl`。
    private enum CodingKeys: String, CodingKey {
        case username, name, state
        case avatarURL = "avatarUrl"
    }

    /// 用户名。
    let username: String

    /// 显示名。
    let name: String?

    /// 账号的状态，可用的是 `active`。
    let state: String

    /// 头像地址；没有头像时为 null。
    let avatarURL: URL?
}
