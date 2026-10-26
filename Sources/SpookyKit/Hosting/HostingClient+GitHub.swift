import Foundation

// MARK: - GitHub

extension HostingClient {
    /// 一页打开着的 Pull Request。
    func githubPullRequests(in project: String, page: Int) async throws -> (items: [PullRequest], nextPage: Int?) {
        let response: HostingResponse<[GitHubPullRequest]> = try await send(
            "GET",
            Self.githubRepository(project) + "/pulls",
            query: [
                URLQueryItem(name: "state", value: "open"),
                URLQueryItem(name: "per_page", value: "50"),
                URLQueryItem(name: "page", value: String(page)),
            ]
        )

        return (response.value.map { $0.request(on: instance, project: project) }, response.nextPage)
    }

    /// 一个 Pull Request 的详情。
    func githubPullRequest(_ id: PullRequestID) async throws -> PullRequest {
        let response: HostingResponse<GitHubPullRequest> = try await send(
            "GET",
            Self.githubRepository(id.project) + "/pulls/\(id.number)"
        )

        return response.value.request(on: instance, project: id.project)
    }

    /// Pull Request 的对话评论，逐页读完。
    func githubComments(on id: PullRequestID) async throws -> [PullRequestComment] {
        var comments: [PullRequestComment] = []
        var page: Int? = 1

        while let current = page {
            let response: HostingResponse<[GitHubComment]> = try await send(
                "GET",
                Self.githubRepository(id.project) + "/issues/\(id.number)/comments",
                query: [URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "page", value: String(current))]
            )

            comments += response.value.map {
                PullRequestComment(id: $0.id, author: $0.user?.login ?? "", body: $0.body ?? "", createdAt: $0.createdAt)
            }
            page = response.nextPage
        }

        return comments
    }

    /// 新建 Pull Request：源分支在 Fork 里时写成 `owner:branch`。
    func createGitHubPullRequest(_ draft: PullRequestDraft) async throws -> PullRequest {
        let owner = draft.sourceProject.split(separator: "/").first.map(String.init) ?? ""
        let head = draft.sourceProject == draft.targetProject ? draft.sourceBranch : owner + ":" + draft.sourceBranch
        let payload = try JSONEncoder().encode([
            "title": draft.title,
            "body": draft.body,
            "head": head,
            "base": draft.targetBranch,
        ])

        let response: HostingResponse<GitHubPullRequest> = try await send(
            "POST",
            Self.githubRepository(draft.targetProject) + "/pulls",
            body: payload
        )

        return response.value.request(on: instance, project: draft.targetProject)
    }

    /// 仓库允许的合并方式、合并后删除分支的设置与当前账号的写权限，加上 Pull Request 能否合并。
    func githubMergeOptions(for request: PullRequest) async throws -> PullRequestMergeOptions {
        async let repositoryResponse: HostingResponse<GitHubRepository> = send(
            "GET",
            Self.githubRepository(request.id.project)
        )
        async let detailResponse: HostingResponse<GitHubPullRequest> = send(
            "GET",
            Self.githubRepository(request.id.project) + "/pulls/\(request.id.number)"
        )

        let repository = try await repositoryResponse.value
        let detail = try await detailResponse.value

        // 仓库没有给出设置时按 GitHub 的默认值，三种方式都允许
        let allowed: [(PullRequestMergeMethod, Bool?)] = [
            (.merge, repository.allowMergeCommit),
            (.squash, repository.allowSquashMerge),
            (.rebase, repository.allowRebaseMerge),
        ]

        return PullRequestMergeOptions(
            methods: allowed.filter { $0.1 ?? true }.map(\.0),
            deletesSourceBranchByDefault: repository.deleteBranchOnMerge ?? false,
            canDeleteSourceBranch: !request.isFromFork,
            block: Self.githubBlock(detail, request: request, canPush: repository.permissions?.push ?? false)
        )
    }

    /// 合并 Pull Request，按需再删除源分支。
    func mergeGitHubPullRequest(
        _ request: PullRequest,
        method: PullRequestMergeMethod,
        deletesSourceBranch: Bool
    ) async throws -> PullRequestMergeResult {
        var fields = ["merge_method": method.rawValue]

        if !request.source.sha.isEmpty {
            fields["sha"] = request.source.sha
        }

        let response: HostingResponse<GitHubMergeResult> = try await send(
            "PUT",
            Self.githubRepository(request.id.project) + "/pulls/\(request.id.number)/merge",
            body: try JSONEncoder().encode(fields)
        )

        if deletesSourceBranch, !request.isFromFork {
            let branch = request.source.branch
                .split(separator: "/", omittingEmptySubsequences: false)
                .map { Self.encodedSegment(String($0)) }
                .joined(separator: "/")

            try await perform("DELETE", Self.githubRepository(request.id.project) + "/git/refs/heads/" + branch)
        }

        return PullRequestMergeResult(sha: response.value.sha, message: response.value.message ?? "")
    }
}

