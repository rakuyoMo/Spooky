import AppKit
import SpookyKit

// MARK: - WorktreePreferences

/// 工作树相关的偏好键。
enum WorktreePreferences {
    /// 新建工作树后在新标签里打开它。
    static let opensAfterCreation = "worktreeOpenAfterCreation"
}

// MARK: - Availability

extension RepositorySession {
    /// 能否移动或删除这个工作树：主工作树不能。
    func canModify(_ worktree: Worktree) -> Bool {
        canWrite && !worktree.isMain && !worktree.isBare
    }

    /// 能否修复这个工作树：只有失效的工作树需要修复。
    func canRepair(_ worktree: Worktree) -> Bool {
        canWrite && !worktree.isValid && !worktree.isBare
    }

    /// 工作树在仓库所在机器上的位置；失效的工作树不能打开，为 nil。
    func location(of worktree: Worktree) -> RepositoryLocation? {
        guard worktree.isValid, let repository else {
            return nil
        }

        switch repository {
        case .local: return .local(path: worktree.path)
        case .remote(let host, _): return .remote(host: host, path: worktree.path)
        }
    }
}

// MARK: - Navigation

extension RepositorySession {
    /// 在主视图显示一个工作树的详情。
    func showWorktree(_ path: String) {
        worktrees.selectedPath = path
        history.showsCommitPage = false
        activeView = .worktree
        onActiveViewChange?()
    }

    /// 打开工作树；失效的工作树响铃。
    func open(_ worktree: Worktree, in target: RepositoryOpenTarget) {
        guard let location = location(of: worktree), let onOpenRepository else {
            NSSound.beep()
            return
        }

        onOpenRepository(location, target)
    }

    /// 交给窗口呈现工作树的对话框。
    func requestWorktree(_ request: WorktreeRequest) {
        worktrees.onRequest?(request)
    }
}

// MARK: - Actions

extension RepositorySession {
    /// 新建工作树，成功后按选项在新标签里打开它。
    ///
    /// - Parameters:
    ///   - path: 新工作树的绝对路径。
    ///   - revision: 检出的分支或版本。
    ///   - detach: 以分离 HEAD 检出。
    ///   - force: 分支已在别的工作树检出时仍然创建。
    ///   - opens: 成功后在新标签里打开。
    /// - Returns: 是否已开始执行。
    @discardableResult
    func addWorktree(at path: String, revision: String, detach: Bool, force: Bool, opens: Bool) -> Bool {
        let host = repository?.host

        return performGit(
            { runner, output in
                try await RepositoryWorktrees(runner: runner)
                    .add(at: path, revision: revision, detach: detach, force: force, onOutput: output)
            },
            title: AppLocalization.text("worktree.add"),
            success: { [weak self] in
                guard opens else { return }
                self?.onOpenRepository?(host.map { .remote(host: $0, path: path) } ?? .local(path: path), .newTab)
            }
        )
    }

    /// 把工作树移到新位置。
    @discardableResult
    func moveWorktree(_ worktree: Worktree, to destination: String) -> Bool {
        performGit(
            { runner, _ in try await RepositoryWorktrees(runner: runner).move(worktree, to: destination) },
            title: AppLocalization.text("worktree.move")
        )
    }

    /// 删除工作树。
    @discardableResult
    func removeWorktree(_ worktree: Worktree, force: Bool) -> Bool {
        performGit(
            { runner, _ in try await RepositoryWorktrees(runner: runner).remove(worktree, force: force) },
            title: AppLocalization.text("worktree.remove")
        )
    }

    /// 按新位置修复手动移走的工作树。
    @discardableResult
    func repairWorktree(at location: String) -> Bool {
        performGit(
            { runner, _ in try await RepositoryWorktrees(runner: runner).repair(at: location) },
            title: AppLocalization.text("worktree.repair")
        )
    }
}
