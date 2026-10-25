import AppKit
import SpookyKit

// MARK: - Quick Actions

extension RepositoryWindowController {
    /// File › Quick Actions… 与工具栏的入口：只在窗口显示仓库时可用。
    @objc
    func showQuickActions() {
        guard !showsManager, session.repository != nil else {
            return
        }

        QuickActionWindowController.shared.show(for: self)
    }

    /// 执行快捷操作里选中的动作；每个动作都走菜单、右键菜单或侧边栏的同一个入口。
    ///
    /// 面板关闭后仓库窗口回到前台，对话框与询问以它的 sheet 呈现。执行前按菜单规则再核对一次，面板打开期间仓库状态可能已经变化。
    func performQuickAction(_ action: QuickAction, on object: QuickActionObject) {
        window?.makeKeyAndOrderFront(nil)

        guard QuickActionCatalog(session: session).isAvailable(action, for: object) else {
            NSSound.beep()
            return
        }

        switch object {
        case .navigation(let destination): perform(action, navigation: destination)
        case .branch(let reference), .remoteBranch(let reference): perform(action, branch: reference)
        case .tag(let reference): perform(action, tag: reference)
        case .commit(let commit, _): perform(action, commit: commit)
        case .stash(let stash): action == .applyStash ? session.requestApplyStash(stash) : session.deleteStashes([stash])
        case .file(let path): perform(action, file: path)
        case .submodule(let submodule): openLinkedRepository(at: submodule.path, inNewWindow: false)
        case .worktree(let worktree): perform(action, worktree: worktree)
        case .remote(let name): perform(action, remote: name)
        case .userProfile(let profile): perform(action, profile: profile)
        case .appearance(let appearance): appearance.select()
        case .theme(let id, _): ThemeStore.shared.select(id, dark: Self.isDarkAppearance)
        }
    }
}

// MARK: - Objects

extension RepositoryWindowController {
    /// App 当前的有效外观是否为深色；主题按它写进浅色或深色外观的选择。
    private static var isDarkAppearance: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    /// 导航：切换主视图，工作区另有 Finder、终端、复制路径与快照。
    private func perform(_ action: QuickAction, navigation destination: QuickActionDestination) {
        switch (action, destination) {
        case (.show, .workingCopy): showWorkingCopy()
        case (.show, .history): showHistory()
        case (.show, .stashes): showStashes()
        case (.show, .branchesReview): showBranchesReview()
        case (.show, .reflog): showReflog()
        case (.revealInFinder, _): revealInFinder()
        case (.openInTerminal, _): openInTerminal()
        case (.copyPath, _): copyPath()
        case (.createSnapshot, _): session.requestSaveStash(snapshot: true)
        default: break
        }
    }

    /// 本地分支与远端分支：与侧边栏分支右键菜单、父分支菜单和分支整理的同名项相同。
    private func perform(_ action: QuickAction, branch: RepositoryReference) {
        switch action {
        case .showReferenceHistory: session.showHistory(of: branch)
        case .revealInHistory: session.revealInHistory(branch.objectID)
        case .checkout: session.checkoutBranch(branch, request: presentRepositoryAction)
        case .track: presentRepositoryAction(RepositoryActionRequest(kind: .track, reference: branch.id))
        case .mergeIntoHead: presentRepositoryAction(RepositoryActionRequest(kind: .merge, reference: branch.id))
        case .rebaseHead: session.requestSyncDialog(.rebase, preselecting: branch.id)
        case .mergeParent, .rebaseOnParent: performParent(action, of: branch)
        case .createBranch: presentRepositoryAction(RepositoryActionRequest(kind: .create, reference: branch.id))
        case .publish: presentRepositoryAction(RepositoryActionRequest(kind: .publish, localBranch: branch.name))
        case .push: presentRepositoryAction(RepositoryActionRequest(kind: .push, localBranch: branch.name))
        case .fastForward: session.fastForward(branch)
        case .delete:
            session.requestReference(branch.isRemote ? .deleteRemoteBranches([branch]) : .deleteBranches([branch]))
        case .rename: session.requestReference(.renameBranch(branch))
        case .copyName: Self.copy(branch.name)
        default: performFlag(action, on: branch)
        }
    }

    /// HEAD 分支的父分支：并入 HEAD，或把 HEAD 变基到它上面。
    private func performParent(_ action: QuickAction, of branch: RepositoryReference) {
        guard let parent = session.parentBranch(of: branch) else {
            return
        }

        if action == .mergeParent {
            presentRepositoryAction(RepositoryActionRequest(kind: .merge, reference: parent.id))
        } else {
            session.requestSyncDialog(.rebase, preselecting: parent.id)
        }
    }

