// MARK: - QuickAction

/// 快捷操作里对象的一个动作；每个动作都接到菜单与右键菜单的同一个入口。
enum QuickAction: Equatable {
    // MARK: 导航与工作区

    /// 在窗口里显示导航对象指向的主视图。
    case show

    /// 在 Finder 中显示工作区、文件或工作树。
    case revealInFinder

    /// 在终端中打开工作区或工作树。
    case openInTerminal

    /// 复制工作区或文件的路径，服务器路径带主机前缀。
    case copyPath

    /// 打开保留工作区的储藏对话框。
    case createSnapshot

    // MARK: 分支、远端分支与标签

    /// 在历史里只看这个引用。
    case showReferenceHistory

    /// 在全部历史里选中引用或提交所指的提交。
    case revealInHistory

    /// 检出分支、远端分支或标签。
    case checkout

    /// 为远端分支新建跟踪分支。
    case track

    /// 把引用并入 HEAD 的合并对话框。
    case mergeIntoHead

    /// 把 HEAD 变基到引用上的对话框。
    case rebaseHead

    /// 把父分支并入 HEAD 分支的合并对话框。
    case mergeParent

    /// 把 HEAD 分支变基到父分支上的对话框。
    case rebaseOnParent

    /// 以引用或提交为起点的新建分支对话框。
    case createBranch

    /// 首次发布本地分支的对话框。
    case publish

    /// 推送本地分支的对话框。
    case push

    /// 把本地分支快进到它的上游。
    case fastForward

    /// 删除分支、远端分支或标签前的确认。
    case delete

    /// 重命名分支或远端分支的对话框。
    case rename

    /// 置顶本地分支。
    case pin

    /// 取消置顶本地分支。
    case unpin

    /// 去掉本地分支的父分支。
    case removeParent

    /// 设置本地分支的父分支的对话框。
    case setParent

    /// 复制分支、远端分支或标签的名称。
    case copyName

    /// 把父分支的新提交合并进本地分支。
    case updateBranch

    /// 归档本地分支。
    case archive

    /// 取消归档本地分支。
    case unarchive

    /// 自动归档时跳过本地分支。
    case skipAutoArchive

    /// 让本地分支重新参与自动归档。
    case includeInAutoArchive

    // MARK: 提交

    /// 打开提交的整页详情。
    case showCommit

    /// 复制提交的完整哈希。
    case copyHash

    /// 以提交为目标的新建标签对话框。
    case createTag

    /// 交互式变基停在这个提交上编辑。
    case editCommit

    /// 改写提交信息的对话框。
    case editMessage

    /// 用外部比较工具查看提交的全部改动。
    case openDiffTool

    // MARK: 储藏

    /// 预选了这个储藏的应用对话框。
    case applyStash

    /// 删除储藏前的确认。
    case deleteStash

    // MARK: 文件

    /// HEAD 版本的文件原文。
    case showFile

    /// 文件历史。
    case showFileHistory

    /// HEAD 版本的逐行追溯。
    case showBlame

    /// 用编辑器打开工作区里的文件；服务器文件经临时副本写回。
    case openInEditor

    // MARK: 子模块与工作树

    /// 在当前窗口打开子模块。
    case openSubmodule

    /// 在主视图显示子模块的状态与配置。
    case showSubmoduleSettings

    /// 在当前窗口打开工作树。
    case openWorktree

    /// 在新窗口打开工作树。
    case openWorktreeInNewWindow

    // MARK: 远端

    /// 在远端视图里显示远端的设置。
    case showRemoteSettings

    /// 获取对话框，预选这个远端。
    case fetch

    /// 修改远端连接地址的对话框。
    case editConnection

    // MARK: 身份档案、外观与主题

    /// 把档案写进当前仓库的提交身份。
    case setCommitter

    /// 把档案的姓名与邮箱写进全局 Git 配置。
    case setGlobalUser

    /// 把主题设为当前外观的主题。
    case applyTheme

    /// 把 App 外观设为这一种。
    case setAppearance
}

// MARK: - Title

extension QuickAction {
    /// 在历史中定位、跟踪、合并、变基与新建分支。
    private var integrationTitle: String {
        switch self {
        case .revealInHistory: AppLocalization.text("quickActions.revealInHistory")
        case .track: AppLocalization.text("branch.track")
        case .mergeIntoHead: AppLocalization.text("quickActions.mergeIntoHead")
        case .rebaseHead: AppLocalization.text("quickActions.rebaseHead")
        case .mergeParent: AppLocalization.text("quickActions.mergeParent")
        case .rebaseOnParent: AppLocalization.text("quickActions.rebaseOnParent")
        default: AppLocalization.text("branch.create")
        }
    }

    /// 本地分支的推送、快进、置顶与父分支。
    private var branchTitle: String {
        switch self {
        case .publish: AppLocalization.text("quickActions.publishBranch")
        case .push: AppLocalization.text("quickActions.pushBranch")
        case .fastForward: AppLocalization.text("quickActions.fastForward")
        case .pin: AppLocalization.text("branch.pin")
        case .unpin: AppLocalization.text("branch.unpin")
        case .removeParent: AppLocalization.text("branch.parent.remove")
        case .setParent: AppLocalization.text("branch.parent.set")
        default: AppLocalization.text("quickActions.updateBranch")
        }
    }

