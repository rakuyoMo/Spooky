import Foundation
import SpookyKit

// MARK: - Remotes

extension UndoRecording {
    /// 添加远端：撤销时删掉它；重做时再添加一次，连通检查也再做一次。
    static func addingRemote(_ name: String) -> Self {
        .inverse { _ in
            UndoInverse { runner, _ in try await RepositoryRemotes(runner: runner).undoAdd(name) }
        }
    }

    /// 把远端 `name` 改名为 `newName`：撤销时改回原名，远端跟踪分支与跟踪设置随之改回。
    static func renamingRemote(_ name: String, to newName: String) -> Self {
        .inverse { _ in
            UndoInverse { runner, _ in try await RepositoryRemotes(runner: runner).undoRename(name, to: newName) }
        }
    }

    /// 删除远端：删除前记下配置段、远端跟踪分支与跟踪或推送到它们的分支段，撤销时恢复。
    static func removingRemotes(_ names: [String]) -> Self {
        .inverse { runner in
            let record = try await RepositoryRemotes(runner: runner).removalRecord(of: names)
            return UndoInverse { runner, _ in try await RepositoryRemotes(runner: runner).undoRemove(record) }
        }
    }

    /// 修改远端的地址、refspec 或 “获取全部”：修改前记下这个远端的配置段，撤销时整段换回。
    static func changingRemote(_ name: String) -> Self {
        .inverse { runner in
            let settings = try await RepositoryRemotes(runner: runner).settings(of: name)
            return UndoInverse { runner, _ in
                try await RepositoryRemotes(runner: runner).restoreSettings(settings, of: name)
            }
        }
    }
}

// MARK: - Publishing

extension UndoRecording {
    /// 发布分支：撤销时在远端删掉它，远端分支被别人推进过时拒绝；发布时建立的跟踪随之换回发布前。远端原来就有这个分支时不记。
    ///
    /// - Parameters:
    ///   - branch: 本地分支的短名。
    ///   - remote: 远端名。
    ///   - destination: 远端上的分支短名。
    ///   - setsUpstream: 发布后是否让本地分支跟踪推上去的远端分支。
    static func publishingBranch(
        _ branch: String,
        to remote: String,
        as destination: String,
        setsUpstream: Bool
    ) -> Self {
        .inverse { runner in
            let publication = try await RepositorySync(runner: runner)
                .publication(of: branch, to: remote, as: destination, setsUpstream: setsUpstream)

            return publication.map { publication in
                UndoInverse(target: .push(remote)) {
                    try await RepositorySync(runner: $0).undoPublish(publication, onOutput: $1)
                }
            }
        }
    }

    /// 发布标签：撤销时在远端删掉它，远端标签被别人改过时拒绝。远端原来就有同名标签时不记。
    static func publishingTag(_ name: String, to remote: String) -> Self {
        .inverse { runner in
            let object = try await RepositoryTags(runner: runner).publicationLease(of: name, on: remote)

            return object.map { object in
                UndoInverse(target: .push(remote)) {
                    try await RepositoryTags(runner: $0).undoPublish(name, on: remote, object: object, onOutput: $1)
                }
            }
        }
    }

    /// 把远端分支 `name` 改名为 `newName`：撤销时再改回原名。
    static func renamingRemoteBranch(_ name: String, on remote: String, to newName: String) -> Self {
        .inverse { _ in
            UndoInverse(target: .push(remote)) {
                try await RepositoryReferences(runner: $0)
                    .undoRenameRemoteBranch(name, on: remote, to: newName, onOutput: $1)
            }
        }
    }
}

// MARK: - Working Copy

extension UndoRecording {
    /// 设置或清除 assume-unchanged：撤销时只把这次改了标记的路径改回去；标记本来都是目标状态时不记。
    static func settingAssumeUnchanged(_ paths: [String], _ assumeUnchanged: Bool) -> Self {
        .inverse { runner in
            let marked = try await WorkingCopyOperations(runner: runner).assumedUnchanged(paths)
            let changed = paths.filter { marked.contains($0) != assumeUnchanged }

            guard !changed.isEmpty else { return nil }

            return UndoInverse { runner, _ in
                try await WorkingCopyOperations(runner: runner).setAssumeUnchanged(changed, !assumeUnchanged)
            }
        }
    }
}

// MARK: - LFS

extension UndoRecording {
    /// 在仓库本地启用 Git LFS：撤销时停用；本地配置里本来就登记了过滤器时只是更新钩子，不记。
    static var enablingLFS: Self {
        .inverse { runner in
            guard try await !RepositoryLFS(runner: runner).isInstalledLocally() else { return nil }

            return UndoInverse { runner, _ in try await RepositoryLFS(runner: runner).undoInstall() }
        }
    }
}
