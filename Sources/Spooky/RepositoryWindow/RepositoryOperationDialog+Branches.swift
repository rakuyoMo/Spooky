import SpookyKit
import SwiftUI

// MARK: - Branch Names

extension RepositoryOperationDialog {
    /// 名称框输入时的规范化：新建本地分支按分支规则，推送与发布的远端分支名按通用规则，跟踪远端分支保持原样。
    ///
    /// - Parameters:
    ///   - input: 名称框里的文字。
    ///   - kind: 对话框的动作。
    ///   - cleaning: 设置里是否开启输入时规范化。
    static func normalizedName(
        _ input: String,
        for kind: RepositoryActionRequest.Kind,
        cleaning: Bool
    ) -> String {
        guard cleaning else {
            return input
        }

        switch kind {
        case .create:
            return RepositoryReferences.normalizedBranchName(input)

        case .push, .publish:
            return RepositoryReferences.normalizedName(input)

        case .track, .fetch, .pull, .merge:
            return input
        }
    }

    /// 名称的校验结果与错误区的说明：空名称不可提交、不显示说明；不合法时写出原因；
    /// 新建与跟踪不能与本地分支重名，发布不能与目标远端上的分支重名。
    ///
    /// - Parameters:
    ///   - name: 名称框里的名称。
    ///   - kind: 对话框的动作。
    ///   - remote: 推送与发布的目标远端。
    ///   - session: 对话框所属的窗口会话。
    /// - Returns: 名称能否提交，以及错误区的说明；能提交时说明为空。
    static func nameValidation(
        _ name: String,
        for kind: RepositoryActionRequest.Kind,
        remote: String,
        in session: RepositorySession
    ) async -> (isValid: Bool, error: String) {
        guard !name.isEmpty, let runner = session.runner else {
            return (false, "")
        }

        do {
            try await RepositoryReferences(runner: runner).validate(name: name)
        } catch {
            return (false, RepositoryDialogRows.validationMessage(error, in: session))
        }

        if let conflict = nameConflict(name, for: kind, remote: remote, in: session) {
            return (false, conflict)
        }

        return (true, "")
    }
}

// MARK: - Preselection

extension RepositoryOperationDialog {
    /// 跟踪远端分支的预选：入口传入的远端分支在候选里时用它，否则取 HEAD 的上游（是远端分支时），再否则取第一个远端分支。
    ///
    /// - Returns: 远端分支的完整引用名；没有远端分支时为空字符串。
    static func trackSource(preselection: String?, in session: RepositorySession) -> String {
        let remotes = session.history.branches.filter(\.isRemote)
        let upstream = session.headBranch?.upstream

        return remotes.first { $0.id == preselection }?.id
            ?? remotes.first { $0.id == upstream }?.id
            ?? remotes.first?.id
            ?? ""
    }

    /// 拉取与合并的来源候选：合并依次是本地分支（含 HEAD 分支）、远端分支与标签，拉取只有远端分支；组内按公共顺序排列。
    ///
    /// - Parameters:
    ///   - kind: 拉取或合并。
    ///   - session: 对话框所属的窗口会话。
    static func sourceCandidates(
        for kind: RepositoryActionRequest.Kind,
        in session: RepositorySession
    ) -> [RepositoryReference] {
        let references = kind == .merge ? session.revisionReferences : session.history.branches.filter(\.isRemote)

        return ReferenceOrder.sorted(references, in: session.history.snapshot)
    }

    /// 拉取与合并的预选：入口指定的引用，否则是 HEAD 的上游（在候选里时），再否则是第一个不是 HEAD 分支的候选。
    ///
    /// - Parameters:
    ///   - kind: 拉取或合并。
    ///   - preselection: 入口指定的完整引用名。
    ///   - session: 对话框所属的窗口会话。
    /// - Returns: 完整引用名；没有可选的候选时为空字符串。
    static func sourcePreselection(
        for kind: RepositoryActionRequest.Kind,
        preselection: String?,
        in session: RepositorySession
    ) -> String {
        let candidates = sourceCandidates(for: kind, in: session)
        let head = session.headBranch

        return preselection
            ?? candidates.first { $0.id == head?.upstream }?.id
            ?? candidates.first { $0.id != head?.id }?.id
            ?? ""
    }
}

// MARK: - Private

extension RepositoryOperationDialog {
    /// 与已有分支重名时的说明，本地与远端分开写；没有重名时为 nil。
    private static func nameConflict(
        _ name: String,
        for kind: RepositoryActionRequest.Kind,
        remote: String,
        in session: RepositorySession
    ) -> String? {
        let branches = session.history.branches

        switch kind {
        case .create, .track:
            guard branches.contains(where: { $0.id == "refs/heads/" + name }) else {
                return nil
            }

            return AppLocalization.text("branch.exists", name)

        case .publish:
            guard branches.contains(where: { $0.id == "refs/remotes/" + remote + "/" + name }) else {
                return nil
            }

            return AppLocalization.text("branch.remoteExists", name, remote)

        case .fetch, .pull, .merge, .push:
            return nil
        }
    }
}
