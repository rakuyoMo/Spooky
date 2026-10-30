import Foundation

// MARK: - BranchPublication

/// 发布分支之前记下的内容，撤销发布时据此在远端删掉分支，并把本地分支的配置段换回发布前。
public struct BranchPublication: Sendable, Equatable {
    /// 本地分支的短名。
    let branch: String

    /// 远端名。
    let remote: String

    /// 远端上的分支短名。
    let destination: String

    /// 发布的提交；撤销时远端分支必须仍指向它。
    let commit: String

    /// 发布时让本地分支跟踪推上去的远端分支。
    let setsUpstream: Bool

    /// 发布前本地分支的配置段，按配置文件中的顺序。
    let branchSettings: [BranchSetting]

    /// 分支段是否仍跟踪发布的远端分支。
    func isTracked(by section: [BranchSetting]) -> Bool {
        let prefix = "branch." + branch + "."

        return section.contains(BranchSetting(branch: branch, key: prefix + "remote", value: remote))
            && section.contains(BranchSetting(branch: branch, key: prefix + "merge", value: "refs/heads/" + destination))
    }

    /// 分支段里跟踪设置以外的项：发布只改 `remote` 与 `merge` 两项。
    func otherSettings(in section: [BranchSetting]) -> [BranchSetting] {
        let upstream = ["branch." + branch + ".remote", "branch." + branch + ".merge"]
        return section.filter { !upstream.contains($0.key) }
    }
}

// MARK: - Undo

extension RepositorySync {
    /// 发布分支之前读出撤销要用的内容。
    ///
    /// 远端已有这个分支时为 nil：这时推送是更新已有的分支，撤销不能删掉它。
    /// 对话框只拒绝本机知道的同名远端分支，这里再连接远端确认一次，本机的记录可能已经过期。
    ///
    /// - Parameters:
    ///   - branch: 本地分支的短名。
    ///   - remote: 远端名。
    ///   - destination: 远端上的分支短名。
    ///   - setsUpstream: 发布后是否让本地分支跟踪推上去的远端分支。
    public func publication(
        of branch: String,
        to remote: String,
        as destination: String,
        setsUpstream: Bool
    ) async throws -> BranchPublication? {
        let references = RepositoryReferences(runner: runner)
        try await references.validate(name: branch)
        try await references.validate(name: destination)

        // 远端名先核对是登记过的远端，不让 ls-remote 把它当成地址或路径
        guard try await !RepositoryRemotes(runner: runner).settings(of: remote).isEmpty else {
            throw RepositorySyncError.missingRemote
        }

        guard try await !references.remoteContains("refs/heads/" + destination, on: remote) else {
            return nil
        }

        return BranchPublication(
            branch: branch,
            remote: remote,
            destination: destination,
            commit: try await references.resolve("refs/heads/" + branch),
            setsUpstream: setsUpstream,
            branchSettings: try await RepositoryUndo(runner: runner).branchSettings().filter { $0.branch == branch }
        )
    }

    /// 撤销发布分支：在远端删掉它，远端分支必须仍指向发布的提交，被别人推进过时推送被拒绝，原样报错；
    /// 发布时建立了跟踪、本地分支现在仍跟踪它时，再把配置段换回发布前。
    ///
    /// 前提是这个远端还在，且要换回的配置段除跟踪设置外没有改动；不符时抛出 ``RepositoryUndoError/repositoryChanged``，不连接远端。
    ///
    /// - Parameter publication: 由 ``publication(of:to:as:setsUpstream:)`` 读出的内容。
    public func undoPublish(
        _ publication: BranchPublication,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            let remote = publication.remote

            guard try await !RepositoryRemotes(runner: runner).settings(of: remote).isEmpty else {
                throw RepositoryUndoError.repositoryChanged
            }

            let undo = RepositoryUndo(runner: runner)
            let section = try await undo.branchSettings().filter { $0.branch == publication.branch }

            // 跟踪已被改到别处时不动配置段；仍跟踪它时，段里的其它项要与发布前相同才能整段换回
            let restoresSection = publication.setsUpstream && publication.isTracked(by: section)

            guard
                !restoresSection
                || publication.otherSettings(in: section) == publication.otherSettings(in: publication.branchSettings)
            else {
                throw RepositoryUndoError.repositoryChanged
            }

            let reference = "refs/heads/" + publication.destination

            _ = try await runner.execute(
                RepositoryReferences.pushCommand(remote: remote)
                    + ["--force-with-lease=" + reference + ":" + publication.commit, "--", remote, ":" + reference],
                onOutput: onOutput
            )

            if restoresSection {
                try await undo.restoreBranchSettings(from: section, to: publication.branchSettings)
            }
        }
    }
}
