import Foundation

// MARK: - GitLab

extension HostingClient {
    /// 一页 Merge Request；来自 Fork 的源项目路径另外读取，同一页里只读一次。
    ///
    /// - Parameter state: `opened` 或 `all`。
    func gitlabMergeRequests(
        in project: String,
        page: Int,
        state: String
    ) async throws -> (items: [PullRequest], nextPage: Int?) {
        let response: HostingResponse<[GitLabMergeRequest]> = try await send(
            "GET",
            Self.gitlabProject(project) + "/merge_requests",
            query: [
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "per_page", value: "50"),
                URLQueryItem(name: "page", value: String(page)),
            ]
        )

        var paths: [Int: String?] = [:]

        for request in response.value
            where request.sourceProjectID != request.targetProjectID && paths[request.sourceProjectID] == nil
        {
            paths[request.sourceProjectID] = try await gitlabProjectPath(request.sourceProjectID)
        }

        let items = response.value.map { request in
            request.request(
                on: instance,
                project: project,
                sourceProject: request.sourceProjectID == request.targetProjectID
                    ? project
                    : paths[request.sourceProjectID] ?? nil
            )
        }

        return (items, response.nextPage)
    }

    /// 一个 Merge Request 的详情，以及当前账号能否合并。
    func gitlabMergeRequest(_ id: PullRequestID) async throws -> (request: PullRequest, payload: GitLabMergeRequest) {
        let response: HostingResponse<GitLabMergeRequest> = try await send(
            "GET",
            Self.gitlabProject(id.project) + "/merge_requests/\(id.number)"
        )

        let payload = response.value
        let source = payload.sourceProjectID == payload.targetProjectID
            ? id.project
            : try await gitlabProjectPath(payload.sourceProjectID)

        return (payload.request(on: instance, project: id.project, sourceProject: source), payload)
    }

    /// Merge Request 的评论与系统记录，逐页读完。
    func gitlabNotes(on id: PullRequestID) async throws -> [PullRequestComment] {
        var notes: [PullRequestComment] = []
        var page: Int? = 1

        while let current = page {
            let response: HostingResponse<[GitLabNote]> = try await send(
                "GET",
                Self.gitlabProject(id.project) + "/merge_requests/\(id.number)/notes",
                query: [
                    URLQueryItem(name: "sort", value: "asc"),
                    URLQueryItem(name: "order_by", value: "created_at"),
                    URLQueryItem(name: "per_page", value: "100"),
                    URLQueryItem(name: "page", value: String(current)),
                ]
            )

            notes += response.value.map {
                PullRequestComment(
                    id: $0.id,
                    author: $0.author?.username ?? "",
                    body: $0.body,
                    createdAt: $0.createdAt,
                    isSystem: $0.system ?? false
                )
            }
            page = response.nextPage
        }

        return notes
    }

    /// 新建 Merge Request：建在源项目里，来自 Fork 时带上目标项目的编号。
    func createGitLabMergeRequest(_ draft: PullRequestDraft) async throws -> PullRequest {
        var fields: [String: GitLabValue] = [
            "source_branch": .text(draft.sourceBranch),
            "target_branch": .text(draft.targetBranch),
            "title": .text(draft.title),
            "description": .text(draft.body),
        ]

        if draft.sourceProject != draft.targetProject {
            let target: HostingResponse<GitLabProject> = try await send("GET", Self.gitlabProject(draft.targetProject))
            fields["target_project_id"] = .number(target.value.id)
        }

        let response: HostingResponse<GitLabMergeRequest> = try await send(
            "POST",
            Self.gitlabProject(draft.sourceProject) + "/merge_requests",
            body: try JSONEncoder().encode(fields)
        )

        return response.value.request(on: instance, project: draft.targetProject, sourceProject: draft.sourceProject)
    }

    /// 项目的合并策略、压缩设置与删除源分支的默认值，加上当前账号能否合并与 GitLab 给出的合并状态。
    func gitlabMergeOptions(for request: PullRequest) async throws -> PullRequestMergeOptions {
        async let projectResponse: HostingResponse<GitLabProject> = send("GET", Self.gitlabProject(request.id.project))
        async let detail = gitlabMergeRequest(request.id)

        let project = try await projectResponse.value
        let payload = try await detail.payload

        // squash_option：never 不能压缩，always 必须压缩，default_on / default_off 可选
        let squash = project.squashOption ?? "default_off"

        return PullRequestMergeOptions(
            methods: [squash == "always" ? .squash : .merge],
            allowsSquashOption: squash != "never",
            squashesByDefault: squash == "always" || squash == "default_on" || (payload.squash ?? false),
            requiresSquash: squash == "always",
            deletesSourceBranchByDefault: payload.forceRemoveSourceBranch ?? project.removeSourceBranchAfterMerge ?? false,
            canDeleteSourceBranch: !request.isFromFork,
            projectMergeMethod: project.mergeMethod,
            block: Self.gitlabBlock(payload, request: request)
        )
    }

    /// 合并 Merge Request。
    func mergeGitLabMergeRequest(
        _ request: PullRequest,
        squash: Bool,
        deletesSourceBranch: Bool
    ) async throws -> PullRequestMergeResult {
        var fields: [String: GitLabValue] = [
            "squash": .flag(squash),
            "should_remove_source_branch": .flag(deletesSourceBranch),
        ]

        if !request.source.sha.isEmpty {
            fields["sha"] = .text(request.source.sha)
        }

        let response: HostingResponse<GitLabMergeRequest> = try await send(
            "PUT",
            Self.gitlabProject(request.id.project) + "/merge_requests/\(request.id.number)/merge",
            body: try JSONEncoder().encode(fields)
        )

        let merged = response.value
        return PullRequestMergeResult(sha: merged.mergeCommitSha ?? merged.squashCommitSha ?? merged.sha, message: merged.state)
    }

    /// 项目编号对应的路径；项目已删除或看不到时为 nil。
    private func gitlabProjectPath(_ id: Int) async throws -> String? {
        do {
            let response: HostingResponse<GitLabProject> = try await send("GET", "projects/\(id)")
            return response.value.pathWithNamespace
        } catch HostingError.notFound {
            return nil
        }
    }
}

