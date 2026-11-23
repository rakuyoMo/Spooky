import Foundation

// MARK: - Checks

extension HostingClient {
    /// 请求的 CI/CD 状态：GitHub 读源分支最新提交上的检查运行与提交状态，GitLab 读请求最新的流水线与其中的作业。
    public func checks(for request: PullRequest) async throws -> PullRequestChecks {
        switch instance.service {
        case .github: try await githubChecks(for: request)
        case .gitlab: try await gitlabChecks(for: request.id)
        }
    }

    /// 请求 CI/CD 的整体状态；没有检查或流水线时为 nil。GitLab 只读流水线的状态，不读其中的作业。
    public func checkState(for request: PullRequest) async throws -> PullRequestCheckState? {
        switch instance.service {
        case .github:
            try await githubChecks(for: request).state

        case .gitlab:
            try await gitlabPipeline(of: request.id)?.status.map { PullRequestCheckState(gitlabStatus: $0) }
        }
    }
}

// MARK: - GitHub

extension HostingClient {
    /// 源分支最新提交上的检查运行与提交状态，两种都读，整体状态由各项合成；源分支提交未知时没有检查。
    ///
    /// 检查运行记在目标仓库里，来自 Fork 的请求同样从目标仓库按提交读取。
    private func githubChecks(for request: PullRequest) async throws -> PullRequestChecks {
        guard !request.source.sha.isEmpty else {
            return PullRequestChecks(state: nil, items: [])
        }

        let commit = Self.githubRepository(request.id.project) + "/commits/" + Self.encodedSegment(request.source.sha)

        async let runs = githubCheckRuns(at: commit)
        async let statuses = githubStatuses(at: commit)

        let items = try await runs + statuses

        return PullRequestChecks(state: PullRequestCheckState.overall(of: items.map(\.state)), items: items)
    }

    /// 提交上的检查运行，逐页读完，按创建的先后排列；同名的检查只有最近的一次。
    private func githubCheckRuns(at commit: String) async throws -> [PullRequestCheck] {
        var runs: [GitHubCheckRuns.Run] = []
        var page: Int? = 1

        while let current = page {
            let response: HostingResponse<GitHubCheckRuns> = try await send(
                "GET",
                commit + "/check-runs",
                query: [URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "page", value: String(current))]
            )

            runs += response.value.checkRuns
            page = response.nextPage
        }

        // 接口从新到旧给出，编号随创建递增
        return runs.sorted { $0.id < $1.id }.map {
            PullRequestCheck(
                id: "run-\($0.id)",
                name: $0.name,
                group: $0.app?.name,
                state: PullRequestCheckState(githubStatus: $0.status, conclusion: $0.conclusion)
            )
        }
    }

    /// 提交上各个 context 最近的一条提交状态，逐页读完。
    private func githubStatuses(at commit: String) async throws -> [PullRequestCheck] {
        var statuses: [GitHubCombinedStatus.Status] = []
        var page: Int? = 1

        while let current = page {
            let response: HostingResponse<GitHubCombinedStatus> = try await send(
                "GET",
                commit + "/status",
                query: [URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "page", value: String(current))]
            )

            statuses += response.value.statuses
            page = response.nextPage
        }

        return statuses.map {
            PullRequestCheck(
                id: "status-\($0.id)",
                name: $0.context,
                group: nil,
                state: PullRequestCheckState(githubState: $0.state)
            )
        }
    }
}

// MARK: - GitLab

extension HostingClient {
    /// 请求最新的流水线；没有流水线，或当前账号看不到时为 nil。
    private func gitlabPipeline(of id: PullRequestID) async throws -> GitLabPipeline? {
        let response: HostingResponse<GitLabMergeDetail> = try await send(
            "GET",
            Self.gitlabProject(id.project) + "/merge_requests/\(id.number)"
        )

        return response.value.pipeline
    }

    /// 请求最新的流水线与其中的作业，作业逐页读完、按创建的先后排列，重试过的作业只有最近的一次。
    private func gitlabChecks(for id: PullRequestID) async throws -> PullRequestChecks {
        guard let pipeline = try await gitlabPipeline(of: id) else {
            return PullRequestChecks(state: nil, items: [])
        }

        let state = pipeline.status.map { PullRequestCheckState(gitlabStatus: $0) }

        guard let pipelineID = pipeline.id else {
            return PullRequestChecks(state: state, items: [])
        }

        // 来自 Fork 的请求，流水线可能在源项目里：响应带项目编号时按编号读
        let project = pipeline.projectID.map { "projects/\($0)" } ?? Self.gitlabProject(id.project)
        var jobs: [GitLabJob] = []
        var page: Int? = 1

        while let current = page {
            let response: HostingResponse<[GitLabJob]> = try await send(
                "GET",
                project + "/pipelines/\(pipelineID)/jobs",
                query: [URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "page", value: String(current))]
            )

            jobs += response.value
            page = response.nextPage
        }

        // 接口从新到旧给出，编号随创建递增，同一阶段的作业编号相邻
        let items = jobs.sorted { $0.id < $1.id }.map {
            PullRequestCheck(
                id: "job-\($0.id)",
                name: $0.name,
                group: $0.stage,
                state: PullRequestCheckState(gitlabStatus: $0.status)
            )
        }

        return PullRequestChecks(state: state, items: items)
    }
}

// MARK: - GitHubCheckRuns

/// GitHub 一页检查运行。
private struct GitHubCheckRuns: Decodable, Sendable {
    /// 一次检查运行。
    struct Run: Decodable, Sendable {
        /// 写下检查运行的应用。
        struct App: Decodable, Sendable {
            /// 应用的名字，如 `GitHub Actions`。
            let name: String?
        }

        /// 编号。
        let id: Int

        /// 名字。
        let name: String

        /// `completed`、`in_progress`，或还没开始的几种状态。
        let status: String

        /// 结束后的结论；还没结束时为 null。
        let conclusion: String?

        /// 写下它的应用。
        let app: App?
    }

    /// 这一页的检查运行。
    let checkRuns: [Run]
}

// MARK: - GitHubCombinedStatus

/// GitHub 提交上合并后的提交状态的一页。
private struct GitHubCombinedStatus: Decodable, Sendable {
    /// 一个 context 最近的一条状态。
    struct Status: Decodable, Sendable {
        /// 编号。
        let id: Int

        /// `success`、`pending`、`failure` 或 `error`。
        let state: String

        /// 写下状态的服务给它起的名字。
        let context: String
    }

    /// 这一页的状态。
    let statuses: [Status]
}

// MARK: - GitLabJob

/// GitLab 流水线里的一个作业。
private struct GitLabJob: Decodable, Sendable {
    /// 编号。
    let id: Int

    /// 作业名。
    let name: String

    /// 所在的阶段。
    let stage: String?

    /// 状态，如 `success`、`failed`、`running`。
    let status: String
}
