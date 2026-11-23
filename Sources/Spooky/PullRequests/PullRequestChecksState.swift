import Foundation
import Observation
import SpookyKit

// MARK: - PullRequestChecksState

/// 请求的 CI/CD 状态：列表各行的整体状态，与所选请求的各项。
///
/// 列表接口不带 CI/CD 状态，按请求各读一次；所选请求的状态在还有等待中或运行中的项时自动刷新。
/// 过期读取的结果不能倒灌。
@MainActor
@Observable
final class PullRequestChecksState {
    /// 一个请求的整体状态上次读取时的源分支提交与时刻。
    private struct Reading {
        /// 读取时请求的源分支提交。
        let sha: String

        /// 读完的时刻。
        let date: Date
    }

    /// 自动刷新的间隔。
    nonisolated static let refreshInterval = Duration.seconds(15)

    /// 列表里同时读取状态的请求数。
    private static let concurrency = 4

    /// 列表里各请求 CI/CD 的整体状态；没有检查或流水线、还没读到的请求不在其中。
    private(set) var states: [PullRequestID: PullRequestCheckState] = [:]

    /// 所选请求的 CI/CD 状态；还没读到时为 nil。
    private(set) var selected: PullRequestChecks? = nil

    /// 读取所选请求状态的失败；自动刷新失败时已读到的状态保留。
    private(set) var failure: AppFailure? = nil

    /// 两次自动刷新之间的等待；测试换成由测试放行的一份。
    @ObservationIgnored
    var wait: @Sendable () async throws -> Void = { try await Task.sleep(for: refreshInterval) }

    /// 各请求的整体状态上次读取的记录，读取失败的也记。
    @ObservationIgnored
    private var readings: [PullRequestID: Reading] = [:]

    /// 读取列表各行状态的任务，每读到一页请求起一个。
    @ObservationIgnored
    private(set) var listTasks: [Task<Void, Never>] = []

    /// 列表从头读取或关闭时递增，丢弃迟到的整体状态。
    @ObservationIgnored
    private var listGeneration = 0

    /// 换一个所选请求或关闭时递增，丢弃迟到的所选请求状态。
    @ObservationIgnored
    private var selectionGeneration = 0

    /// 读取一页请求 CI/CD 的整体状态，读到一个记下一个；一页合成 Activity 里的一条记录。
    ///
    /// 一分钟内读过、源分支提交没变、也不在等待或运行中的请求不再读。
    ///
    /// - Parameters:
    ///   - requests: 这一页的请求。
    ///   - restarts: 列表从头读取，取消还没读完的各页。
    ///   - client: 账号的客户端。
    ///   - repository: 列表所属的仓库，记进 Activity。
    func loadStates(
        of requests: [PullRequest],
        restarts: Bool,
        client: HostingClient,
        repository: RepositoryLocation?
    ) {
        if restarts {
            cancelList()
        }

        let now = Date()

        let pending = requests.filter { request in
            guard let reading = readings[request.id], reading.sha == request.source.sha else {
                return true
            }

            return (states[request.id]?.isActive ?? false) || now.timeIntervalSince(reading.date) >= 60
        }

        guard !pending.isEmpty else { return }

        let generation = listGeneration

        listTasks.append(
            Task { [weak self] in
                await self?.recordStates(of: pending, client: client, repository: repository, generation: generation)
            }
        )
    }

