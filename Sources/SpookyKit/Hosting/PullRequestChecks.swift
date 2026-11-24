import Foundation

// MARK: - PullRequestCheckState

/// 一项检查、一个作业，或请求 CI/CD 整体的状态。
public enum PullRequestCheckState: String, Sendable, Hashable, CaseIterable {
    /// 没有通过：失败、出错或超时。
    case failure

    /// 被取消。
    case cancelled

    /// 等人处理：GitHub 的 `action_required`，GitLab 的手动作业。
    case manual

    /// 正在运行。
    case running

    /// 还没开始：排队、等待资源或已安排。
    case pending

    /// 通过。
    case success

    /// 结束了，既不算通过也不算失败：GitHub 的 `neutral` 与 `stale`，以及认不出的状态。
    case neutral

    /// 被跳过。
    case skipped

    /// 还会自己变化：等待中或运行中。
    public var isActive: Bool {
        self == .pending || self == .running
    }

    /// 几项状态合成的整体状态：按声明的先后，取其中最靠前的一种；一项都没有时为 nil。
    public static func overall(of states: some Sequence<Self>) -> Self? {
        let present = Set(states)

        return allCases.first { present.contains($0) }
    }
}

// MARK: - Service States

extension PullRequestCheckState {
    /// GitHub 检查运行的状态：结束了的看结论，其余按是否已开始运行。
    ///
    /// - Parameters:
    ///   - status: `completed`、`in_progress`，或 `queued`、`waiting`、`requested`、`pending` 这些还没开始的状态。
    ///   - conclusion: 结束后的结论；还没结束时为 nil。
    init(githubStatus status: String, conclusion: String?) {
        guard status == "completed" else {
            self = status == "in_progress" ? .running : .pending
            return
        }

        self =
            switch conclusion {
            case "success": .success
            case "failure", "timed_out", "startup_failure": .failure
            case "cancelled": .cancelled
            case "skipped": .skipped
            case "action_required": .manual
            default: .neutral
            }
    }

    /// GitHub 提交状态：`success`、`pending`，或算作失败的 `failure` 与 `error`。
    init(githubState state: String) {
        self =
            switch state {
            case "success": .success
            case "pending": .pending
            case "failure", "error": .failure
            default: .neutral
            }
    }

    /// GitLab 流水线或作业的状态；`canceling` 与取消完成一样算被取消。
    init(gitlabStatus status: String) {
        self =
            switch status {
            case "success": .success
            case "failed": .failure
            case "canceled", "canceling": .cancelled
            case "skipped": .skipped
            case "manual": .manual
            case "running": .running
            case "created", "waiting_for_resource", "preparing", "waiting_for_callback", "pending", "scheduled": .pending
            default: .neutral
            }
    }
}

// MARK: - PullRequestCheck

/// 请求 CI/CD 里的一项：GitHub 的检查运行或提交状态，GitLab 流水线里的一个作业。
public struct PullRequestCheck: Sendable, Hashable, Identifiable {
    /// 身份：种类加托管服务上的编号，同一个请求里不重复。
    public let id: String

    /// 名称：检查运行的名字、提交状态的 context，或作业名。
    public let name: String

    /// 所属的一组：GitHub 是写下检查运行的应用，GitLab 是作业所在的阶段；提交状态没有，为 nil。
    public let group: String?

    /// 状态。
    public let state: PullRequestCheckState

    /// 读取日志的 API 路径：GitHub Actions 已结束的作业与 GitLab 流水线里的作业才有；没有日志可读的项为 nil。
    public let logPath: String?

    /// 创建一项；解析与测试使用。
    public init(id: String, name: String, group: String?, state: PullRequestCheckState, logPath: String? = nil) {
        self.id = id
        self.name = name
        self.group = group
        self.state = state
        self.logPath = logPath
    }
}

// MARK: - PullRequestChecks

/// 请求的 CI/CD 状态：整体状态与其中的各项。
public struct PullRequestChecks: Sendable, Hashable {
    /// 整体状态：GitHub 由各项合成，GitLab 是流水线的状态；没有检查或流水线时为 nil。
    public let state: PullRequestCheckState?

    /// 各项：GitHub 先是检查运行、再是提交状态，GitLab 是流水线里的作业；检查运行与作业按创建的先后。
    public let items: [PullRequestCheck]

    /// 整体或其中某一项还会自己变化。
    public var isActive: Bool {
        (state?.isActive ?? false) || items.contains { $0.state.isActive }
    }

    /// 创建状态；解析与测试使用。
    public init(state: PullRequestCheckState?, items: [PullRequestCheck]) {
        self.state = state
        self.items = items
    }
}
