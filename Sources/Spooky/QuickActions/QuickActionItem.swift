import SpookyKit

// MARK: - QuickActionKind

/// 快捷操作的对象种类；声明顺序就是结果列表里各类对象的先后。
///
/// 要执行 Git 查询的文件与提交排在最后，它们的结果晚到时只追加在列表末尾，已显示的行不会移动。
enum QuickActionKind: Int, CaseIterable, Comparable {
    /// 主视图入口。
    case navigation

    /// 本地分支。
    case branch

    /// 工作树。
    case worktree

    /// 远端。
    case remote

    /// 子模块。
    case submodule

    /// 远端分支。
    case remoteBranch

    /// 标签。
    case tag

    /// 储藏。
    case stash

    /// 身份档案。
    case userProfile

    /// App 外观。
    case appearance

    /// 文本区主题。
    case theme

    /// HEAD 树中的文件。
    case file

    /// 提交。
    case commit

    /// 结果行副标题里的类型名。
    var title: String {
        switch self {
        case .navigation: AppLocalization.text("quickActions.type.navigation")
        case .branch: AppLocalization.text("quickActions.type.branch")
        case .worktree: AppLocalization.text("quickActions.type.worktree")
        case .remote: AppLocalization.text("quickActions.type.remote")
        case .submodule: AppLocalization.text("quickActions.type.submodule")
        case .remoteBranch: AppLocalization.text("quickActions.type.remoteBranch")
        case .tag: AppLocalization.text("quickActions.type.tag")
        case .stash: AppLocalization.text("quickActions.type.stash")
        case .userProfile: AppLocalization.text("quickActions.type.userProfile")
        case .appearance: AppLocalization.text("quickActions.type.appearance")
        case .theme: AppLocalization.text("quickActions.type.theme")
        case .file: AppLocalization.text("quickActions.type.file")
        case .commit: AppLocalization.text("quickActions.type.commit")
        }
    }

    /// 按声明顺序比较。
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - QuickActionDestination

/// 导航对象指向的主视图，与侧边栏 Workspace 分组的各行相同。
enum QuickActionDestination: CaseIterable {
    /// 工作区。
    case workingCopy

    /// 全部分支的历史。
    case history

    /// 储藏列表。
    case stashes

    /// 分支整理。
    case branchesReview

    /// 引用日志。
    case reflog

    /// 仓库设置。
    case settings

    /// 侧边栏里的名称。
    var title: String {
        switch self {
        case .workingCopy: AppLocalization.text("workspace.title")
        case .history: AppLocalization.text("history.title")
        case .stashes: AppLocalization.text("stash.title")
        case .branchesReview: AppLocalization.text("review.title")
        case .reflog: AppLocalization.text("reflog.title")
        case .settings: AppLocalization.text("repositorySettings.title")
        }
    }