    /// 本地分支的归档与自动归档。
    private var archiveTitle: String {
        switch self {
        case .archive: AppLocalization.text("branch.archive")
        case .unarchive: AppLocalization.text("branch.unarchive")
        case .skipAutoArchive: AppLocalization.text("quickActions.skipAutoArchive")
        default: AppLocalization.text("quickActions.includeAutoArchive")
        }
    }

    /// 提交与储藏的动作。
    private var commitTitle: String {
        switch self {
        case .showCommit: AppLocalization.text("quickActions.showCommit")
        case .copyHash: AppLocalization.text("quickActions.copyCommitHash")
        case .createTag: AppLocalization.text("quickActions.createTag")
        case .editCommit: AppLocalization.text("quickActions.editCommit")
        case .editMessage: AppLocalization.text("rewrite.reword")
        case .openDiffTool: AppLocalization.text("externalTool.openDiffTool")
        case .applyStash: AppLocalization.text("stash.apply")
        default: AppLocalization.text("stash.delete")
        }
    }

    /// 文件、子模块、工作树、远端、身份档案、主题与外观的动作。
    private var otherTitle: String {
        switch self {
        case .showFile: AppLocalization.text("quickActions.showFile")
        case .showFileHistory: AppLocalization.text("quickActions.showFileHistory")
        case .showBlame: AppLocalization.text("quickActions.showBlame")
        case .openInEditor: AppLocalization.text("quickActions.openInEditor")
        case .openSubmodule: AppLocalization.text("quickActions.openSubmodule")
        case .showSubmoduleSettings: AppLocalization.text("quickActions.showSubmoduleSettings")
        case .openWorktree: AppLocalization.text("quickActions.openWorktree")
        case .openWorktreeInNewWindow: AppLocalization.text("quickActions.openWorktreeInNewWindow")
        case .showRemoteSettings: AppLocalization.text("quickActions.showRemoteSettings")
        case .fetch: AppLocalization.text("sync.fetch")
        case .editConnection: AppLocalization.text("remote.editConnection")
        case .setCommitter: AppLocalization.text("quickActions.setCommitter")
        case .setGlobalUser: AppLocalization.text("quickActions.setGlobalUser")
        case .applyTheme: AppLocalization.text("quickActions.applyTheme")
        default: AppLocalization.text("quickActions.setAppearance")
        }
    }

    /// 动作行与对象行右侧提示里的动作名；同一个动作对不同种类的对象写出对象的类型，如 Delete Branch 与 Delete Tag。
    func title(for kind: QuickActionKind) -> String {
        switch self {
        case .show, .revealInFinder, .openInTerminal, .copyPath, .createSnapshot:
            workspaceTitle(for: kind)
        case .showReferenceHistory, .checkout, .delete, .rename, .copyName:
            referenceTitle(for: kind)
        case .revealInHistory, .track, .mergeIntoHead, .rebaseHead, .mergeParent, .rebaseOnParent, .createBranch:
            integrationTitle
        case .publish, .push, .fastForward, .pin, .unpin, .removeParent, .setParent, .updateBranch:
            branchTitle
        case .archive, .unarchive, .skipAutoArchive, .includeInAutoArchive:
            archiveTitle
        case .showCommit, .copyHash, .createTag, .editCommit, .editMessage, .openDiffTool, .applyStash, .deleteStash:
            commitTitle
        default:
            otherTitle
        }
    }

    /// 工作区与工作树共用的系统动作；工作树的写出 Worktree。
    private func workspaceTitle(for kind: QuickActionKind) -> String {
        switch (self, kind) {
        case (.show, _): AppLocalization.text("quickActions.showInApp")
        case (.revealInFinder, .worktree): AppLocalization.text("quickActions.revealWorktree")
        case (.revealInFinder, _): AppLocalization.text("action.revealFinder")
        case (.openInTerminal, .worktree): AppLocalization.text("quickActions.openWorktreeInTerminal")
        case (.openInTerminal, _): AppLocalization.text("action.openTerminal")
        case (.copyPath, _): AppLocalization.text("action.copyPath")
        default: AppLocalization.text("stash.snapshot")
        }
    }

    /// 分支、远端分支与标签共有的动作，名称里写出引用的类型。
    private func referenceTitle(for kind: QuickActionKind) -> String {
        switch (self, kind) {
        case (.showReferenceHistory, .remoteBranch): AppLocalization.text("quickActions.showRemoteBranchHistory")
        case (.showReferenceHistory, .tag): AppLocalization.text("quickActions.showTagHistory")
        case (.showReferenceHistory, _): AppLocalization.text("quickActions.showBranchHistory")
        case (.checkout, .remoteBranch): AppLocalization.text("quickActions.checkoutRemoteBranch")
        case (.checkout, .tag): AppLocalization.text("quickActions.checkoutTag")
        case (.checkout, _): AppLocalization.text("branch.checkout")
        case (.delete, .remoteBranch): AppLocalization.text("quickActions.deleteRemoteBranch")
        case (.delete, .tag): AppLocalization.text("tag.delete")
        case (.delete, _): AppLocalization.text("branch.delete")
        case (.rename, .remoteBranch): AppLocalization.text("branch.renameRemote")
        case (.rename, _): AppLocalization.text("branch.rename")
        case (_, .remoteBranch): AppLocalization.text("quickActions.copyRemoteBranchName")
        case (_, .tag): AppLocalization.text("quickActions.copyTagName")
        default: AppLocalization.text("branch.copyName")
        }
    }

}
