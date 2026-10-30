import Foundation
import SpookyKit

// MARK: - Remotes

extension UndoRecording {
    /// 添加远端：撤销时删掉它；重做时再添加一次，连通检查也再做一次。
    static func addingRemote(_ name: String) -> Self {
        .inverse { _ in
            UndoInverse { try await RepositoryRemotes(runner: $0).undoAdd(name) }
        }
    }

    /// 把远端 `name` 改名为 `newName`：撤销时改回原名，远端跟踪分支与跟踪设置随之改回。
    static func renamingRemote(_ name: String, to newName: String) -> Self {
        .inverse { _ in
            UndoInverse { try await RepositoryRemotes(runner: $0).undoRename(name, to: newName) }
        }
    }

    /// 删除远端：删除前记下配置段、远端跟踪分支与跟踪或推送到它们的分支段，撤销时恢复。
    static func removingRemotes(_ names: [String]) -> Self {
        .inverse { runner in
            let record = try await RepositoryRemotes(runner: runner).removalRecord(of: names)
            return UndoInverse { try await RepositoryRemotes(runner: $0).undoRemove(record) }
        }
    }

    /// 修改远端的地址、refspec 或 “获取全部”：修改前记下这个远端的配置段，撤销时整段换回。
    static func changingRemote(_ name: String) -> Self {
        .inverse { runner in
            let settings = try await RepositoryRemotes(runner: runner).settings(of: name)
            return UndoInverse { try await RepositoryRemotes(runner: $0).restoreSettings(settings, of: name) }
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

            return UndoInverse { try await WorkingCopyOperations(runner: $0).setAssumeUnchanged(changed, !assumeUnchanged) }
        }
    }
}

// MARK: - LFS

extension UndoRecording {
    /// 在仓库本地启用 Git LFS：撤销时停用；本地配置里本来就登记了过滤器时只是更新钩子，不记。
    static var enablingLFS: Self {
        .inverse { runner in
            guard try await !RepositoryLFS(runner: runner).isInstalledLocally() else { return nil }

            return UndoInverse { try await RepositoryLFS(runner: $0).undoInstall() }
        }
    }
}