    /// 读取所选请求的 CI/CD 状态；只要还有等待中或运行中的项，就每隔 ``refreshInterval`` 再读一次，直到任务被取消。
    ///
    /// 第一次读取记进 Activity，自动刷新不记；读取失败时停下并记下失败。列表里这个请求的整体状态随之更新。
    ///
    /// - Parameters:
    ///   - request: 所选的请求。
    ///   - client: 账号的客户端。
    ///   - repository: 请求所属的仓库，记进 Activity。
    func watch(_ request: PullRequest, client: HostingClient, repository: RepositoryLocation?) async {
        let generation = selectionGeneration
        var records = true

        while true {
            do {
                let checks = try await read(request, client: client, repository: repository, records: records)

                guard !Task.isCancelled, generation == selectionGeneration else { return }

                selected = checks
                failure = nil
                states[request.id] = checks.state
                readings[request.id] = Reading(sha: request.source.sha, date: Date())

                guard checks.isActive else { return }

                try await wait()
            } catch {
                guard !Task.isCancelled, generation == selectionGeneration else { return }

                failure = AppFailure(error: error, opening: false, location: nil)
                return
            }

            records = false
        }
    }

    /// 换一个所选请求时清掉上一个请求的状态。
    func clearSelected() {
        selectionGeneration += 1
        selected = nil
        failure = nil
    }

    /// 关闭仓库或换远端时清空并取消列表各行的读取。
    func close() {
        cancelList()
        states = [:]
        readings = [:]
        clearSelected()
    }
}

// MARK: - Private

extension PullRequestChecksState {
    /// 一个请求，与它的整体状态或读取的失败。
    private typealias StateResult = (request: PullRequest, state: Result<PullRequestCheckState?, any Error>)

    /// 读出一个请求的整体状态；失败留在结果里，不打断同一页其余请求的读取。
    private nonisolated static func state(of request: PullRequest, client: HostingClient) async -> StateResult {
        do {
            return (request, .success(try await client.checkState(for: request)))
        } catch {
            return (request, .failure(error))
        }
    }

    /// 把一页请求整体状态的读取记成 Activity 里的一条；读取的失败只留在这条记录里。
    private func recordStates(
        of requests: [PullRequest],
        client: HostingClient,
        repository: RepositoryLocation?,
        generation: Int
    ) async {
        _ = try? await RepositoryActivities.shared.recordHosting(
            title: AppLocalization.text("pullRequests.loadChecks.title"),
            repository: repository
        ) {
            try await readStates(of: requests, client: client, generation: generation)
        }
    }

    /// 逐个读出请求的整体状态，同时最多读 `concurrency` 个；读取失败的请求保留已读到的状态。
    ///
    /// 全部读完后抛出遇到的第一个失败，这一页的记录随之算失败。
    private func readStates(of requests: [PullRequest], client: HostingClient, generation: Int) async throws {
        var failure: (any Error)? = nil

        await withTaskGroup(of: StateResult.self) { group in
            var remaining = requests.makeIterator()

            // 先放进同时读取的个数，之后每读完一个再放进一个
            for _ in 0 ..< Self.concurrency {
                guard let request = remaining.next() else { break }
                group.addTask { await Self.state(of: request, client: client) }
            }

            for await result in group {
                if let request = remaining.next() {
                    group.addTask { await Self.state(of: request, client: client) }
                }

                guard generation == listGeneration else { continue }

                readings[result.request.id] = Reading(sha: result.request.source.sha, date: Date())

                switch result.state {
                case .success(let state): states[result.request.id] = state
                case .failure(let error): failure = failure ?? error
                }
            }
        }

        if let failure {
            throw failure
        }
    }

    /// 读一次所选请求的 CI/CD 状态；要记录时记进 Activity 的 Service 页。
    private func read(
        _ request: PullRequest,
        client: HostingClient,
        repository: RepositoryLocation?,
        records: Bool
    ) async throws -> PullRequestChecks {
        guard records else {
            return try await client.checks(for: request)
        }

        return try await RepositoryActivities.shared.recordHosting(
            title: AppLocalization.text("pullRequests.loadChecks.title"),
            repository: repository
        ) {
            try await client.checks(for: request)
        }
    }

    /// 取消列表各行还没读完的读取。
    private func cancelList() {
        listGeneration += 1
        for listTask in listTasks { listTask.cancel() }
        listTasks = []
    }
}
