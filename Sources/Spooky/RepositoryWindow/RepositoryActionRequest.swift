import SpookyKit

// MARK: - RepositoryActionRequest

/// 同一个 Git 动作的菜单、工具栏、右键和拖放共享参数入口。
struct RepositoryActionRequest {
    /// 这个入口支持的操作种类；原始值是 Activity 记录与拖放提示的标题的资源键，加上 `.help` 是对话框说明的资源键。
    enum Kind: String {
        /// 新建本地分支。
        case create = "branch.create"

        /// 新建跟踪远端的本地分支。
        case track = "branch.track"

        /// 获取一个或全部远端。
        case fetch = "sync.fetch"

        /// 显式合并或变基拉取。
        case pull = "sync.pull"

        /// 推送本地分支。
        case push = "sync.push"

        /// 首次发布分支。
        case publish = "sync.publish"

        /// 合并到当前分支。
        case merge = "sync.merge"

        /// Activity 记录的传输方向：要连接远端的获取、拉取、推送与发布有方向，记在 Remote 页；其余为 nil，记在 Repository 页。
        var transfer: ActivityTransfer? {
            switch self {
            case .fetch: .fetch
            case .pull: .pull
            case .push, .publish: .push
            case .create, .track, .merge: nil
            }
        }

        /// 对话框标题的资源键：新建分支是 Create New Branch，推送按本地分支是不是 HEAD 分支写 Push HEAD 或 Push Branch。
        ///
        /// - Parameter pushesHead: 推送的本地分支是不是 HEAD 分支；其余种类不看它。
        func titleKey(pushesHead: Bool) -> String {
            switch self {
            case .create: "branch.create.title"
            case .push: pushesHead ? "sync.pushHead" : "sync.pushBranch"
            case .track, .fetch, .pull, .publish, .merge: rawValue
            }
        }

        /// 主按钮的资源键：跟踪远端分支是 Create，推送与标题相同。
        ///
        /// - Parameter pushesHead: 推送的本地分支是不是 HEAD 分支；其余种类不看它。
        func submitKey(pushesHead: Bool) -> String {
            switch self {
            case .track: "branch.track.submit"
            case .push: titleKey(pushesHead: pushesHead)
            case .create, .fetch, .pull, .publish, .merge: rawValue
            }
        }
    }

    /// 对话框类型。
    let kind: Kind

    /// 已选的起点或目标引用。
    var reference: String? = nil

    /// 拖放或远端右键指定的远端。
    var remote: String? = nil

    /// 推送拖放指定的本地源分支。
    var localBranch: String? = nil

    /// 新建分支预填的名称，如文件夹右键预填的文件夹路径与结尾的 “/”。
    var name: String? = nil

    /// 清理右键预设的选项。
    var prune = false

    /// 实际打开的请求：推送 HEAD 分支、没有指定目标远端分支而 HEAD 还没有上游时，改为发布这个分支；其它请求原样返回。
    ///
    /// - Parameter head: 当前分支的状态；读不到状态时为 nil。
    func resolved(for head: BranchStatus?) -> Self {
        guard
            kind == .push,
            reference == nil,
            let head,
            let name = head.head,
            (localBranch ?? name) == name,
            head.upstream == nil
        else {
            return self
        }

        return Self(kind: .publish, remote: remote, localBranch: localBranch)
    }
}
