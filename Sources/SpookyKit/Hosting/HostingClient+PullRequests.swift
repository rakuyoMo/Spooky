import Foundation

// MARK: - Pull Requests

extension HostingClient {
    /// 一页打开着的请求：GitHub 的 Pull Request 或 GitLab 的 Merge Request，按创建时间从新到旧。
    ///
    /// - Parameters:
    ///   - project: 目标项目的路径。
    ///   - page: 页码，从 1 开始。
    /// - Returns: 这一页的请求与下一页的页码。
    public func pullRequests(in project: String, page: Int = 1) async throws -> (items: [PullRequest], nextPage: Int?) {
        switch instance.service {
        case .github: try await githubPullRequests(in: project, page: page)
        case .gitlab: try await gitlabMergeRequests(in: project, page: page)
        }
    }

    /// 读取一个请求的详情。
    public func pullRequest(_ id: PullRequestID) async throws -> PullRequest {
        switch instance.service {
        case .github: try await githubPullRequest(id)
        case .gitlab: try await gitlabMergeRequest(id).request
        }
    }

    /// 请求下的全部评论，按时间从早到晚。
    public func comments(on id: PullRequestID) async throws -> [PullRequestComment] {
        switch instance.service {
        case .github: try await githubComments(on: id)
        case .gitlab: try await gitlabNotes(on: id)
        }
    }

    /// 发表一条评论。
    ///
    /// - Parameters:
    ///   - body: 评论内容，Markdown。
    ///   - id: 请求。
    public func addComment(_ body: String, to id: PullRequestID) async throws {
        let payload = try JSONEncoder().encode(["body": body])

        switch instance.service {
        case .github:
            try await perform("POST", Self.githubRepository(id.project) + "/issues/\(id.number)/comments", body: payload)

        case .gitlab:
            try await perform("POST", Self.gitlabProject(id.project) + "/merge_requests/\(id.number)/notes", body: payload)
        }
    }

    /// 新建请求：GitHub 建在目标仓库里，GitLab 建在源项目里并指向目标项目。
    public func createPullRequest(_ draft: PullRequestDraft) async throws -> PullRequest {
        switch instance.service {
        case .github: try await createGitHubPullRequest(draft)
        case .gitlab: try await createGitLabMergeRequest(draft)
        }
    }

    /// 修改标题、描述与目标分支。
    public func updatePullRequest(_ id: PullRequestID, title: String, body: String, targetBranch: String) async throws {
        switch instance.service {
        case .github:
            let payload = try JSONEncoder().encode(["title": title, "body": body, "base": targetBranch])
            try await perform("PATCH", Self.githubRepository(id.project) + "/pulls/\(id.number)", body: payload)

        case .gitlab:
            let payload = try JSONEncoder().encode(["title": title, "description": body, "target_branch": targetBranch])
            try await perform("PUT", Self.gitlabProject(id.project) + "/merge_requests/\(id.number)", body: payload)
        }
    }

    /// 关闭请求，不合并。
    public func closePullRequest(_ id: PullRequestID) async throws {
        switch instance.service {
        case .github:
            let payload = try JSONEncoder().encode(["state": "closed"])
            try await perform("PATCH", Self.githubRepository(id.project) + "/pulls/\(id.number)", body: payload)

        case .gitlab:
            let payload = try JSONEncoder().encode(["state_event": "close"])
            try await perform("PUT", Self.gitlabProject(id.project) + "/merge_requests/\(id.number)", body: payload)
        }
    }

    /// 合并选项：GitHub 按仓库允许的合并方式与当前账号的写权限，GitLab 按项目的合并策略、压缩设置与当前账号能否合并。
    public func mergeOptions(for request: PullRequest) async throws -> PullRequestMergeOptions {
        switch instance.service {
        case .github: try await githubMergeOptions(for: request)
        case .gitlab: try await gitlabMergeOptions(for: request)
        }
    }

    /// 在托管服务上合并请求；源分支变了时服务端拒绝，免得合并进没有看过的提交。
    ///
    /// - Parameters:
    ///   - request: 要合并的请求，用它的源分支提交核对。
    ///   - method: 合并方式；GitLab 用 `squash` 表示合并时压缩。
    ///   - deletesSourceBranch: 合并后删除源分支。
    public func merge(
        _ request: PullRequest,
        method: PullRequestMergeMethod,
        deletesSourceBranch: Bool
    ) async throws -> PullRequestMergeResult {
        switch instance.service {
        case .github: try await mergeGitHubPullRequest(request, method: method, deletesSourceBranch: deletesSourceBranch)
        case .gitlab: try await mergeGitLabMergeRequest(
                request,
                squash: method == .squash,
                deletesSourceBranch: deletesSourceBranch
            )
        }
    }
}

// MARK: - Paths

extension HostingClient {
    /// GitHub 仓库的 API 路径：`repos/<owner>/<repo>`，每段单独转义。
    static func githubRepository(_ project: String) -> String {
        "repos/" + project.split(separator: "/").map { encodedSegment(String($0)) }.joined(separator: "/")
    }

    /// GitLab 项目的 API 路径：`projects/<转义后的完整路径>`，“/” 写成 `%2F`。
    static func gitlabProject(_ project: String) -> String {
        "projects/" + encodedSegment(project)
    }
}
