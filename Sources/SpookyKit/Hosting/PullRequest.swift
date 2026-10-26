import Foundation

// MARK: - PullRequestID

/// 一个 Pull Request 或 Merge Request 的身份：实例、目标项目与项目内编号，不同项目的同号请求不会混淆。
public struct PullRequestID: Sendable, Hashable, Codable {
    /// 所在的实例。
    public let instance: HostingInstance

    /// 目标项目的路径，如 `owner/repo` 或 `group/subgroup/project`。
    public let project: String

    /// 项目内的编号：GitHub 的 number，GitLab 的 iid。
    public let number: Int

    /// 界面里的编号：GitHub 写作 `#12`，GitLab 写作 `!12`。
    public var reference: String {
        (instance.service == .github ? "#" : "!") + String(number)
    }

    /// 创建身份。
    public init(instance: HostingInstance, project: String, number: Int) {
        self.instance = instance
        self.project = project
        self.number = number
    }
}

// MARK: - PullRequestState

/// 请求的状态。
public enum PullRequestState: String, Sendable, Hashable {
    /// 打开着，可以合并或关闭。
    case /// 已关闭，没有合并。
        open

    case closed

    /// 已合并。
    case merged
}

// MARK: - PullRequestBranch

/// 请求的一侧：所在项目、分支与提交。
public struct PullRequestBranch: Sendable, Hashable {
    /// 分支所在的项目路径；Fork 已被删除时为 nil。
    public let project: String?

    /// 分支名。
    public let branch: String

    /// 分支当前的提交；托管服务没有给出时为空字符串。
    public let sha: String

    /// 创建一侧。
    public init(project: String?, branch: String, sha: String) {
        self.project = project
        self.branch = branch
        self.sha = sha
    }
}

// MARK: - PullRequest

/// 托管服务上的一个 Pull Request 或 Merge Request。
public struct PullRequest: Sendable, Hashable, Identifiable {
    /// 身份。
    public let id: PullRequestID

    /// 标题。
    public let title: String

    /// 描述；没有描述时为空字符串。
    public let body: String

    /// 状态。
    public let state: PullRequestState

    /// 是草稿。
    public let isDraft: Bool

    /// 作者的用户名。
    public let author: String

    /// 创建的时间。
    public let createdAt: Date

    /// 最后更新的时间。
    public let updatedAt: Date

    /// 源分支。
    public let source: PullRequestBranch

    /// 目标分支。
    public let target: PullRequestBranch

    /// 指派的用户名。
    public let assignees: [String]

    /// 网页地址。
    public let webURL: URL?

    /// 托管服务算出的合并基准；GitHub 不提供，为 nil。
    public let mergeBase: String?

    /// 源分支在另一个项目里，即来自 Fork。
    public var isFromFork: Bool {
        source.project != target.project
    }

    /// 创建请求；解析与测试使用。
    public init(
        id: PullRequestID,
        title: String,
        body: String,
        state: PullRequestState,
        isDraft: Bool,
        author: String,
        createdAt: Date,
        updatedAt: Date,
        source: PullRequestBranch,
        target: PullRequestBranch,
        assignees: [String] = [],
        webURL: URL? = nil,
        mergeBase: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.state = state
        self.isDraft = isDraft
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.target = target
        self.assignees = assignees
        self.webURL = webURL
        self.mergeBase = mergeBase
    }
}

// MARK: - PullRequestComment

/// 请求下的一条评论；GitLab 的系统记录（如推送了新提交）同样列出并标出。
public struct PullRequestComment: Sendable, Hashable, Identifiable {
    /// 托管服务上的评论编号。
    public let id: Int

    /// 作者的用户名。
    public let author: String

    /// 内容，Markdown。
    public let body: String

    /// 发表的时间。
    public let createdAt: Date

    /// 是托管服务自动写下的记录。
    public let isSystem: Bool

    /// 创建评论；解析与测试使用。
    public init(id: Int, author: String, body: String, createdAt: Date, isSystem: Bool = false) {
        self.id = id
        self.author = author
        self.body = body
        self.createdAt = createdAt
        self.isSystem = isSystem
    }
}

// MARK: - PullRequestMergeMethod

