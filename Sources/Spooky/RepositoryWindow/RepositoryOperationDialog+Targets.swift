import SpookyKit

// MARK: - Push Destination

extension RepositoryOperationDialog {
    /// 推送 HEAD 分支时用一个 Destination 选择目标；入口指定了 HEAD 以外的本地分支时是 Push Branch，
    /// 保持本地分支、远端与远端分支名三行。
    ///
    /// - Parameters:
    ///   - request: 打开对话框的请求。
    ///   - session: 对话框所属的窗口会话。
    static func usesDestination(_ request: RepositoryActionRequest, in session: RepositorySession) -> Bool {
        let head = session.status?.branch.head

        return request.kind == .push && (request.localBranch ?? head) == head
    }

    /// Destination 的候选：已配置远端上的远端跟踪分支，顺序沿用分支列表；分支列表已不含远端 HEAD 这类符号引用。
    ///
    /// - Parameter session: 对话框所属的窗口会话。
    static func pushDestinations(in session: RepositorySession) -> [RepositoryReference] {
        guard let snapshot = session.history.snapshot else {
            return []
        }

        return session.history.branches.filter { $0.isRemote && snapshot.remote(for: $0) != nil }
    }

    /// Destination 的预选：入口指定的远端分支，否则是 HEAD 的上游，HEAD 没有上游时是第一个在所属远端上与 HEAD 同名的远端分支，
    /// 最后是第一个候选；每一级都要在候选里。HEAD 有上游、但上游已不在候选里时直接取第一个候选。
    ///
    /// - Parameters:
    ///   - preselection: 入口指定的远端分支的完整引用名，如把本地分支拖到远端分支上。
    ///   - session: 对话框所属的窗口会话。
    /// - Returns: 远端分支的完整引用名；没有候选时为空字符串。
    static func destinationPreselection(preselection: String?, in session: RepositorySession) -> String {
        let candidates = pushDestinations(in: session)
        let snapshot = session.history.snapshot
        let head = session.headBranch

        // HEAD 没有上游时，找所属远端上与 HEAD 同名的远端分支
        let sameName: RepositoryReference? = head.flatMap { head in
            guard head.upstream == nil else {
                return nil
            }

            return candidates.first { candidate in
                guard let remote = snapshot?.remote(for: candidate) else {
                    return false
                }

                return candidate.id == "refs/remotes/\(remote.name)/\(head.name)"
            }
        }

        return candidates.first { $0.id == preselection }?.id
            ?? candidates.first { $0.id == head?.upstream }?.id
            ?? sameName?.id
            ?? candidates.first?.id
            ?? ""
    }

    /// Destination 所选的远端分支对应的推送目标：所属远端、远端上的分支名，以及强推的期望值，即这个远端跟踪分支指向的提交。
    ///
    /// - Parameters:
    ///   - reference: 所选远端分支的完整引用名。
    ///   - session: 对话框所属的窗口会话。
    /// - Returns: 所选的远端分支已不在候选里时为 nil。
    static func destinationTarget(
        _ reference: String,
        in session: RepositorySession
    ) -> (remote: String, branch: String, lease: String)? {
        guard
            let selected = pushDestinations(in: session).first(where: { $0.id == reference }),
            let remote = session.history.snapshot?.remote(for: selected)
        else {
            return nil
        }

        let branch = String(selected.id.dropFirst(("refs/remotes/" + remote.name + "/").count))

        return (remote.name, branch, selected.objectID)
    }
}

// MARK: - Empty State

extension RepositoryOperationDialog {
    /// 没有可用目标时错误区的说明，随引用快照更新，对话框打开后目标被移除时同样适用；有目标时为 nil。
    ///
    /// 获取、拉取与跟踪说明尚未配置远端，有远端却没有远端分支时拉取与跟踪说明还没有远端分支；
    /// 推送说明没有推送的远端，Push HEAD 有远端却没有远端分支时同样说明还没有远端分支；
    /// 发布分别说明没有可发布到的远端与没有本地分支；合并说明没有可合并的引用。
    ///
    /// - Parameters:
    ///   - request: 打开对话框的请求。
    ///   - session: 对话框所属的窗口会话。
    static func emptyState(for request: RepositoryActionRequest, in session: RepositorySession) -> String? {
        let noRemotes = session.history.snapshot?.remotes.isEmpty != false
        let branches = session.history.branches

        switch request.kind {
        case .create:
            return nil

        case .fetch:
            return noRemotes ? AppLocalization.text("sync.noRemotes") : nil

        case .pull, .track:
            if noRemotes {
                return AppLocalization.text("sync.noRemotes")
            }

            return branches.contains(where: \.isRemote) ? nil : AppLocalization.text("sync.noRemoteBranches")

        case .push:
            if noRemotes {
                return AppLocalization.text("sync.push.empty")
            }

            // Push Branch 可以推到远端上还没有的分支，只有 Push HEAD 要从已有的远端分支里选
            guard usesDestination(request, in: session), pushDestinations(in: session).isEmpty else {
                return nil
            }

            return AppLocalization.text("sync.noRemoteBranches")

        case .publish:
            if noRemotes {
                return AppLocalization.text("sync.publish.noRemotes")
            }

            return branches.contains(where: \.isLocal) ? nil : AppLocalization.text("sync.publish.noBranches")

        case .merge:
            guard sourceCandidates(for: .merge, in: session).isEmpty else {
                return nil
            }

            return AppLocalization.text("sync.merge.empty")
        }
    }
}
