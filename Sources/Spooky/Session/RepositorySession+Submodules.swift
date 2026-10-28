import AppKit
import SpookyKit

// MARK: - SubmodulePreferences

/// 子模块相关的偏好键。
enum SubmodulePreferences {
    /// 操作改动了已初始化子模块的指针后直接更新它们，不再询问；默认关。
    static let alwaysUpdate = "alwaysUpdateSubmodules"

    /// 获取子模块时清理远端已删除的分支。
    static let fetchPrune = "submoduleFetchPrune"

    /// 更新子模块时连同嵌套的子模块一起更新。
    static let updateRecursive = "submoduleUpdateRecursive"

    /// 删除子模块时保留工作区。
    static let deleteKeepsWorkingTree = "submoduleDeleteKeepWorkingTree"

    /// 移动子模块时把名称改成新路径。
    static let moveRenames = "submoduleMoveRename"
}

// MARK: - Availability

extension RepositorySession {
    /// 有可以获取的子模块：配置完整且已检出。
    var canFetchSubmodules: Bool {
        canWrite && submodules.items.contains { $0.isValid && $0.isPopulated }
    }

    /// 有可以更新的子模块：配置完整。
    var canUpdateSubmodules: Bool {
        canWrite && submodules.items.contains(where: \.isValid)
    }

    /// 父仓库的位置；本仓库不是子模块时为 nil。
    var superprojectLocation: RepositoryLocation? {
        guard let path = submodules.superproject, let repository else {
            return nil
        }

        switch repository {
        case .local: return .local(path: path)
        case .remote(let host, _): return .remote(host: host, path: path)
        }
    }

    /// 能否获取这个子模块。
    func canFetch(_ submodule: Submodule) -> Bool {
        canWrite && submodule.isValid && submodule.isPopulated
    }

    /// 能否更新、初始化、移动或改名这个子模块：配置完整即可。
    func canModify(_ submodule: Submodule) -> Bool {
        canWrite && submodule.isValid
    }

    /// 能否同步这个子模块的地址：已初始化。
    func canSynchronize(_ submodule: Submodule) -> Bool {
        canWrite && submodule.isValid && submodule.isInitialized
    }

    /// 能否在这个子模块里检出别的版本：已检出。
    func canCheckoutRevision(in submodule: Submodule) -> Bool {
        canWrite && submodule.isValid && submodule.isPopulated
    }

    /// 子模块在仓库所在机器上的位置；已检出才能当作仓库打开。
    func location(of submodule: Submodule) -> RepositoryLocation? {
        guard submodule.isPopulated, let repository else {
            return nil
        }

        let path = repository.path + "/" + submodule.path

        switch repository {
        case .local: return .local(path: path)
        case .remote(let host, _): return .remote(host: host, path: path)
        }
    }
}

// MARK: - Navigation

extension RepositorySession {
    /// 在主视图显示一个子模块的状态与配置。
    func showSubmodule(_ path: String) {
        submodules.selectedPath = path
        history.showsCommitPage = false
        activeView = .submodule
        onActiveViewChange?()
    }

    /// 在本窗口把已检出的子模块当仓库打开；没有检出时响铃。
    func open(_ submodule: Submodule) {
        guard let location = location(of: submodule), let onOpenRepository else {
            NSSound.beep()
            return
        }

        onOpenRepository(location, .currentWindow)
    }

    /// 交给窗口呈现子模块的对话框或询问。
    func requestSubmodule(_ request: SubmoduleRequest) {
        submodules.onRequest?(request)
    }

    /// 写入失败是子模块删除遇到本地改动或添加遇到已有 Git 目录时，改为询问；返回是否已经接手。
    func offerSubmoduleRecovery(after error: any Error) -> Bool {
        switch error {
        case let offer as SubmoduleDeletionOffer:
            requestSubmodule(.forceDelete(offer))
            return true

        case let offer as SubmoduleAdditionOffer:
            requestSubmodule(.forceAdd(offer))
            return true

        default:
            return false
        }
    }
}

// MARK: - Auto Update