    /// 侧边栏里的符号。
    var symbol: String {
        switch self {
        case .workingCopy: "folder"
        case .history: "clock"
        case .stashes: "tray.full"
        case .branchesReview: "arrow.triangle.pull"
        case .reflog: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

// MARK: - QuickActionObject

/// 快捷操作面板里可以搜索、执行动作的一个对象。
enum QuickActionObject: Equatable {
    /// 主视图入口。
    case navigation(QuickActionDestination)

    /// 本地分支。
    case branch(RepositoryReference)

    /// 工作树。
    case worktree(Worktree)

    /// 远端名。
    case remote(String)

    /// 子模块。
    case submodule(Submodule)

    /// 远端分支。
    case remoteBranch(RepositoryReference)

    /// 标签。
    case tag(RepositoryReference)

    /// 储藏。
    case stash(StashEntry)

    /// 身份档案。
    case userProfile(UserProfile)

    /// App 外观的一种选择。
    case appearance(AppAppearance)

    /// 文本区主题。
    case theme(id: String, name: String)

    /// HEAD 树中的文件，值为仓库内的相对路径。
    case file(String)

    /// 提交；`onHead` 表示它能从 HEAD 到达，改写类动作只对这样的提交出现。
    case commit(HistoryCommit, onHead: Bool)

    /// 对象种类。
    var kind: QuickActionKind {
        switch self {
        case .navigation: .navigation
        case .branch: .branch
        case .worktree: .worktree
        case .remote: .remote
        case .submodule: .submodule
        case .remoteBranch: .remoteBranch
        case .tag: .tag
        case .stash: .stash
        case .userProfile: .userProfile
        case .appearance: .appearance
        case .theme: .theme
        case .file: .file
        case .commit: .commit
        }
    }

    /// 在同一次打开的面板里稳定的身份，选中行在列表刷新后据此找回。
    var identifier: String {
        switch self {
        case .navigation(let destination): "navigation:\(destination)"
        case .branch(let reference), .remoteBranch(let reference), .tag(let reference): reference.id
        case .worktree(let worktree): "worktree:" + worktree.path
        case .remote(let name): "remote:" + name
        case .submodule(let submodule): "submodule:" + submodule.path
        case .stash(let stash): "stash:" + stash.id
        case .userProfile(let profile): "profile:" + profile.id.uuidString
        case .appearance(let appearance): "appearance:\(appearance.rawValue)"
        case .theme(let id, _): "theme:" + id
        case .file(let path): "file:" + path
        case .commit(let commit, _): "commit:" + commit.id
        }
    }

    /// 结果行的标题，也是模糊匹配的对象；文件只取文件名，提交取标题行。
    var title: String {
        switch self {
        case .navigation(let destination): destination.title
        case .branch(let reference), .remoteBranch(let reference), .tag(let reference): reference.name
        case .worktree(let worktree): worktree.name
        case .remote(let name): name
        case .submodule(let submodule): submodule.name
        case .stash(let stash): stash.title
        case .userProfile(let profile): profile.title
        case .appearance(let appearance): appearance.title
        case .theme(_, let name): name
        case .file(let path): path.split(separator: "/").last.map(String.init) ?? path
        case .commit(let commit, _): commit.subject
        }
    }

    /// 结果行的副标题：类型名；远端分支、文件与提交在后面带上所在远端、路径与短哈希。
    var subtitle: String {
        let detail: String? =
            switch self {
            case .remoteBranch(let reference): reference.id.split(separator: "/").dropFirst(2).first.map(String.init)
            case .file(let path): path
            case .commit(let commit, _): commit.shortID
            default: nil
            }

        guard let detail else {
            return kind.title
        }

        return AppLocalization.text("quickActions.detail", kind.title, detail)
    }

    /// 结果行的符号，与侧边栏等处同类对象的符号一致。
    var symbol: String {
        switch self {
        case .navigation(let destination): destination.symbol
        case .branch: "arrow.triangle.branch"
        case .worktree: "rectangle.on.rectangle"
        case .remote, .remoteBranch: "network"
        case .submodule: "shippingbox"
        case .tag: "tag"
        case .stash: "tray"
        case .userProfile: "person.crop.circle"
        case .appearance: "circle.lefthalf.filled"
        case .theme: "paintpalette"
        case .file: "doc"
        case .commit: "smallcircle.filled.circle"
        }
    }
}

// MARK: - QuickActionItem

/// 结果列表的一行：对象本身，或动作模式里这个对象的一个动作。
struct QuickActionItem: Equatable {
    /// 行所属的对象。
    let object: QuickActionObject

    /// 动作行的动作；对象行为 nil，↩ 执行对象的默认动作。
    let action: QuickAction?

    /// 选中行在列表刷新后据此找回。
    var identifier: String {
        object.identifier + (action.map { "#\($0)" } ?? "")
    }

    /// 对象行显示对象名，动作行显示动作名。
    var title: String {
        action?.title(for: object.kind) ?? object.title
    }

    /// 动作行的副标题固定为 Action。
    var subtitle: String {
        action == nil ? object.subtitle : AppLocalization.text("quickActions.type.action")
    }

    /// 动作行统一用齿轮符号。
    var symbol: String {
        action == nil ? object.symbol : "gearshape"
    }
}