    /// 本地分支的置顶、父分支、更新、归档与自动归档标记。
    private func performFlag(_ action: QuickAction, on branch: RepositoryReference) {
        switch action {
        case .pin, .unpin: session.setPinned(action == .pin, branches: [branch])
        case .removeParent: session.removeParent(of: branch)
        case .setParent: session.requestReference(.setParent(branch))
        case .updateBranch: session.updateBranch(branch, rebase: false)
        case .archive, .unarchive: session.setArchived(action == .archive, branches: [branch])
        case .skipAutoArchive, .includeInAutoArchive:
            session.setSkipsAutoArchive(action == .skipAutoArchive, branches: [branch])
        default: break
        }
    }

    /// 标签：与侧边栏标签右键菜单的同名项相同。
    private func perform(_ action: QuickAction, tag: RepositoryReference) {
        switch action {
        case .showReferenceHistory: session.showHistory(of: tag)
        case .revealInHistory: session.revealInHistory(tag.objectID)
        case .checkout: session.requestCheckout(tag.id)
        case .delete: session.requestReference(.deleteTags([tag.name]))
        case .createBranch: presentRepositoryAction(RepositoryActionRequest(kind: .create, reference: tag.id))
        case .copyName: Self.copy(tag.name)
        default: break
        }
    }

    /// 提交：与历史列表右键菜单的同名项相同。
    private func perform(_ action: QuickAction, commit: HistoryCommit) {
        switch action {
        case .showCommit: session.showCommit(commit)
        case .copyHash: Self.copy(commit.id)
        case .revealInHistory: session.revealInHistory(commit.id)
        case .createTag: session.requestReference(.createTag(revision: commit.id))
        case .createBranch: presentRepositoryAction(RepositoryActionRequest(kind: .create, reference: commit.id))
        case .editCommit: session.requestRewrite(.edit(commit.id))
        case .editMessage: session.requestReword(commit.id)
        default: break
        }
    }

    /// HEAD 树中的文件：原文、文件历史与逐行追溯跟随 HEAD；Finder 只用于本机仓库，复制的路径带服务器的主机前缀。
    private func perform(_ action: QuickAction, file path: String) {
        switch action {
        case .showFile: session.showFile(path, at: nil, mode: .raw)

        case .showFileHistory: session.showFileHistory(path)

        case .showBlame: session.showFile(path, at: nil, mode: .blame)

        case .revealInFinder:
            if let root = session.repository?.localURL {
                NSWorkspace.shared.activateFileViewerSelecting([root.appending(path: path)])
            }

        case .copyPath:
            if let repository = session.repository {
                Self.copy(repository.displayPath + "/" + path)
            }

        default: break
        }
    }

    /// 工作树：在当前窗口或新窗口打开，在 Finder 或终端中打开；服务器上的工作树复制带主机前缀的路径。
    private func perform(_ action: QuickAction, worktree: WorktreeEntry) {
        switch action {
        case .openWorktree, .openWorktreeInNewWindow:
            openLinkedRepository(at: worktree.path, inNewWindow: action == .openWorktreeInNewWindow)

        case .revealInFinder:
            NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: worktree.path)])

        case .openInTerminal:
            if let location = linkedLocation(worktree.path) {
                openLocationInTerminal(location)
            }

        case .copyPath:
            if let location = linkedLocation(worktree.path) {
                Self.copy(location.displayPath)
            }

        default: break
        }
    }

    /// 远端：与侧边栏远端右键菜单的同名项相同。
    private func perform(_ action: QuickAction, remote: String) {
        switch action {
        case .showRemoteSettings: session.showRemote(remote)
        case .fetch: presentRepositoryAction(RepositoryActionRequest(kind: .fetch, remote: remote))
        case .editConnection: session.requestReference(.editURL(remote: remote, push: false))
        default: break
        }
    }

    /// 身份档案：写进当前仓库的提交身份，或写进全局 Git 配置。
    private func perform(_ action: QuickAction, profile: UserProfile) {
        if action == .setCommitter {
            session.applyProfile(profile)
        } else {
            session.applyGlobalProfile(profile)
        }
    }
}

// MARK: - Helpers

extension RepositoryWindowController {
    /// 把文字放进剪贴板。
    private static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// 子模块与工作树在仓库所在机器上的位置：相对路径接在仓库根目录后，服务器仓库沿用同一个主机。
    private func linkedLocation(_ path: String) -> RepositoryLocation? {
        guard let repository = session.repository else {
            return nil
        }

        let absolute = path.hasPrefix("/") ? path : repository.path + "/" + path

        switch repository {
        case .local: return .local(path: absolute)
        case .remote(let host, _): return .remote(host: host, path: absolute)
        }
    }

    /// 打开子模块或工作树，验证与窗口复用规则和打开其它仓库相同。
    private func openLinkedRepository(at path: String, inNewWindow: Bool) {
        guard let location = linkedLocation(path) else {
            return
        }

        coordinator?.openRepository(at: location, from: self, inNewWindow: inNewWindow)
    }

}
