import Foundation

// MARK: - GitLab Merge

extension HostingClient {
    /// 项目的合并策略、压缩设置与删除源分支的默认值，加上现在不能合并的原因。
    func gitlabMergeOptions(for request: PullRequest) async throws -> PullRequestMergeOptions {
        async let projectResponse: HostingResponse<GitLabProject> = send("GET", Self.gitlabProject(request.id.project))
        async let detailResponse: HostingResponse<GitLabMergeDetail> = send(
            "GET",
            Self.gitlabProject(request.id.project) + "/merge_requests/\(request.id.number)"
        )

        let project = try await projectResponse.value
        let detail = try await detailResponse.value
        let payload = detail.request
        let block = try await gitlabBlock(detail, project: project, request: request)

        // squash_option：never 不能压缩，always 必须压缩，default_on / default_off 可选；
        // 请求上没有 squash 字段（CE 11.0 以前）时不能压缩
        let squash = payload.squash == nil ? "never" : project.squashOption ?? "default_off"

        return PullRequestMergeOptions(
            methods: [squash == "always" ? .squash : .merge],
            allowsSquashOption: squash != "never",
            squashesByDefault: squash == "always" || squash == "default_on" || (payload.squash ?? false),
            requiresSquash: squash == "always",
            deletesSourceBranchByDefault: payload.forceRemoveSourceBranch ?? project.removeSourceBranchAfterMerge ?? false,
            canDeleteSourceBranch: !request.isFromFork,
            projectMergeMethod: project.mergeMethod ?? "merge",
            block: block
        )
    }

    /// 合并 Merge Request；服务端没有合并时按原因抛出。
    func mergeGitLabMergeRequest(
        _ request: PullRequest,
        squash: Bool,
        deletesSourceBranch: Bool
    ) async throws -> PullRequestMergeResult {
        let path = Self.gitlabProject(request.id.project) + "/merge_requests/\(request.id.number)"

        if !squash {
            try await clearGitLabSquash(at: path)
        }

        var fields: [String: GitLabValue] = [
            "squash": .flag(squash),
            "should_remove_source_branch": .flag(deletesSourceBranch),
        ]

        if !request.source.sha.isEmpty {
            fields["sha"] = .text(request.source.sha)
        }

        let response: HostingResponse<GitLabMergeRequest>

        do {
            response = try await send("PUT", path + "/merge", body: try JSONEncoder().encode(fields))
        } catch let error as HostingError {
            throw await gitlabMergeFailure(error)
        }

        let merged = response.value

        // 服务端合并失败时合并接口仍回 200，请求还开着，原因在 merge_error（11.6 起）
        guard merged.state == "merged" else {
            throw HostingError.mergeFailed(merged.mergeError ?? "")
        }

        return PullRequestMergeResult(
            sha: merged.mergeCommitSha ?? merged.squashCommitSha ?? merged.sha,
            message: merged.state
        )
    }

    /// 不能合并的原因：先看请求状态与当前账号的权限，再看 GitLab 给出的合并状态；
    /// 没有 `detailed_merge_status`（15.6 以前）时用旧字段推出，最后看 EE 的审批。
    private func gitlabBlock(
        _ detail: GitLabMergeDetail,
        project: GitLabProject,
        request: PullRequest
    ) async throws -> PullRequestMergeBlock? {
        guard request.state == .open else {
            return .notOpen
        }

        // 没有 can_merge（11.9 以前）时不预先挡住，交给服务端判断
        guard detail.request.user?.canMerge ?? true else {
            return .permission
        }

        if let status = detail.request.detailedMergeStatus {
            return Self.gitlabBlock(detailedStatus: status)
        }

        if let block = Self.legacyGitLabBlock(detail, project: project) {
            return block
        }

        return try await gitlabApprovalsLeft(request.id) > 0 ? .policy("not_approved") : nil
    }

    /// EE 上还差的审批数；CE 没有这个接口或不返回 `approvals_left` 时当作没有审批要求。
    private func gitlabApprovalsLeft(_ id: PullRequestID) async throws -> Int {
        do {
            let response: HostingResponse<GitLabApprovals> = try await send(
                "GET",
                Self.gitlabProject(id.project) + "/merge_requests/\(id.number)/approvals"
            )

            return response.value.approvalsLeft ?? 0
        } catch HostingError.notFound {
            return 0
        }
    }

    /// 请求上勾了压缩时先取消：只给合并接口传 `squash: false` 改不了请求上的设置。
    private func clearGitLabSquash(at path: String) async throws {
        let current: HostingResponse<GitLabMergeRequest> = try await send("GET", path)

        guard current.value.squash ?? false else {
            return
        }

        try await perform("PUT", path, body: try JSONEncoder().encode(["squash": false]))
    }

