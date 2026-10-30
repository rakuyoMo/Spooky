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
    /// 发布分支：撤销时在远端删掉它，远端分支被别人推进过时拒绝；发布时建立的跟踪随之换回发布前。
    /// 推送没有新建远端分支时不记：已是最新不碰撤销记录，快进了远端已有的分支按不能撤销处理。
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

            return UndoInverse(target: .push(remote), pushedReference: (remote, "refs/heads/" + destination)) {
                try await RepositorySync(runner: $0).undoPublish(publication, onOutput: $1)
            }
        }
    }

    /// 发布标签：撤销时在远端删掉它，远端标签被别人改过时拒绝。远端原来就有同名标签、推送已是最新时不记。
    static func publishingTag(_ name: String, to remote: String) -> Self {
        .inverse { runner in
            let object = try await RepositoryTags(runner: runner).publicationLease(of: name)

            return UndoInverse(target: .push(remote), pushedReference: (remote, "refs/tags/" + name)) {
                try await RepositoryTags(runner: $0).undoPublish(name, on: remote, object: object, onOutput: $1)
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

// MARK: - Submodules

extension UndoRecording {
    /// 添加子模块：撤销时删掉它、`.gitmodules` 换回添加之前，子模块的 Git 目录留在仓库里；重做时复用这个 Git 目录重新添加，不再克隆。
    ///
    /// - Parameters:
    ///   - url: 子模块仓库的地址。
    ///   - path: 工作区里的相对路径。
    static func addingSubmodule(url: String, path: String) -> Self {
        .inverse { runner in
            let addition = try await RepositorySubmodules(runner: runner).additionRecord(at: path)

            return UndoInverse { runner, _ in
                try await RepositorySubmodules(runner: runner).undoAdd(addition)
            } redo: { runner, output in
                try await RepositorySubmodules(runner: runner)
                    .add(url: url, path: path, reusesGitDirectory: true, onOutput: output)
            }
        }
    }

    /// 删除子模块：删除前记下指针、`.gitmodules`、本地配置里的段与要删掉的工作区，撤销时恢复；
    /// 要删掉的工作区里有找不回的内容时不能撤销。
    static func deletingSubmodule(_ submodule: Submodule, keepsWorkingTree: Bool) -> Self {
        .inverse { runner in
            let removal = try await RepositorySubmodules(runner: runner)
                .removalRecord(of: submodule, keepsWorkingTree: keepsWorkingTree)

            return UndoInverse { runner, _ in try await RepositorySubmodules(runner: runner).undoDelete(removal) }
        }
    }

    /// 移动子模块：撤销时移回原路径，同时改了名称的再改回原名。
    static func movingSubmodule(_ submodule: Submodule, to path: String, renaming: Bool) -> Self {
        .inverse { _ in
            UndoInverse { runner, _ in
                try await RepositorySubmodules(runner: runner).undoMove(submodule, to: path, renamesSubmodule: renaming)
            }
        }
    }

    /// 修改子模块名称：撤销时改回原名。
    static func renamingSubmodule(_ submodule: Submodule, to name: String) -> Self {
        .inverse { _ in
            UndoInverse { runner, _ in try await RepositorySubmodules(runner: runner).undoRename(submodule, to: name) }
        }
    }

    /// 修改子模块的地址：写进 `.gitmodules` 的改动留在工作区，按快照撤销；写进本地配置的撤销时写回原值，原来没有的删掉。
    static func changingSubmoduleURL(
        _ url: String,
        of submodule: Submodule,
        in scope: SubmoduleConfigurationScope
    ) -> Self {
        guard scope == .local else {
            return .reversible
        }

        return .inverse { runner in
            try await RepositorySubmodules(runner: runner).localURLChange(of: submodule, to: url).map(Self.settingInverse)
        }
    }

    /// 修改或删除子模块的选项：写进 `.gitmodules` 的改动留在工作区，按快照撤销；写进本地配置的撤销时写回原值，原来没有的删掉。
    static func changingSubmoduleOption(
        _ option: SubmoduleOption,
        to value: String?,
        of submodule: Submodule,
        in scope: SubmoduleConfigurationScope
    ) -> Self {
        guard scope == .local else {
            return .reversible
        }

        return .inverse { runner in
            try await RepositorySubmodules(runner: runner)
                .localOptionChange(option, of: submodule, to: value)
                .map(Self.settingInverse)
        }
    }

    /// 写回本地配置里子模块一项设置的反向操作。
    private static func settingInverse(_ change: SubmoduleSettingChange) -> UndoInverse {
        UndoInverse { runner, _ in try await RepositorySubmodules(runner: runner).undoSettingChange(change) }
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