// MARK: - GitLab Merge Block

extension HostingClient {
    /// GitLab 给出的不能合并的原因。
    private static func gitlabBlock(_ payload: GitLabMergeRequest, request: PullRequest) -> PullRequestMergeBlock? {
        guard request.state == .open else {
            return .notOpen
        }

        guard payload.user?.canMerge ?? false else {
            return .permission
        }

        switch payload.detailedMergeStatus {
        case "mergeable", nil: return nil
        case "conflict": return .conflicts
        case "draft_status": return .draft
        case "not_open": return .notOpen
        case "checking", "unchecked", "preparing", "approvals_syncing": return .checking
        case let status?: return .policy(status)
        }
    }
}

// MARK: - GitLabMergeRequest

/// GitLab 的 Merge Request。
struct GitLabMergeRequest: Decodable, Sendable {
    /// 合并基准、源分支与目标分支的提交。
    struct DiffReferences: Decodable, Sendable {
        /// 合并基准。
        let baseSha: String?

        /// 源分支的提交。
        let headSha: String?

        /// 目标分支的提交。
        let startSha: String?
    }

    /// 当前账号对这个请求的权限。
    struct UserPermissions: Decodable, Sendable {
        /// 可以合并。
        let canMerge: Bool?
    }

    /// 字段名：解码器先把蛇形字段转成驼峰，`source_project_id` 转成 `sourceProjectId`。
    private enum CodingKeys: String, CodingKey {
        case iid, title, description, state, draft, workInProgress, author, createdAt, updatedAt
        case sourceBranch, targetBranch, sha, assignees, diffRefs, detailedMergeStatus, user
        case forceRemoveSourceBranch, squash, mergeCommitSha, squashCommitSha
        case sourceProjectID = "sourceProjectId"
        case targetProjectID = "targetProjectId"
        case webURL = "webUrl"
    }