extension RepositorySession {
    /// 写入前后都已初始化、指针变了、检出的提交与新指针不同的子模块。
    nonisolated static func outdatedSubmodules(before: [Submodule], after: [Submodule]) -> [Submodule] {
        let pointers = Dictionary(before.map { ($0.path, $0.pointer) }, uniquingKeysWith: { first, _ in first })

        return after.filter { submodule in
            guard submodule.isInitialized, submodule.state == .updated, let previous = pointers[submodule.path] else {
                return false
            }

            return previous != submodule.pointer
        }
    }

    /// 写操作结束后检查已初始化子模块的指针：被改动、检出的提交随之过时的子模块按设置直接更新，或留待写入结束后询问。
    ///
    /// 检查本身读不到清单时不影响写操作的结果；直接更新失败时与写操作一样报告。
    ///
    /// - Parameters:
    ///   - action: 原来的写操作。
    ///   - tracked: 写入前已初始化的子模块；为空时原样返回写操作。
    func updatingSubmodules(
        after action: @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
        tracked: [Submodule]
    ) -> @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void {
        guard !tracked.isEmpty else {
            return action
        }

        let automatic = UserDefaults.standard.bool(forKey: SubmodulePreferences.alwaysUpdate)

        return { [weak self] runner, output in
            try await action(runner, output)

            let submodules = RepositorySubmodules(runner: runner)

            guard
                let current = try? await submodules.list(),
                case let outdated = Self.outdatedSubmodules(before: tracked, after: current),
                !outdated.isEmpty
            else { return }

            if automatic {
                try await submodules.update(outdated, recursive: false, onOutput: output)
            } else {
                await MainActor.run { self?.submodules.outdated = outdated }
            }
        }
    }

    /// 刚结束的写操作留下了过时的子模块时，询问是否更新它们。
    func offerSubmoduleUpdate() {
        guard let outdated = submodules.outdated else {
            return
        }

        submodules.outdated = nil
        requestSubmodule(.autoUpdate(outdated))
    }
}

// MARK: - Actions

extension RepositorySession {
    /// 添加子模块；父仓库里已有同名 Git 目录且没有选择复用时，改为询问复用还是覆盖。
    ///
    /// - Parameters:
    ///   - url: 子模块仓库的地址。
    ///   - path: 工作区里的相对路径。
    ///   - reusesGitDirectory: 复用已有的 Git 目录。
    ///   - overwrites: 先删掉已有的 Git 目录再重新克隆。
    /// - Returns: 是否已开始执行。
    @discardableResult
    func addSubmodule(url: String, path: String, reusesGitDirectory: Bool = false, overwrites: Bool = false) -> Bool {
        performGit(
            { runner, output in
                let submodules = RepositorySubmodules(runner: runner)

                if overwrites {
                    try await submodules.removeGitDirectory(named: path)
                }

                do {
                    try await submodules.add(url: url, path: path, reusesGitDirectory: reusesGitDirectory, onOutput: output)
                } catch SubmoduleError.gitDirectoryExists {
                    throw SubmoduleAdditionOffer(url: url, path: path)
                }
            },
            title: AppLocalization.text("submodule.add"),
            activityKind: .remote
        )
    }

    /// 依次获取若干子模块的全部远端。
    ///
    /// - Parameters:
    ///   - targets: 已检出的子模块。
    ///   - prunes: 清理远端已删除的分支。
    /// - Returns: 是否已开始执行。
    @discardableResult
    func fetchSubmodules(_ targets: [Submodule], prunes: Bool) -> Bool {
        performGit(
            { runner, output in
                let submodules = RepositorySubmodules(runner: runner)

                for submodule in targets {
                    try await submodules.fetch(submodule, prunes: prunes, onOutput: output)
                }
            },
            title: AppLocalization.text(targets.count == 1 ? "submodule.fetch" : "submodule.fetchAll"),
            activityKind: .remote
        )
    }

    /// 更新子模块：没有初始化的先初始化，再检出指针所指的提交。
    ///
    /// - Parameters:
    ///   - targets: 要更新的子模块；nil 表示全部。
    ///   - recursive: 连同嵌套的子模块一起更新。
    /// - Returns: 是否已开始执行。
    @discardableResult
    func updateSubmodules(_ targets: [Submodule]?, recursive: Bool) -> Bool {
        performGit(
            { runner, output in
                try await RepositorySubmodules(runner: runner).update(targets, recursive: recursive, onOutput: output)
            },
            title: AppLocalization.text(targets?.count == 1 ? "submodule.update" : "submodule.updateAll"),
            activityKind: .remote
        )
    }

