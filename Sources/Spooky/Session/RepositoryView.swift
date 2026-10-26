// MARK: - RepositoryView

/// 当前窗口选中的主视图。
enum RepositoryView: String, CaseIterable {
    /// 工作区状态列表。
    case workingCopy

    /// 分页提交列表与只读提交详情。
    case history

    /// 储藏列表与只读储藏详情。
    case stashes

    /// HEAD 或一个本地分支的引用日志，与所选记录的提交详情。
    case reflog

    /// 一个文件的提交时间线与所选版本的详情。
    case fileHistory

    /// 某个版本的文件原文与逐行追溯。
    case fileContent

    /// 一个远端的设置与远端分支。
    case remote

    /// 托管服务上打开着的 Pull Request 或 Merge Request，与所选请求的详情。
    case pullRequests

    /// 本地分支与基准分支的比较与整理。
    case branchesReview

    /// 仓库设置：描述、Issue 追踪、提交人身份、折行与签名，以及 LFS、忽略与排除规则。
    case settings

    /// 一个子模块的状态与两处配置。
    case submodule

    /// 一个工作树的详情。
    case worktree

    /// 工具栏搜索框只作用于提供列表过滤的视图，其余视图中禁用。
    var supportsSearch: Bool {
        switch self {
        case .fileContent, .remote, .settings, .submodule, .worktree, .pullRequests: false
        case .workingCopy, .history, .stashes, .fileHistory, .branchesReview, .reflog: true
        }
    }
}
