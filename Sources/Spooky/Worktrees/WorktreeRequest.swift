import SpookyKit

// MARK: - WorktreeRequest

/// 工作树的对话框；菜单、侧边栏、分支右键菜单与拖放共用，由仓库窗口以 sheet 呈现。
enum WorktreeRequest {
    /// 新建工作树；版本为 nil 时预选当前分支。
    case add(revision: String?)

    /// 移动工作树。
    case move(Worktree)

    /// 删除工作树，可以强制。
    case remove(Worktree)

    /// 给出手动移走的工作树的新位置，修复它与仓库的连接。
    case repair(Worktree)
}

// MARK: - RepositoryOpenTarget

/// 另一个仓库在哪里打开。
enum RepositoryOpenTarget {
    /// 本窗口。
    case currentWindow

    /// 本窗口所在标签组里的新标签。
    case newTab

    /// 新窗口。
    case newWindow
}
