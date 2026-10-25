import Foundation

// MARK: - RemoteRecoverySnapshot

/// 写操作中断后重新读取的仓库事实，不推测原命令是否成功。
public struct RemoteRecoverySnapshot: Sendable {
    /// 当前分支及工作区的完整状态。
    public let status: WorkingCopyStatus

    /// 外部进程是否仍持有暂存区锁。
    public let indexLocked: Bool

    /// 是否有合并尚未结束。
    public let merging: Bool

    /// 是否有变基尚未结束。
    public let rebasing: Bool

    /// 完成核对的时间，界面只采用晚于写入中断的核对结果。
    public let checkedAt: Date

    /// 远端跟踪分支的完整引用名与提交，用来核对获取与推送是否已经改动它们。
    public var remoteReferences: [String: String] = [:]

    /// 解析 `for-each-ref --format=%(refname)%00%(objectname)` 的输出：每行一个引用名、NUL、对象标识。
    static func parseReferences(_ data: Data) throws -> [String: String] {
        var references: [String: String] = [:]

        for line in data.split(separator: 10) {
            let fields = line.split(separator: 0, omittingEmptySubsequences: false)
            let object = fields.count == 2 ? String(decoding: fields[1], as: UTF8.self) : ""

            guard fields.count == 2, !fields[0].isEmpty, GitObjectID.isValid(object) else {
                throw RepositoryReadError.malformedOutput("for-each-ref")
            }

            references[String(decoding: fields[0], as: UTF8.self)] = object
        }

        return references
    }
}

// MARK: - Recovery

extension RemoteConnection {
    /// 重连后的核对由 Git 定位元数据，只检查锁与进行中操作的存在性。
    func reconcile() async throws -> RemoteRecoverySnapshot {
        let rawStatus = try await runWrapped(
            ["status", "--porcelain=v2", "-z", "--branch", "--untracked-files=all"],
            input: nil,
            acceptedExitCodes: [0],
            writing: false,
            onOutput: { _ in }
        )
        let names = ["index.lock", "MERGE_HEAD", "rebase-merge", "rebase-apply"]
        var paths: [String] = []

        for name in names {
            let result = try await runWrapped(
                ["rev-parse", "--path-format=absolute", "--git-path", name],
                input: nil,
                acceptedExitCodes: [0],
                writing: false,
                onOutput: { _ in }
            )
            paths.append(String(decoding: result.standardOutput.dropLast(), as: UTF8.self))
        }

        // 获取与推送中断时，远端跟踪分支是否已被改动要另行核对
        let references = try await runWrapped(
            ["for-each-ref", "--format=%(refname)%00%(objectname)", "refs/remotes"],
            input: nil,
            acceptedExitCodes: [0],
            writing: false,
            onOutput: { _ in }
        )

        let flags = try await inspectFlags(paths)
        let snapshot = RemoteRecoverySnapshot(
            status: try WorkingCopyStatus(porcelainV2: rawStatus.standardOutput),
            indexLocked: flags[0],
            merging: flags[1],
            rebasing: flags[2] || flags[3],
            checkedAt: Date(),
            remoteReferences: try RemoteRecoverySnapshot.parseReferences(references.standardOutput)
        )
        requiresReconciliation = false
        return snapshot
    }
}
