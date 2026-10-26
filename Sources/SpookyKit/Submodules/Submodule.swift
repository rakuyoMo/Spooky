import Foundation

// MARK: - SubmoduleFetchMode

/// 子模块的 `fetchRecurseSubmodules`：父仓库获取时是否连带获取这个子模块。
public enum SubmoduleFetchMode: String, Sendable, CaseIterable {
    /// 从不连带获取。
    case never = "false"

    /// 总是连带获取。
    case always = "true"

    /// 父仓库获取到改动了子模块指针的提交时才获取；没有配置时 Git 按它处理。
    case onDemand = "on-demand"

    /// 按 Git 的写法解析配置值：布尔值的各种写法都接受，认不出时为 nil。
    ///
    /// - Parameter configValue: 配置里的原值。
    public init?(configValue: String) {
        switch configValue.lowercased() {
        case "on-demand": self = .onDemand
        case "true", "yes", "on", "1": self = .always
        case "false", "no", "off", "0": self = .never
        default: return nil
        }
    }
}

// MARK: - SubmoduleIgnoreMode

/// 子模块的 `ignore`：父仓库的状态里忽略子模块的哪些改动。
public enum SubmoduleIgnoreMode: String, Sendable, CaseIterable {
    /// 不忽略任何改动，配置值为 none；没有配置时 Git 按它处理。
    case nothing = "none"

    /// 子模块的任何改动都不算改动，包括检出了别的提交。
    case all

    /// 只忽略子模块里的未跟踪文件。
    case untracked

    /// 忽略子模块工作区里的全部改动，只看检出的提交。
    case dirty

    /// 按配置原值解析，Git 对取值不区分大小写；认不出时为 nil。
    ///
    /// - Parameter configValue: 配置里的原值。
    public init?(configValue: String) {
        self.init(rawValue: configValue.lowercased())
    }
}

// MARK: - SubmoduleUpdateStrategy

/// 子模块的 `update`：更新子模块时怎样把它带到指针所指的提交。
public enum SubmoduleUpdateStrategy: String, Sendable, CaseIterable {
    /// 不更新，配置值为 none。
    case skip = "none"

    /// 以分离 HEAD 检出指针所指的提交；没有配置时 Git 按它处理。
    case checkout

    /// 把子模块当前分支变基到指针所指的提交上。
    case rebase

    /// 把指针所指的提交合并进子模块当前分支。
    case merge

    /// 按配置原值解析；`!命令` 这类自定义写法认不出，返回 nil。
    ///
    /// - Parameter configValue: 配置里的原值。
    public init?(configValue: String) {
        self.init(rawValue: configValue.lowercased())
    }
}

// MARK: - SubmoduleSettings

/// 子模块在 `.gitmodules` 或仓库本地配置里的一段设置，值保持配置里的原样。
public struct SubmoduleSettings: Sendable, Hashable {
    /// 子模块在父仓库里的相对路径。
    public var path: String?

    /// 子模块仓库的地址；`.gitmodules` 里可以是相对父仓库远端的写法。
    public var url: String?

    /// `fetchRecurseSubmodules` 的原值。
    public var fetchRecurseSubmodules: String?

    /// `ignore` 的原值。
    public var ignore: String?

    /// `update` 的原值。
    public var update: String?

    /// 创建一段设置；解析配置与测试使用。
    public init(
        path: String? = nil,
        url: String? = nil,
        fetchRecurseSubmodules: String? = nil,
        ignore: String? = nil,
        update: String? = nil
    ) {
        self.path = path
        self.url = url
        self.fetchRecurseSubmodules = fetchRecurseSubmodules
        self.ignore = ignore
        self.update = update
    }
}

// MARK: - SubmoduleState

/// `git submodule status` 给出的子模块状态。
public enum SubmoduleState: Sendable, Hashable {
    /// 状态读取失败。
    case unknown

    /// 还没有检出：没有初始化，或初始化了还没有更新。
    case uninitialized

    /// 检出的提交就是指针所指的提交。
    case clean

    /// 检出的提交与指针所指的提交不同。
    case updated

    /// 子模块指针处于合并冲突中。
    case unmerged
}

// MARK: - SubmoduleProblem

/// 子模块配置不完整的原因；有问题的子模块只能修复或删除。
public enum SubmoduleProblem: Sendable, Hashable {
    /// 索引里有子模块指针，`.gitmodules` 里却没有对应的段。
    case missingConfiguration

    /// `.gitmodules` 里有这一段，索引里却没有子模块指针。
    case missingPointer
}

// MARK: - Submodule

/// 父仓库的一个子模块：`.gitmodules` 与本地配置里的两段设置、索引里的指针与检出状态。
public struct Submodule: Sendable, Hashable, Identifiable {
    /// 以路径区分子模块，配置不完整的子模块同样有路径。
    public var id: String { path }

    /// `submodule.<名称>` 段的名称；缺少配置时取路径。
    public let name: String

    /// 子模块在父仓库里的相对路径。
    public let path: String