    /// 合并接口的失败按它在 GitLab 里的含义重新分类。
    private func gitlabMergeFailure(_ error: HostingError) async -> HostingError {
        switch error {
        case .unauthorized(let message):
            // 没有合并权限时也回 401：同一令牌还能读出用户，说明令牌有效，只是没有权限
            guard (try? await currentUser()) != nil else {
                return error
            }

            return .forbidden(message)

        case .rejected(let status, let message) where [405, 406, 422].contains(status):
            // 已经检出的冲突回 405，本次才算出的冲突回 406（15.3 起是 422）
            return .mergeConflict(message)

        default:
            return error
        }
    }
}

// MARK: - GitLab Merge Block

extension HostingClient {
    /// `detailed_merge_status` 对应的原因；15.6–16.10 的 `broken_status` 也是冲突。
    private static func gitlabBlock(detailedStatus status: String) -> PullRequestMergeBlock? {
        switch status {
        case "mergeable": nil
        case "conflict", "broken_status": .conflicts
        case "draft_status": .draft
        case "not_open": .notOpen
        case "checking", "unchecked", "preparing", "approvals_syncing": .checking
        default: .policy(status)
        }
    }

    /// 用旧字段推出的原因，旧版本缺的字段对应的那项不判断；讨论与流水线写成新版 `detailed_merge_status` 的同名取值。
    private static func legacyGitLabBlock(_ detail: GitLabMergeDetail, project: GitLabProject) -> PullRequestMergeBlock? {
        let payload = detail.request

        if payload.draft ?? payload.workInProgress ?? false {
            return .draft
        }

        // 10.5 以前读取时不同步计算，可能一直是 unchecked，同样按正在检查
        if ["unchecked", "checking", "cannot_be_merged_recheck"].contains(payload.mergeStatus) {
            return .checking
        }

        // 没有 has_conflicts（12.5 以前）时只看 merge_status
        if payload.hasConflicts ?? false || payload.mergeStatus == "cannot_be_merged" {
            return .conflicts
        }

        // 没有 blocking_discussions_resolved（12.5 以前）时不判断
        if
            project.onlyAllowMergeIfAllDiscussionsAreResolved ?? false,
            !(payload.blockingDiscussionsResolved ?? true)
        {
            return .policy("discussions_not_resolved")
        }

        // 响应里没有流水线字段（10.6 以前）时不判断；字段为 null 是没有流水线，算没通过
        if
            project.onlyAllowMergeIfPipelineSucceeds ?? false,
            detail.reportsPipeline,
            detail.pipeline?.status != "success"
        {
            return .policy("ci_must_pass")
        }

        return nil
    }
}

// MARK: - GitLabMergeDetail

/// 合并前读取的 Merge Request 详情：请求本身，加上最新的流水线。
///
/// 流水线要区分响应里没有这个键（旧版本，判断不了）与值为 null（没有流水线），所以单独解码。
private struct GitLabMergeDetail: Decodable, Sendable {
    /// 流水线的字段名：解码器先把蛇形字段转成驼峰。
    private enum PipelineKeys: String, CodingKey {
        case headPipeline, pipeline
    }

    /// 请求本身。
    let request: GitLabMergeRequest

    /// 响应里有流水线字段：`head_pipeline`，或 10.6 起单个请求的 `pipeline`。
    let reportsPipeline: Bool

    /// 最新的流水线；没有流水线时为 nil。
    let pipeline: GitLabPipeline?

    /// 先解码请求本身，再取流水线：先取 `head_pipeline`，响应里没有这个键再取可能为空或落后于最新流水线的 `pipeline`。
    init(from decoder: any Decoder) throws {
        request = try GitLabMergeRequest(from: decoder)

        let container = try decoder.container(keyedBy: PipelineKeys.self)
        let key = [PipelineKeys.headPipeline, .pipeline].first { container.contains($0) }

        reportsPipeline = key != nil
        pipeline = try key.flatMap { try container.decodeIfPresent(GitLabPipeline.self, forKey: $0) }
    }
}

// MARK: - GitLabPipeline

/// GitLab 流水线里用到的字段。
private struct GitLabPipeline: Decodable, Sendable {
    /// 状态，如 `success`、`failed`、`running`。
    let status: String?
}

// MARK: - GitLabApprovals

/// GitLab 请求的审批里用到的字段。
private struct GitLabApprovals: Decodable, Sendable {
    /// 还差的审批数；只有 EE 返回。
    let approvalsLeft: Int?
}
