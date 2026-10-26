import AppKit
import SpookyKit

// MARK: - Terminology

extension RepositorySession {
    /// 选中远端对应 GitLab 时界面叫 Merge Request，其余叫 Pull Request。
    var usesMergeRequests: Bool {
        pullRequests.target?.service == .gitlab
    }

    /// 按选中远端的服务取 Pull Request 或 Merge Request 的文案：资源键分别以 `pr.` 与 `mr.` 开头。
    ///
    /// - Parameters:
    ///   - key: `pr.` 之后的资源键。
    ///   - arguments: 格式参数。
    func pullRequestText(_ key: String, _ arguments: any CVarArg...) -> String {
        AppLocalization.text((usesMergeRequests ? "mr." : "pr.") + key, arguments: arguments)
    }
}

// MARK: - Navigation

extension RepositorySession {
    /// 在主视图显示请求；第一次显示时读取远端与列表。
    func showPullRequests() {
        history.showsCommitPage = false
        activeView = .pullRequests
        onActiveViewChange?()

        if !pullRequests.isLoaded {
            reloadPullRequests()
        }
    }

    /// 重新读取远端、列表与所选请求的详情。
    func reloadPullRequests() {
        guard let runner else { return }

        pullRequests.load(runner: runner)
        pullRequests.reloadDetail(runner: runner)
    }

    /// 交给窗口呈现请求的对话框。
    func requestPullRequest(_ request: PullRequestRequest) {
        pullRequests.onRequest?(request)
    }

    /// 本地或远端分支已有打开着的请求时返回它；只看已读到的列表。
    func pullRequest(forBranch branch: String) -> PullRequest? {
        let project = pullRequests.project

        return pullRequests.items.first { $0.source.branch == branch && $0.source.project == project }
    }
}

// MARK: - Hosting Actions

extension RepositorySession {
    /// 在托管服务上新建请求，成功后重新读取并选中它。
    func createPullRequest(_ draft: PullRequestDraft) -> Bool {
        performHosting(title: pullRequestText("create.title")) { [weak self] client in
            let created = try await client.createPullRequest(draft)

            await MainActor.run {
                guard let self, let runner = self.runner else { return }
                self.pullRequests.select(created.id, runner: runner)
            }

            return created.webURL?.absoluteString
        }
    }

    /// 修改标题、描述与目标分支。
    func updatePullRequest(_ request: PullRequest, title: String, body: String, targetBranch: String) -> Bool {
        performHosting(title: pullRequestText("edit.title")) { client in
            try await client.updatePullRequest(request.id, title: title, body: body, targetBranch: targetBranch)
            return nil
        }
    }

    /// 发表评论。
    func addComment(_ body: String, to request: PullRequest) -> Bool {
        performHosting(title: AppLocalization.text("pullRequests.comment.title")) { client in
            try await client.addComment(body, to: request.id)
            return nil
        }
    }

    /// 确认后关闭请求。
    func closePullRequest(_ request: PullRequest) {
        let site = request.id.instance.displayName

        onConfirm?(
            pullRequestText("close.title"),
            pullRequestText("close.message", request.id.reference, site),
            { [weak self] in
                self?.performHosting(title: self?.pullRequestText("close.title") ?? "") { client in
                    try await client.closePullRequest(request.id)
                    return nil
                }
            },
            nil
        )
    }

    /// 在托管服务上合并，成功后在仓库所在的机器上获取目标远端，让远端分支跟上合并结果。
    func mergePullRequest(_ request: PullRequest, method: PullRequestMergeMethod, deletesSourceBranch: Bool) -> Bool {
        let remote = pullRequests.remote

        return performHosting(title: pullRequestText("accept.title")) { [weak self] client in
            let result = try await client.merge(request, method: method, deletesSourceBranch: deletesSourceBranch)

            await MainActor.run {
                guard let self, let remote else { return }
                self.quickFetch(remote: remote)
            }

            return [result.message, result.sha].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        }
    }
}

// MARK: - Git Actions

extension RepositorySession {
    /// 取回请求的源分支提交，之后比较提交与改动。
    func fetchPullRequestHead(_ request: PullRequest) {
        guard let remote = pullRequests.remote else { return }

        performGit(
            { runner, output in
                try await RepositoryPullRequests(runner: runner).fetchHead(of: request.id, from: remote, onOutput: output)
            },
            title: pullRequestText("fetchHead.title", request.id.reference),
            success: { [weak self] in
                guard let self, let runner else { return }
                pullRequests.reloadDetail(runner: runner)
            }
        )
    }

    /// 把请求检出成本地分支；工作区有改动挡住时按设置询问先储藏。
    @discardableResult
    func checkoutPullRequest(_ request: PullRequest, as name: String) -> Bool {
        guard let remote = pullRequests.remote else { return false }

        return performGit(
            { runner, output in
                try await RepositoryPullRequests(runner: runner).checkout(request, remote: remote, as: name, onOutput: output)
            },
            title: pullRequestText("checkout.title"),
            offersAutoStash: true,
            undo: .reversible
        )
    }
}

// MARK: - Private

extension RepositorySession {
    /// 在托管服务上执行一次写操作：记进 Activity，原文写进日志；完成后重新读取，失败时弹出错误。
    ///
    /// - Parameters:
    ///   - title: Activity 的标题。
    ///   - action: 用账号的客户端执行写操作，返回要写进日志的服务端结果。
    /// - Returns: 是否已开始执行；选中远端没有可用的账号时为 false。
    @discardableResult
    private func performHosting(
        title: String,
        _ action: @escaping @Sendable (HostingClient) async throws -> String?
    ) -> Bool {
        guard let client = pullRequests.client, let repository else {
            return false
        }

        let activity = RepositoryActivity(repository: repository, title: title)
        RepositoryActivities.shared.insert(activity)

        Task { [weak self] in
            do {
                if let message = try await action(client), !message.isEmpty {
                    activity.append(.standardOutput(Data(message.utf8)))
                }

                activity.state = "activity.finished"
            } catch {
                let failure = AppFailure(error: error, opening: false, location: repository)
                activity.append(.standardError(Data(failure.details.utf8)))
                activity.state = "activity.failed"
                self?.onFailure?(failure)
            }

            self?.reloadPullRequests()
        }

        return true
    }
}
