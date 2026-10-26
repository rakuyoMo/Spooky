import Foundation
import Observation
import SpookyKit

// MARK: - PullRequestRequest

/// 请求视图里由窗口呈现的对话框。
enum PullRequestRequest {
    /// 新建请求；可以预选源分支。
    case create(sourceBranch: String?)

    /// 修改标题、描述与目标分支。
    case edit(PullRequest)

    /// 在托管服务上合并。
    case merge(PullRequest)

    /// 发表评论。
    case comment(PullRequest)

    /// 检出成本地分支。
    case checkout(PullRequest)

    /// 把远端手动关联到账号与项目。
    case associate(remote: String, url: String)

    /// 在托管服务上新建仓库并发布到那里。
    case publish
}

// MARK: - RepositoryPullRequestState

/// 一个仓库窗口的请求视图：选中的远端、它对应的账号与项目、请求列表与所选请求的详情。
///
/// 托管服务的接口从本机调用；提交与改动在仓库所在的机器上比较。过期请求的结果不能倒灌。
@MainActor
@Observable
final class RepositoryPullRequestState {
    /// 详情的三段。
    enum Page: Hashable {
        /// 描述与评论。
        case conversation

        /// 源分支里的提交。
        case commits

        /// 合并基准到源分支的改动。
        case changeset
    }

    /// 仓库的远端名与获取地址。
    private(set) var remotes: [RemoteConfiguration] = []

    /// 选中的远端名。
    private(set) var remote: String? = nil

    /// 选中远端对应的账号与项目；还没有读取时为 nil。
    private(set) var target: PullRequestTarget? = nil

    /// 已读到的打开着的请求。
    private(set) var items: [PullRequest] = []

    /// 下一页的页码；没有更多时为 nil。
    private(set) var nextPage: Int? = nil

    /// 正在读取列表。
    private(set) var isLoading = false

    /// 第一次读取完成前不显示空状态。
    private(set) var isLoaded = false

    /// 读取远端或列表的失败。
    private(set) var failure: AppFailure? = nil

    /// 读取列表失败时的原始错误，用来判断是否提供重新认证。
    private(set) var failureError: HostingError? = nil

    /// 选中的请求。
    private(set) var selectedID: PullRequestID? = nil

    /// 选中请求的详情。
    private(set) var detail: PullRequest? = nil

    /// 选中请求的评论。
    private(set) var comments: [PullRequestComment] = []

    /// 正在读取详情。
    private(set) var isLoadingDetail = false

    /// 读取详情的失败。
    private(set) var detailFailure: AppFailure? = nil

    /// 源分支的提交还不在仓库里，提交与改动要先获取。
    private(set) var needsFetch = false

    /// 详情显示的一段。
    var page = Page.conversation

    /// 分支整理用的各分支对应的请求：源分支名到同一项目里最近的一个请求，任何状态都算；还没读到或远端对应不上账号时为 nil。
    private(set) var branchRequests: [String: PullRequest]? = nil

    /// 读取分支对应的请求的失败。
    private(set) var branchRequestsFailure: AppFailure? = nil

    /// 提交与改动两段共用的比较。
    let comparison = RevisionComparisonState()

    /// 对话框由窗口呈现。
    @ObservationIgnored
    var onRequest: ((PullRequestRequest) -> Void)? = nil

    /// 账号与令牌的来源；测试换成不写钥匙串的一份。
    @ObservationIgnored
    var accounts = HostingAccounts.shared

    /// 列表读取任务。
    @ObservationIgnored
    private var listTask: Task<Void, Never>? = nil

    /// 详情读取任务。
    @ObservationIgnored
    private var detailTask: Task<Void, Never>? = nil

    /// 关闭仓库或重新读取时递增，丢弃迟到的结果。
    @ObservationIgnored
    private var generation = 0

    /// 上次为 `#` 补全读到的 Issue：项目、结果与读取的时刻。
    @ObservationIgnored
    private var issueCache: (project: String, issues: [HostingIssue], date: Date)? = nil

    /// 上次读取分支对应的请求的时刻。
    @ObservationIgnored
    private var branchRequestsDate: Date? = nil

    /// 选中远端对应的账号；对应不上时为 nil。
    var account: HostingAccount? {
        guard case .resolved(let account, _) = target else { return nil }
        return account
    }

    /// 选中远端对应的项目路径。
    var project: String? {
        switch target {
        case .resolved(_, let project), .chooseAccount(_, let project): project
        default: nil
        }
    }

    /// 选中远端的获取地址。
    var remoteURL: String? {
        remotes.first { $0.name == remote }?.url
    }