    /// 项目内编号。
    let iid: Int

    /// 标题。
    let title: String

    /// 描述。
    let description: String?

    /// `opened`、`closed`、`merged` 或 `locked`。
    let state: String

    /// 草稿；16.0 起的字段。
    let draft: Bool?

    /// 草稿；旧版本的字段。
    let workInProgress: Bool?

    /// 作者。
    let author: GitLabUserReference?

    /// 创建时间。
    let createdAt: Date

    /// 更新时间。
    let updatedAt: Date

    /// 源分支。
    let sourceBranch: String

    /// 目标分支。
    let targetBranch: String

    /// 源项目编号。
    let sourceProjectID: Int

    /// 目标项目编号。
    let targetProjectID: Int

    /// 源分支的提交。
    let sha: String?

    /// 网页地址。
    let webURL: URL?

    /// 指派的用户。
    let assignees: [GitLabUserReference]?

    /// 提交引用；列表里没有。
    let diffRefs: DiffReferences?

    /// 合并状态，如 `mergeable`、`conflict`；列表里可能没有。
    let detailedMergeStatus: String?

    /// 当前账号的权限；只在详情里有。
    let user: UserPermissions?

    /// 请求设置了合并后删除源分支。
    let forceRemoveSourceBranch: Bool?

    /// 请求设置了合并时压缩。
    let squash: Bool?

    /// 合并提交。
    let mergeCommitSha: String?

    /// 压缩后的提交。
    let squashCommitSha: String?

    /// 换成通用的请求。
    ///
    /// - Parameters:
    ///   - instance: 所在的实例。
    ///   - project: 目标项目路径。
    ///   - sourceProject: 源项目路径；Fork 删除后为 nil。
    func request(on instance: HostingInstance, project: String, sourceProject: String?) -> PullRequest {
        let status: PullRequestState =
            switch state {
            case "merged": .merged
            case "opened": .open
            default: .closed
            }

        return PullRequest(
            id: PullRequestID(instance: instance, project: project, number: iid),
            title: title,
            body: description ?? "",
            state: status,
            isDraft: draft ?? workInProgress ?? false,
            author: author?.username ?? "",
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: PullRequestBranch(project: sourceProject, branch: sourceBranch, sha: diffRefs?.headSha ?? sha ?? ""),
            target: PullRequestBranch(project: project, branch: targetBranch, sha: diffRefs?.startSha ?? ""),
            assignees: assignees?.map(\.username) ?? [],
            webURL: webURL,
            mergeBase: diffRefs?.baseSha
        )
    }
}

// MARK: - GitLabUserReference

/// GitLab 里引用的用户。
struct GitLabUserReference: Decodable, Sendable {
    /// 用户名。
    let username: String
}

// MARK: - GitLabNote

/// GitLab 的评论或系统记录。
private struct GitLabNote: Decodable, Sendable {
    /// 编号。
    let id: Int

    /// 内容。
    let body: String

    /// 作者。
    let author: GitLabUserReference?

    /// 发表时间。
    let createdAt: Date

    /// 是系统记录。
    let system: Bool?
}

// MARK: - GitLabProject

/// GitLab 项目里与合并有关的设置。
private struct GitLabProject: Decodable, Sendable {
    /// 项目编号。
    let id: Int

    /// 完整路径。
    let pathWithNamespace: String?

    /// 合并策略：`merge`、`rebase_merge` 或 `ff`。
    let mergeMethod: String?

    /// 压缩设置：`never`、`always`、`default_on` 或 `default_off`。
    let squashOption: String?

    /// 合并后默认删除源分支。
    let removeSourceBranchAfterMerge: Bool?
}

// MARK: - GitLabValue

/// GitLab 请求体里的值：文字、数字或布尔。
private enum GitLabValue: Encodable {
    /// 文字。
    case text(String)

    /// 数字。
    case number(Int)

    /// 布尔。
    case flag(Bool)

    /// 按种类编码成 JSON 值。
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .text(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .flag(let value): try container.encode(value)
        }
    }
}