    /// `.gitmodules` 里的设置；缺少配置时为 nil。
    public let shared: SubmoduleSettings?

    /// 仓库本地配置里的设置；没有初始化时为 nil。
    public let local: SubmoduleSettings?

    /// 索引里子模块指针所指的提交；缺少指针或指针处于冲突中时为 nil。
    public let pointer: String?

    /// 子模块里检出的提交；没有检出时为 nil。
    public let checkedOut: String?

    /// 检出状态。
    public let state: SubmoduleState

    /// 配置不完整的原因；完整时为 nil。
    public let problem: SubmoduleProblem?

    /// 本地配置里的地址与 `.gitmodules` 里的不一致，需要同步。
    public let needsSynchronizing: Bool

    /// 配置完整，可以执行子模块操作。
    public var isValid: Bool { problem == nil }

    /// 已初始化：本地配置里登记了地址。
    public var isInitialized: Bool { local?.url != nil }

    /// 子模块已检出，可以在里面执行 Git。
    public var isPopulated: Bool { state == .clean || state == .updated }

    /// 生效的地址：初始化后以本地配置为准，否则取 `.gitmodules` 里的写法。
    public var url: String? { local?.url ?? shared?.url }

    /// 生效的获取方式；两处都没有配置时为 nil，按 Git 的默认值处理。
    public var fetchMode: SubmoduleFetchMode? {
        (local?.fetchRecurseSubmodules ?? shared?.fetchRecurseSubmodules).flatMap(SubmoduleFetchMode.init(configValue:))
    }

    /// 生效的忽略方式；两处都没有配置时为 nil，按 Git 的默认值处理。
    public var ignoreMode: SubmoduleIgnoreMode? {
        (local?.ignore ?? shared?.ignore).flatMap(SubmoduleIgnoreMode.init(configValue:))
    }

    /// 生效的更新方式；两处都没有配置时为 nil，按 Git 的默认值处理。
    public var updateStrategy: SubmoduleUpdateStrategy? {
        (local?.update ?? shared?.update).flatMap(SubmoduleUpdateStrategy.init(configValue:))
    }

    /// 创建子模块；读取清单与测试使用。
    public init(
        name: String,
        path: String,
        shared: SubmoduleSettings?,
        local: SubmoduleSettings?,
        pointer: String?,
        checkedOut: String?,
        state: SubmoduleState,
        problem: SubmoduleProblem?,
        needsSynchronizing: Bool
    ) {
        self.name = name
        self.path = path
        self.shared = shared
        self.local = local
        self.pointer = pointer
        self.checkedOut = checkedOut
        self.state = state
        self.problem = problem
        self.needsSynchronizing = needsSynchronizing
    }
}

// MARK: - SubmoduleSummary

/// 已检出子模块的工作区概况，侧边栏的徽标与详情的 Local Changes 使用。
public struct SubmoduleSummary: Sendable, Hashable {
    /// 子模块工作区里有变化的文件数，未跟踪的文件逐个计入。
    public let changes: Int

    /// 检出的提交领先指针的提交数；检出的就是指针或读不到时为 0。
    public let ahead: Int

    /// 检出的提交落后指针的提交数；检出的就是指针或读不到时为 0。
    public let behind: Int

    /// 创建概况；读取与测试使用。
    public init(changes: Int, ahead: Int, behind: Int) {
        self.changes = changes
        self.ahead = ahead
        self.behind = behind
    }
}

// MARK: - SubmoduleRevision

/// 子模块里可以检出的一个分支或标签。
public struct SubmoduleRevision: Sendable, Hashable, Identifiable {
    /// 以完整引用名区分。
    public var id: String { reference }

    /// 完整引用名，如 `refs/heads/main`、`refs/tags/v1.0`。
    public let reference: String

    /// 是子模块当前检出的分支。
    public let isCurrent: Bool

    /// 是标签：检出标签会分离 HEAD。
    public var isTag: Bool { reference.hasPrefix("refs/tags/") }

    /// 去掉 `refs/heads/`、`refs/tags/` 前缀的名称。
    public var name: String {
        for prefix in ["refs/heads/", "refs/tags/"] where reference.hasPrefix(prefix) {
            return String(reference.dropFirst(prefix.count))
        }

        return reference
    }

    /// 创建一项；读取与测试使用。
    public init(reference: String, isCurrent: Bool) {
        self.reference = reference
        self.isCurrent = isCurrent
    }
}

// MARK: - SubmoduleError

/// 子模块操作在执行 Git 之前或 Git 报出的、界面要分别处理的失败。
public enum SubmoduleError: Error, Sendable, Equatable {
    /// 父仓库的 Git 目录里已有同名子模块的 Git 目录，可以复用或覆盖。
    case gitDirectoryExists(name: String)

    /// 子模块里有本地改动，删除需要再次确认。
    case localModifications

    /// 新名称已被另一个子模块使用，或它的 Git 目录已存在。
    case nameInUse(String)

    /// 修复缺少配置的子模块时找不到它的远端地址。
    case missingRemoteURL
}
