import Foundation

// MARK: - PullRequestCheckoutError

/// 检出请求时在执行 Git 之前就能判断的失败。
public enum PullRequestCheckoutError: Error, Sendable, Equatable {
    /// 同名的本地分支已存在，但指向别的提交；带上分支名。
    case branchMismatch(String)
}

// MARK: - RepositoryPullRequests

/// 请求在仓库所在机器上的 Git 动作：取回源分支的提交、确定比较基准与检出成本地分支；服务器仓库都在服务器上执行。
public struct RepositoryPullRequests: Sendable {
    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 创建服务，不立即执行命令。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 托管服务在目标项目里为请求保留的源分支引用：GitHub 是 `refs/pull/<编号>/head`，GitLab 是 `refs/merge-requests/<编号>/head`；来自 Fork 的请求同样有。
    public static func headReference(of id: PullRequestID) -> String {
        switch id.instance.service {
        case .github: "refs/pull/\(id.number)/head"
        case .gitlab: "refs/merge-requests/\(id.number)/head"
        }
    }

    /// 仓库里是否已有这个提交。
    public func hasCommit(_ sha: String) async throws -> Bool {
        guard GitObjectID.isValid(sha) else {
            return false
        }

        let result = try await runner.execute(
            ["rev-parse", "--verify", "--quiet", "--end-of-options", sha + "^{commit}"],
            acceptedExitCodes: [0, 1]
        )

        return result.exitCode == 0
    }

    /// 比较基准：托管服务给出的合并基准，否则在本机算出目标分支与源分支的 merge-base；提交不在仓库里时为 nil。
    public func comparisonBase(for request: PullRequest) async throws -> String? {
        if let base = request.mergeBase, try await hasCommit(base) {
            return base
        }

        guard try await hasCommit(request.target.sha), try await hasCommit(request.source.sha) else {
            return nil
        }

        let output = try await runner.run(["merge-base", request.target.sha, request.source.sha])
        let base = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        return GitObjectID.isValid(base) ? base : nil
    }

    /// 从远端取回请求的源分支提交，只写进 FETCH_HEAD，不改动本地与远端跟踪分支。
    ///
    /// - Parameters:
    ///   - id: 请求。
    ///   - remote: 指向目标项目的远端名。
    ///   - onOutput: 获取进度。
    public func fetchHead(
        of id: PullRequestID,
        from remote: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        _ = try await runner.execute(
            ["fetch", "--progress", "--no-recurse-submodules", "--no-auto-maintenance", "--", remote, Self.headReference(of: id)],
            onOutput: onOutput
        )
    }

    /// 检出请求：先取回源分支的提交；同名本地分支已指向它时直接检出，指向别处时报错；否则新建分支，
    /// 同仓库的请求在远端跟踪分支正好是源分支提交时跟踪它。
    ///
    /// - Parameters:
    ///   - request: 要检出的请求。
    ///   - remote: 指向目标项目的远端名。
    ///   - name: 本地分支名。
    ///   - onOutput: 获取与检出的输出。
    public func checkout(
        _ request: PullRequest,
        remote: String,
        as name: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            let references = RepositoryReferences(runner: runner)
            try await references.validate(name: name)
            try await fetchHead(of: request.id, from: remote, onOutput: onOutput)

            if let existing = try await commit(of: "refs/heads/" + name) {
                guard existing == request.source.sha else {
                    throw PullRequestCheckoutError.branchMismatch(name)
                }

                _ = try await runner.execute(["switch", "--no-guess", "--", name], onOutput: onOutput)
                return
            }

            let tracking = "refs/remotes/" + remote + "/" + request.source.branch
            let tracks = !request.isFromFork ? try await commit(of: tracking) == request.source.sha : false

            _ = try await runner.execute(
                ["switch", "-c", name] + (tracks ? ["--track=direct", tracking] : ["--no-track", request.source.sha]),
                onOutput: onOutput
            )
        }
    }

    /// 引用指向的提交；引用不存在时为 nil。
    private func commit(of reference: String) async throws -> String? {
        let result = try await runner.execute(
            ["rev-parse", "--verify", "--quiet", "--end-of-options", reference + "^{commit}"],
            acceptedExitCodes: [0, 1]
        )

        let value = String(decoding: result.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
        return result.exitCode == 0 && GitObjectID.isValid(value) ? value : nil
    }
}
