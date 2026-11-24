import Foundation

// MARK: - Labels

extension HostingClient {
    /// 项目里能用的全部标签，逐页读完；GitLab 连上级群组的标签一起列出。
    ///
    /// - Parameter project: 项目路径。
    public func labels(in project: String) async throws -> [PullRequestLabel] {
        var labels: [PullRequestLabel] = []
        var page: Int? = 1

        while let current = page {
            let query = [URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "page", value: String(current))]

            switch instance.service {
            case .github:
                let response: HostingResponse<[GitHubLabel]> = try await send(
                    "GET",
                    Self.githubRepository(project) + "/labels",
                    query: query
                )

                labels += response.value.map {
                    PullRequestLabel(name: $0.name, color: $0.color, description: $0.description ?? "")
                }

                page = response.nextPage

            case .gitlab:
                let response: HostingResponse<[GitLabLabel]> = try await send(
                    "GET",
                    Self.gitlabProject(project) + "/labels",
                    query: query
                )

                labels += response.value.map {
                    PullRequestLabel(name: $0.name, color: $0.color, description: $0.description ?? "")
                }

                page = response.nextPage
            }
        }

        return labels
    }

    /// 在项目里新建一个标签。
    ///
    /// - Parameters:
    ///   - name: 标签的名称。
    ///   - color: 底色，6 位十六进制，不带 “#”。
    ///   - project: 项目路径。
    public func createLabel(_ name: String, color: String, in project: String) async throws {
        switch instance.service {
        case .github:
            let payload = try JSONEncoder().encode(["name": name, "color": color])
            try await perform("POST", Self.githubRepository(project) + "/labels", body: payload)

        case .gitlab:
            let payload = try JSONEncoder().encode(["name": name, "color": "#" + color])
            try await perform("POST", Self.gitlabProject(project) + "/labels", body: payload)
        }
    }

    /// 给请求加上项目里已有的一个标签；GitHub 经同号 Issue 的接口。
    ///
    /// - Parameters:
    ///   - name: 标签的名称。
    ///   - id: 请求。
    public func addLabel(_ name: String, to id: PullRequestID) async throws {
        switch instance.service {
        case .github:
            let payload = try JSONEncoder().encode(["labels": [name]])
            try await perform("POST", Self.githubRepository(id.project) + "/issues/\(id.number)/labels", body: payload)

        case .gitlab:
            let payload = try JSONEncoder().encode(["add_labels": name])
            try await perform("PUT", Self.gitlabProject(id.project) + "/merge_requests/\(id.number)", body: payload)
        }
    }

    /// 从请求上去掉一个标签；GitHub 经同号 Issue 的接口。
    ///
    /// - Parameters:
    ///   - name: 标签的名称。
    ///   - id: 请求。
    public func removeLabel(_ name: String, from id: PullRequestID) async throws {
        switch instance.service {
        case .github:
            try await perform(
                "DELETE",
                Self.githubRepository(id.project) + "/issues/\(id.number)/labels/" + Self.encodedSegment(name)
            )

        case .gitlab:
            let payload = try JSONEncoder().encode(["remove_labels": name])
            try await perform("PUT", Self.gitlabProject(id.project) + "/merge_requests/\(id.number)", body: payload)
        }
    }
}