    /// 初始化子模块。
    @discardableResult
    func initializeSubmodule(_ submodule: Submodule) -> Bool {
        performGit(
            { runner, _ in try await RepositorySubmodules(runner: runner).initialize([submodule]) },
            title: AppLocalization.text("submodule.initialize")
        )
    }

    /// 按 `.gitmodules` 同步子模块的地址。
    @discardableResult
    func synchronizeSubmodule(_ submodule: Submodule) -> Bool {
        performGit(
            { runner, _ in try await RepositorySubmodules(runner: runner).synchronize([submodule]) },
            title: AppLocalization.text("submodule.synchronize")
        )
    }

    /// 修改子模块在 `.gitmodules` 或本地配置里的地址。
    @discardableResult
    func setSubmoduleURL(_ url: String, for submodule: Submodule, in scope: SubmoduleConfigurationScope) -> Bool {
        performGit(
            { runner, _ in try await RepositorySubmodules(runner: runner).setURL(url, for: submodule, in: scope) },
            title: AppLocalization.text("submodule.editURL")
        )
    }

    /// 修改或删除子模块的一个选项。
    ///
    /// - Parameters:
    ///   - option: 选项。
    ///   - value: 配置值；nil 表示删除，按 Git 的默认值处理。
    ///   - submodule: 子模块。
    ///   - scope: 写进 `.gitmodules` 还是本地配置。
    func setSubmoduleOption(
        _ option: SubmoduleOption,
        to value: String?,
        for submodule: Submodule,
        in scope: SubmoduleConfigurationScope
    ) {
        performGit(
            { runner, _ in
                try await RepositorySubmodules(runner: runner).set(option, to: value, for: submodule, in: scope)
            },
            title: AppLocalization.text("submodule.setting")
        )
    }

    /// 在子模块里检出一个分支或标签；子模块里的改动挡住时不询问储藏，父仓库的储藏管不到子模块。
    func checkoutSubmoduleRevision(_ revision: SubmoduleRevision, in submodule: Submodule) {
        performGit(
            { runner, _ in try await RepositorySubmodules(runner: runner).checkout(revision, in: submodule) },
            title: AppLocalization.text("submodule.checkoutRevision")
        )
    }

    /// 移动子模块，可以同时把名称改成新路径。
    @discardableResult
    func moveSubmodule(_ submodule: Submodule, to path: String, renaming: Bool) -> Bool {
        performGit(
            { runner, _ in
                try await RepositorySubmodules(runner: runner).move(submodule, to: path, renamesSubmodule: renaming)
            },
            title: AppLocalization.text("submodule.move")
        )
    }

    /// 修改子模块名称。
    @discardableResult
    func renameSubmodule(_ submodule: Submodule, to name: String) -> Bool {
        performGit(
            { runner, _ in try await RepositorySubmodules(runner: runner).rename(submodule, to: name) },
            title: AppLocalization.text("submodule.rename")
        )
    }

    /// 删除子模块；没有强制时遇到本地改动，改为询问是否强制删除。
    @discardableResult
    func deleteSubmodule(_ submodule: Submodule, keepsWorkingTree: Bool, force: Bool) -> Bool {
        performGit(
            { runner, _ in
                do {
                    try await RepositorySubmodules(runner: runner)
                        .delete(submodule, keepsWorkingTree: keepsWorkingTree, force: force)
                } catch SubmoduleError.localModifications {
                    throw SubmoduleDeletionOffer(submodule: submodule, keepsWorkingTree: keepsWorkingTree)
                }
            },
            title: AppLocalization.text("submodule.delete")
        )
    }

    /// 修复配置不完整的子模块。
    @discardableResult
    func repairSubmodule(_ submodule: Submodule) -> Bool {
        performGit(
            { runner, output in try await RepositorySubmodules(runner: runner).repair(submodule, onOutput: output) },
            title: AppLocalization.text("submodule.repair")
        )
    }
}
