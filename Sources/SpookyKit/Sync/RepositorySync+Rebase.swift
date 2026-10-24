import Foundation

// MARK: - SyncStep

/// 同步的三个步骤，按 Fetch → Pull → Push 的顺序执行。
public enum SyncStep: Int, Sendable, CaseIterable, Comparable {
    /// 获取所选远端。
    case fetch

    /// 把所选远端分支并入当前分支。
    case pull

    /// 把当前分支推回同一个远端分支。
    case push

    /// 按执行顺序比较。
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - SyncOptions

/// 同步对话框的选项：拉取部分的合并方式与签名校验，推送部分的标签、子模块与钩子。
public struct SyncOptions: Sendable, Equatable {
    /// 以变基代替合并并入远端分支。
    public var rebase = false

    /// 要求取回的提交有可信签名。
    public var verifySignatures = false

    /// 推送的附带选项；其中的跳过钩子同样作用于拉取。
    public var push = PushOptions()

    /// 默认以合并方式同步。
    public init() { }
}

// MARK: - Rebase & Sync

extension RepositorySync {
    /// 把当前分支变基到所选版本之上；开始前核对当前分支与工作区，冲突时留下进行中的变基。
    ///
    /// - Parameters:
    ///   - revision: 变基的目标，可以是分支、标签或提交。
    ///   - skipHooks: 跳过 pre-rebase 钩子。
    public func rebase(
        onto revision: String,
        skipHooks: Bool = false,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            let status = try await runner.status()

            guard status.branch.head != nil, status.branch.oid != nil else {
                throw RepositorySyncError.requiresBranch
            }

            guard status.entries.isEmpty else {
                throw RepositorySyncError.dirtyWorkingCopy
            }

            let target = try await RepositoryReferences(runner: runner).resolve(revision)
            try await rebaseCurrentBranch(onto: target, skipHooks: skipHooks, onOutput: onOutput)
        }
    }

    /// 依次获取远端、拉取所选远端分支、再推回同一个远端分支，三步持有同一个仓库写锁。
    ///
    /// 任何一步失败都停在这一步并抛出它的错误，后面的步骤不再执行；每一步开始前先调用 `onStep`。
    ///
    /// - Parameters:
    ///   - remote: 远端名。
    ///   - branch: 远端上的完整分支引用名，如 `refs/heads/main`。
    public func sync(
        remote: String,
        branch: String,
        options: SyncOptions = SyncOptions(),
        onStep: @escaping @Sendable (SyncStep) async -> Void = { _ in },
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            let status = try await runner.status()

            guard let current = status.branch.head, status.branch.oid != nil else {
                throw RepositorySyncError.requiresBranch
            }

            // 工作区不干净时在获取之前就停下，自动储藏可以在任何步骤开始前介入
            guard status.entries.isEmpty else {
                throw RepositorySyncError.dirtyWorkingCopy
            }

            let target = try await pullTarget(remote: remote, branch: branch, current: current)

            await onStep(.fetch)
            _ = try await fetch(remote: target.remote, onOutput: onOutput)

            await onStep(.pull)
            try await pull(
                remote: target.remote,
                branch: target.branch,
                rebase: options.rebase,
                verifySignatures: options.verifySignatures,
                skipHooks: options.push.skipHooks,
                onOutput: onOutput
            )

            await onStep(.push)
            _ = try await push(
                branch: current,
                remote: target.remote,
                destination: String(target.branch.dropFirst("refs/heads/".count)),
                setUpstream: false,
                options: options.push,
                onOutput: onOutput
            )
        }
    }
}
