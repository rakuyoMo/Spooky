import AppKit

// MARK: - HelpArticle

/// 官网手册里的一节：对话框、冲突向导与签名弹窗的帮助按钮打开它。
///
/// 原始值是英文页相对网站根目录的路径与锚点；没有语言前缀的地址由官网按浏览器的语言跳到对应的译文。
enum HelpArticle: String, CaseIterable {
    // MARK: 工作区与提交

    /// “丢弃改动”：丢弃所选文件与丢弃全部改动的确认。
    case discard = "guide/work/diff/#discard"

    /// “未跟踪与忽略的文件”：自定义忽略或排除规则，以及忽略已跟踪文件时是否取消跟踪的询问。
    case ignore = "guide/work/working-copy/#untracked-ignored"

    /// “保存储藏”：保存储藏与快照。
    case saveStash = "guide/work/stash/#save"

    /// “储藏部分文件”：只储藏所选文件，以及它们的快照。
    case partialStash = "guide/work/stash/#partial"

    /// “应用储藏”。
    case applyStash = "guide/work/stash/#apply"

    /// “删除储藏”：删除一个或几个储藏的确认。
    case deleteStashes = "guide/work/stash/#delete"

    /// “自动储藏”：操作被本地改动挡住时先储藏的询问。
    case autoStash = "guide/work/stash/#auto-stash"

    /// “使用冲突向导”：选中冲突文件时的右栏。
    case conflictWizard = "guide/work/conflicts/#wizard"

    // MARK: 历史

    /// “比较两个版本”。
    case compare = "guide/history/commit-details/#compare"

    /// “签名”：提交与标签的签名弹窗。
    case signatures = "guide/history/commit-details/#signatures"

    /// “从某个版本恢复文件”：把工作区的文件恢复到指定版本，以及从文件历史或提交详情恢复的确认。
    case restore = "guide/history/file-views/#restore"

    /// “反转提交”。
    case revert = "guide/history/rewrite/#revert"

    /// “摘取提交”。
    case cherryPick = "guide/history/rewrite/#cherry-pick"

    /// “重置到更早的提交”。
    case reset = "guide/history/rewrite/#reset"

    /// “把提交变基到别处”。
    case rebaseOnto = "guide/history/rewrite/#rebase-onto"

    // MARK: 分支与同步

    /// “新建分支”。
    case createBranch = "guide/branches/branches/#create"

    /// “检出标签或提交”。
    case checkoutRevision = "guide/branches/branches/#checkout-revision"

    /// “合并”。
    case merge = "guide/branches/merge-rebase/#merge"

    /// “变基”。
    case rebase = "guide/branches/merge-rebase/#rebase"

    /// “获取”。
    case fetch = "guide/branches/sync/#fetch"

    /// “拉取”。
    case pull = "guide/branches/sync/#pull"

    /// “推送”：推送 HEAD 与推送所选分支。
    case push = "guide/branches/sync/#push"

    /// “发布分支”。
    case publishBranch = "guide/branches/sync/#publish"

    /// “同步”。
    case sync = "guide/branches/sync/#sync"

    /// “安全强推”。
    case forcePush = "guide/branches/sync/#force-push"

    /// “发布标签”。
    case publishTag = "guide/branches/tags-remotes/#publish-tag"

    /// “添加远端”。
    case addRemote = "guide/branches/tags-remotes/#add-remote"

    /// “远端设置”：修改获取与推送地址。
    case remoteSettings = "guide/branches/tags-remotes/#remote-settings"

    // MARK: 子模块与工作树

    /// “添加子模块”。
    case addSubmodule = "guide/advanced/submodules/#add"

    /// “获取与更新”：获取或更新子模块。
    case updateSubmodule = "guide/advanced/submodules/#update"

    /// “初始化与同步”：初始化子模块，或同步改过的地址。
    case initializeSubmodule = "guide/advanced/submodules/#initialize"

    /// “详情”：子模块的配置页，修改地址在这里。
    case submoduleSettings = "guide/advanced/submodules/#details"

    /// “移动、改名与删除”：删除子模块。
    case deleteSubmodule = "guide/advanced/submodules/#manage"

    /// “修复子模块”。
    case repairSubmodule = "guide/advanced/submodules/#repair"

    /// “添加工作树”。
    case addWorktree = "guide/advanced/worktrees/#add"

    /// “移动工作树”。
    case moveWorktree = "guide/advanced/worktrees/#move"

    /// “删除工作树”。
    case removeWorktree = "guide/advanced/worktrees/#remove"

    /// “修复工作树”：重新指定被移走的工作树文件夹。
    case repairWorktree = "guide/advanced/worktrees/#repair"

    // MARK: 仓库与托管账号

    /// “克隆仓库”。
    case clone = "guide/repositories/manager/#clone"

    /// “GitHub”：添加或重新认证 GitHub 账号。
    case github = "guide/hosting/accounts/#github"

    /// “GitLab.com”：添加或重新认证 GitLab.com 账号。
    case gitlab = "guide/hosting/accounts/#gitlab-com"

    /// “私有部署的 GitLab”：添加或重新认证私有部署的 GitLab 账号。
    case selfManagedGitLab = "guide/hosting/accounts/#self-managed"

    /// “发布仓库”：在托管服务上新建仓库并推送。
    case publishRepository = "guide/hosting/accounts/#publish"

    /// 这一节在官网上的地址。
    var url: URL? {
        URL(string: rawValue, relativeTo: HelpLinks.website)?.absoluteURL
    }

    /// 在默认浏览器里打开这一节。
    func open() {
        url.map { _ = NSWorkspace.shared.open($0) }
    }
}