// MARK: - GitHub Merge Block

extension HostingClient {
    /// GitHub 给出的不能合并的原因。
    private static func githubBlock(
        _ detail: GitHubPullRequest,
        request: PullRequest,
        canPush: Bool
    ) -> PullRequestMergeBlock? {
        guard request.state == .open else {
            return .notOpen
        }

        guard canPush else {
            return .permission
        }

        if detail.draft ?? false {
            return .draft
        }

        // mergeable 为 null 时 GitHub 还在后台计算
        guard let mergeable = detail.mergeable else {
            return .checking
        }

        switch detail.mergeableState {
        case "dirty": return .conflicts
        case "draft": return .draft
        case "unknown": return .checking
        case "blocked", "behind": return .policy(detail.mergeableState ?? "")
        default: return mergeable ? nil : .policy(detail.mergeableState ?? "")
        }
    }
}

// MARK: - GitHubPullRequest

/// GitHub 的 Pull Request。
private struct GitHubPullRequest: Decodable, Sendable {
    /// 一侧的分支。
    struct Branch: Decodable, Sendable {
        /// 分支所在的仓库。
        struct Repository: Decodable, Sendable {
            /// `owner/repo`。
            let fullName: String
        }

        /// 分支名。
        let ref: String

        /// 分支的提交。
        let sha: String

        /// 所在的仓库；Fork 删除后为 null。
        let repo: Repository?
    }

    /// 字段名：解码器先把蛇形字段转成驼峰，`html_url` 转成 `htmlUrl`。
    private enum CodingKeys: String, CodingKey {
        case number, title, body, state, draft, user, createdAt, updatedAt, mergedAt, assignees, head, base
        case mergeable, mergeableState
        case htmlURL = "htmlUrl"
    }

    /// 编号。
    let number: Int

    /// 标题。
    let title: String

    /// 描述。
    let body: String?

    /// `open` 或 `closed`。
    let state: String

    /// 草稿。
    let draft: Bool?

    /// 作者。
    let user: GitHubUserReference?

    /// 创建时间。
    let createdAt: Date

    /// 更新时间。
    let updatedAt: Date

    /// 合并时间；没有合并时为 null。
    let mergedAt: Date?

    /// 网页地址。
    let htmlURL: URL?

    /// 指派的用户。
    let assignees: [GitHubUserReference]?

    /// 源分支。
    let head: Branch

    /// 目标分支。
    let base: Branch

    /// 能否合并；GitHub 还在计算时为 null，列表里没有。
    let mergeable: Bool?

    /// 合并状态，如 `clean`、`dirty`、`blocked`；列表里没有。
    let mergeableState: String?

    /// 换成通用的请求。
    func request(on instance: HostingInstance, project: String) -> PullRequest {
        PullRequest(
            id: PullRequestID(instance: instance, project: project, number: number),
            title: title,
            body: body ?? "",
            state: mergedAt != nil ? .merged : (state == "open" ? .open : .closed),
            isDraft: draft ?? false,
            author: user?.login ?? "",
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: PullRequestBranch(project: head.repo?.fullName, branch: head.ref, sha: head.sha),
            target: PullRequestBranch(project: base.repo?.fullName ?? project, branch: base.ref, sha: base.sha),
            assignees: assignees?.map(\.login) ?? [],
            webURL: htmlURL
        )
    }
}

// MARK: - GitHubUserReference

/// GitHub 里引用的用户。
private struct GitHubUserReference: Decodable, Sendable {
    /// 用户名。
    let login: String
}

// MARK: - GitHubComment

/// GitHub 的对话评论。
private struct GitHubComment: Decodable, Sendable {
    /// 评论编号。
    let id: Int

    /// 作者。
    let user: GitHubUserReference?

    /// 内容。
    let body: String?

    /// 发表时间。
    let createdAt: Date
}

// MARK: - GitHubRepository

/// GitHub 仓库里与合并有关的设置与当前账号的权限。
private struct GitHubRepository: Decodable, Sendable {
    /// 当前账号的权限。
    struct Permissions: Decodable, Sendable {
        /// 可以推送，也就可以合并。
        let push: Bool?
    }

    /// 允许生成合并提交。
    let allowMergeCommit: Bool?

    /// 允许压缩合并。
    let allowSquashMerge: Bool?

    /// 允许变基合并。
    let allowRebaseMerge: Bool?

    /// 合并后自动删除源分支。
    let deleteBranchOnMerge: Bool?

    /// 当前账号的权限。
    let permissions: Permissions?
}

// MARK: - GitHubMergeResult

/// GitHub 合并的结果。
private struct GitHubMergeResult: Decodable, Sendable {
    /// 合并后的提交。
    let sha: String?

    /// 服务端的说明。
    let message: String?
}
