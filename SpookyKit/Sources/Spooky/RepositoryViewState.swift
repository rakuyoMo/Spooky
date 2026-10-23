import Foundation
import SpookyKit

/// 一个仓库在窗口中的视图状态：主视图、选区与提交草稿；仓库数据在切回时重新读取。
struct RepositoryViewState {
    /// 当前主视图。
    var activeView = RepositoryView.workingCopy

    /// 详情显示的文件。
    var selectedID: StatusRowID?

    /// 文件列表的多选。
    var selectedIDs: Set<StatusRowID> = []

    /// 详情显示的暂存侧。
    var diffSide = DiffSide.unstaged

    /// 提交标题草稿。
    var commitSubject = ""

    /// 提交正文草稿。
    var commitBody = ""

    /// 是否处于修补模式。
    var amend = false

    /// 进入修补前的普通草稿。
    var originalDraft: (subject: String, body: String)?

    /// 是否只显示冲突文件。
    var onlyConflicts = false

    /// 历史侧边栏选中的引用。
    var historyReferences: Set<String> = []

    /// 历史列表选中的提交。
    var historyCommits: Set<String> = []
}

/// 每个窗口最多保留 15 个仓库的视图状态，超出时淘汰最久未使用的仓库。
struct RepositoryViewStateCache {
    /// 单个窗口缓存的仓库数量上限，包含正在显示的仓库。
    static let capacity = 15

    /// 按仓库位置保存的状态。
    private var states: [RepositoryLocation: RepositoryViewState] = [:]

    /// 使用顺序，末尾为最近使用。
    private(set) var order: [RepositoryLocation] = []

    /// 取出仓库的状态并标记为最近使用。
    mutating func state(for location: RepositoryLocation) -> RepositoryViewState? {
        guard let state = states[location] else {
            return nil
        }

        touch(location)
        return state
    }

    /// 保存仓库的状态，超出上限时从最久未使用的仓库开始淘汰。
    mutating func store(_ state: RepositoryViewState, for location: RepositoryLocation) {
        states[location] = state
        touch(location)

        while order.count > Self.capacity {
            states[order.removeFirst()] = nil
        }
    }

    /// 把仓库移到使用顺序末尾。
    private mutating func touch(_ location: RepositoryLocation) {
        order.removeAll { $0 == location }
        order.append(location)
    }
}