/// 合并方式：GitHub 可选其一；GitLab 的合并策略由项目决定，这里只区分是否压缩。
public enum PullRequestMergeMethod: String, Sendable, Hashable, CaseIterable {
    /// 生成合并提交。
    case merge

    /// 把提交变基到目标分支上。
    case rebase

    /// 压缩成一个提交。
    case squash
}

// MARK: - PullRequestMergeBlock

/// 现在不能合并的原因。
public enum PullRequestMergeBlock: Sendable, Hashable {
    /// 请求已关闭或已合并。
    case notOpen

    /// 当前账号没有合并权限。
    case permission

    /// 是草稿。
    case draft

    /// 与目标分支有冲突。
    case conflicts

    /// 托管服务按项目规则拒绝合并，如检查未通过、缺少批准或分支落后；带服务端给出的状态。
    case policy(String)

    /// 托管服务还在计算能否合并。
    case checking
}

// MARK: - PullRequestMergeOptions

/// 按平台能力、项目设置与当前账号权限给出的合并选项。
public struct PullRequestMergeOptions: Sendable, Hashable {
    /// 可选的合并方式，第一项是默认；GitLab 只有 merge，或在项目要求时只有 squash。
    public let methods: [PullRequestMergeMethod]

    /// GitLab 可以在合并时压缩提交；GitHub 的压缩是一种合并方式，这里为 false。
    public let allowsSquashOption: Bool

    /// GitLab 默认压缩提交。
    public let squashesByDefault: Bool

    /// GitLab 项目要求压缩，不能取消。
    public let requiresSquash: Bool

    /// 合并后默认删除源分支。
    public let deletesSourceBranchByDefault: Bool

    /// 可以在合并时删除源分支：源分支与目标在同一项目里。
    public let canDeleteSourceBranch: Bool

    /// GitLab 项目的合并策略，如 `merge`、`rebase_merge`、`ff`；GitHub 为 nil。
    public let projectMergeMethod: String?

    /// 现在不能合并的原因；可以合并时为 nil。
    public let block: PullRequestMergeBlock?

    /// 创建选项；解析与测试使用。
    public init(
        methods: [PullRequestMergeMethod],
        allowsSquashOption: Bool = false,
        squashesByDefault: Bool = false,
        requiresSquash: Bool = false,
        deletesSourceBranchByDefault: Bool = false,
        canDeleteSourceBranch: Bool = true,
        projectMergeMethod: String? = nil,
        block: PullRequestMergeBlock? = nil
    ) {
        self.methods = methods
        self.allowsSquashOption = allowsSquashOption
        self.squashesByDefault = squashesByDefault
        self.requiresSquash = requiresSquash
        self.deletesSourceBranchByDefault = deletesSourceBranchByDefault
        self.canDeleteSourceBranch = canDeleteSourceBranch
        self.projectMergeMethod = projectMergeMethod
        self.block = block
    }
}

// MARK: - PullRequestMergeResult

/// 平台合并的结果：服务端的说明与合并后目标分支上的提交。
public struct PullRequestMergeResult: Sendable, Hashable {
    /// 合并后的提交；服务端没有给出时为 nil。
    public let sha: String?

    /// 服务端的说明。
    public let message: String

    /// 创建结果。
    public init(sha: String?, message: String) {
        self.sha = sha
        self.message = message
    }
}

// MARK: - PullRequestDraft

/// 新建请求的内容：源与目标的项目和分支、标题与描述。
public struct PullRequestDraft: Sendable, Hashable {
    /// 源分支所在的项目路径。
    public let sourceProject: String

    /// 源分支。
    public let sourceBranch: String

    /// 目标项目路径。
    public let targetProject: String

    /// 目标分支。
    public let targetBranch: String

    /// 标题。
    public let title: String

    /// 描述。
    public let body: String

    /// 创建内容。
    public init(
        sourceProject: String,
        sourceBranch: String,
        targetProject: String,
        targetBranch: String,
        title: String,
        body: String
    ) {
        self.sourceProject = sourceProject
        self.sourceBranch = sourceBranch
        self.targetProject = targetProject
        self.targetBranch = targetBranch
        self.title = title
        self.body = body
    }
}