    /// 选中远端对应账号的接口客户端；令牌不在钥匙串里时为 nil。
    var client: HostingClient? {
        account.flatMap { accounts.client(for: $0) }
    }

    /// 读出远端，沿用已选的远端，否则选 origin 或第一个，再读取它的请求。
    func load(runner: GitRunner) {
        generation += 1
        listTask?.cancel()

        let request = generation
        isLoading = true

        listTask = Task { [weak self] in
            do {
                let remotes = try await RepositoryRemotes(runner: runner).configurations()
                guard let self, generation == request else { return }

                self.remotes = remotes

                let names = remotes.map(\.name)
                remote = remote.flatMap { names.contains($0) ? $0 : nil } ?? (names.contains("origin") ? "origin" : names.first)
                await loadList(request: request)
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }
                report(error, location: runner.location)
            }
        }
    }

    /// 换一个远端并重新读取；上一个远端的列表不留到新远端下。
    func select(remote name: String, runner: GitRunner) {
        guard name != remote else { return }

        remote = name
        items = []
        nextPage = nil
        selectedID = nil
        clearDetail()
        load(runner: runner)
    }

    /// 读取下一页请求。
    func loadMore() {
        guard !isLoading, let page = nextPage, let client, let project else {
            return
        }

        let request = generation
        isLoading = true

        listTask = Task { [weak self] in
            do {
                let result = try await client.pullRequests(in: project, page: page)
                guard let self, generation == request else { return }

                items += result.items.filter { item in !items.contains { $0.id == item.id } }
                nextPage = result.nextPage
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }
                report(error, location: nil)
            }

            self?.isLoading = false
        }
    }

    /// 选中一个请求，读取详情、评论与比较。
    func select(_ id: PullRequestID?, runner: GitRunner) {
        guard id != selectedID || detail == nil else { return }

        selectedID = id
        clearDetail()

        guard let id else { return }
        reloadDetail(of: id, runner: runner)
    }

    /// 重新读取所选请求的详情与评论；源分支提交在仓库里时比较提交与改动。
    func reloadDetail(runner: GitRunner) {
        guard let selectedID else { return }
        reloadDetail(of: selectedID, runner: runner)
    }

    /// 提交信息 `#` 补全用的打开着的 Issue；远端对应不上账号时没有；一分钟内复用上次的结果。
    ///
    /// - Parameters:
    ///   - runner: 仓库的执行器，读取远端地址。
    ///   - upstreamRemote: HEAD 跟踪的远端。
    func openIssues(runner: GitRunner, upstreamRemote: String?) async -> [HostingIssue] {
        guard let (_, project, client) = await mainTarget(runner: runner, upstreamRemote: upstreamRemote) else {
            return []
        }

        if let cache = issueCache, cache.project == project, Date().timeIntervalSince(cache.date) < 60 {
            return cache.issues
        }

        guard let issues = try? await client.openIssues(in: project) else {
            return []
        }

        issueCache = (project, issues, Date())
        return issues
    }

    /// 读取分支整理用的各分支对应的请求：最近的三页，同一项目里每个源分支取最近的一个；一分钟内不重复读取。
    ///
    /// - Parameters:
    ///   - runner: 仓库的执行器，读取远端地址。
    ///   - upstreamRemote: HEAD 跟踪的远端。
    func loadBranchRequests(runner: GitRunner, upstreamRemote: String?) async {
        if let date = branchRequestsDate, Date().timeIntervalSince(date) < 60 {
            return
        }

        branchRequestsDate = Date()

        guard let (_, project, client) = await mainTarget(runner: runner, upstreamRemote: upstreamRemote) else {
            branchRequests = nil
            branchRequestsFailure = nil
            return
        }

        do {
            var requests: [String: PullRequest] = [:]
            var page: Int? = 1

            while let current = page, current <= 3 {
                let result = try await client.pullRequests(in: project, page: current, includesClosed: true)

                // 列表从新到旧，同一分支只留最近的一个
                for request in result.items where request.source.project == project && requests[request.source.branch] == nil {
                    requests[request.source.branch] = request
                }

                page = result.nextPage
            }

            branchRequests = requests
            branchRequestsFailure = nil
        } catch {
            branchRequests = nil
            branchRequestsFailure = AppFailure(error: error, opening: false, location: runner.location)
            markRejectedToken(error)
        }
    }

    /// 关闭仓库时清空并取消全部读取。
    func close() {
        generation += 1
        issueCache = nil
        branchRequests = nil
        branchRequestsFailure = nil
        branchRequestsDate = nil
        listTask?.cancel()
        listTask = nil
        remotes = []
        remote = nil
        target = nil
        items = []
        nextPage = nil
        isLoading = false
        isLoaded = false
        failure = nil
        failureError = nil
        selectedID = nil
        clearDetail()
    }
}

// MARK: - Loading

extension RepositoryPullRequestState {
    /// 选中远端对应账号与项目后读第一页。
    private func loadList(request: Int) async {
        let associations = PullRequestAssociations.load()

        target = remoteURL.map {
            PullRequestTarget.resolve(remoteURL: $0, accounts: accounts.items, associations: associations)
        }

        guard let client, let project else {
            items = []
            nextPage = nil
            failure = nil
            failureError = nil
            finishLoading(request)
            return
        }

        do {
            let result = try await client.pullRequests(in: project)
            guard generation == request else { return }

            items = result.items
            nextPage = result.nextPage
            failure = nil
            failureError = nil

            // 选中的请求已不在列表里时清掉详情
            if let selectedID, !items.contains(where: { $0.id == selectedID }) {
                self.selectedID = nil
                clearDetail()
            }
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            report(error, location: nil)
        }

        finishLoading(request)
    }

    /// 读取详情、评论与比较基准。
    private func reloadDetail(of id: PullRequestID, runner: GitRunner) {
        guard let client else { return }

        detailTask?.cancel()
        isLoadingDetail = true

        let request = generation

        detailTask = Task { [weak self] in
            do {
                async let detail = client.pullRequest(id)
                async let comments = client.comments(on: id)
                let loaded = try await (detail, comments)

                guard let self, generation == request, selectedID == id else { return }

                (self.detail, self.comments) = loaded
                detailFailure = nil

                try await openComparison(loaded.0, runner: runner)
            } catch {
                guard let self, generation == request, selectedID == id, !Task.isCancelled else { return }
                detailFailure = AppFailure(error: error, opening: false, location: nil)
                markRejectedToken(error)
            }

            guard let self, generation == request else { return }
            isLoadingDetail = false
        }
    }

    /// 源分支提交在仓库里时比较合并基准与源分支，否则标出需要获取。
    private func openComparison(_ request: PullRequest, runner: GitRunner) async throws {
        let pulls = RepositoryPullRequests(runner: runner)

        guard try await pulls.hasCommit(request.source.sha), let base = try await pulls.comparisonBase(for: request) else {
            needsFetch = true
            comparison.close()
            return
        }

        needsFetch = false
        comparison.open(
            base: RevisionComparisonState.Side(id: base, title: request.target.branch),
            target: RevisionComparisonState.Side(id: request.source.sha, title: request.source.branch),
            runner: runner
        )
    }

    /// 清掉详情与比较。
    private func clearDetail() {
        detailTask?.cancel()
        detailTask = nil
        detail = nil
        comments = []
        isLoadingDetail = false
        detailFailure = nil
        needsFetch = false
        comparison.close()
    }

    /// 列表读取结束。
    private func finishLoading(_ request: Int) {
        guard generation == request else { return }

        isLoading = false
        isLoaded = true
    }

    /// 记下失败；令牌被拒绝时标记账号需要重新认证。
    private func report(_ error: any Error, location: RepositoryLocation?) {
        failure = AppFailure(error: error, opening: false, location: location)
        failureError = error as? HostingError
        isLoading = false
        isLoaded = true
        markRejectedToken(error)
    }

    /// 补全与分支整理用的远端对应的账号、项目与客户端：远端按选中的、HEAD 跟踪的、origin、第一个的顺序取。
    private func mainTarget(runner: GitRunner, upstreamRemote: String?) async -> (HostingAccount, String, HostingClient)? {
        guard let remotes = try? await RepositoryRemotes(runner: runner).configurations() else {
            return nil
        }

        let names = [remote, upstreamRemote, "origin", remotes.first?.name].compactMap { $0 }
        let url = names.lazy.compactMap { name in remotes.first { $0.name == name }?.url }.first
        let target = url.map {
            PullRequestTarget.resolve(remoteURL: $0, accounts: accounts.items, associations: PullRequestAssociations.load())
        }

        guard case .resolved(let account, let project) = target, let client = accounts.client(for: account) else {
            return nil
        }

        return (account, project, client)
    }

    /// 托管服务拒绝令牌时标记账号。
    private func markRejectedToken(_ error: any Error) {
        guard case HostingError.unauthorized = error, let account else { return }
        accounts.markNeedsReauthentication(account)
    }
}
