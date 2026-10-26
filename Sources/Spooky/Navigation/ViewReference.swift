import Foundation
import SpookyKit

// MARK: - ViewReference

/// 窗口里一个可以回到的视图：仓库管理，或某个仓库的某个主视图连同重新打开它所需的选择。
///
/// 后退 / 前进与窗口恢复都以它记下位置。`string` 与 `init?(string:)` 互为逆运算，形如
/// `repository?location=b:/srv/app&view=history&ref=refs/heads/main`；
/// 服务器仓库的位置写作 `<主机别名>:<远端路径>`，本机仓库写绝对路径。
enum ViewReference: Hashable {
    /// 仓库管理。
    case repositories

    /// 一个仓库里的视图。
    case repository(RepositoryLocation, RepositoryDestination)

    /// 文字形式的路径部分。
    private enum Kind: String {
        /// 仓库管理。
        case repositories

        /// 仓库里的视图。
        case repository
    }

    /// 查询参数里放得下而不必转义的字符：`&`、`=`、`+`、`#` 会改变查询的结构，一律转义。
    private static let allowed: CharacterSet = {
        var characters = CharacterSet.urlQueryAllowed
        characters.remove(charactersIn: "&=+#")
        return characters
    }()

    /// 文字形式，可以存进窗口恢复的状态，也可以由 `init?(string:)` 解析回来。
    var string: String {
        switch self {
        case .repositories:
            return Kind.repositories.rawValue

        case .repository(let location, let destination):
            let parameters = [("location", location.displayPath)] + destination.parameters

            let query = parameters
                .map { name, value in
                    name + "=" + (value.addingPercentEncoding(withAllowedCharacters: Self.allowed) ?? value)
                }
                .joined(separator: "&")

            return Kind.repository.rawValue + "?" + query
        }
    }

    /// 解析文字形式；种类、位置或视图无法识别，或视图缺少必需的参数时返回 nil。
    init?(string: String) {
        guard
            let components = URLComponents(string: string),
            let kind = Kind(rawValue: components.path)
        else { return nil }

        switch kind {
        case .repositories:
            self = .repositories

        case .repository:
            // 同名参数可以出现多次，如历史选中的多个引用
            let parameters = (components.queryItems ?? []).reduce(into: [String: [String]]()) { result, item in
                if let value = item.value {
                    result[item.name, default: []].append(value)
                }
            }

            guard
                let location = parameters["location"]?.first.flatMap(RepositoryLocation.init(displayPath:)),
                let destination = RepositoryDestination(parameters: parameters)
            else { return nil }

            self = .repository(location, destination)
        }
    }
}

// MARK: - RepositoryDestination

/// 仓库窗口里的一个主视图，以及重新打开它所需的选择。
enum RepositoryDestination: Hashable {
    /// 工作区。
    case workingCopy

    /// 历史；`references` 是侧边栏选中的完整引用名，按名称排序，空表示全部历史。
    case history(references: [String])

    /// 一个提交的整页详情，`commit` 是完整哈希。
    case commit(String)

    /// 储藏列表。
    case stashes

    /// 引用日志。
    case reflog

    /// 托管服务上的 Pull Request 或 Merge Request。
    case pullRequests

    /// 分支整理。
    case branchesReview

    /// 仓库设置。
    case settings

    /// 一个远端的设置与远端分支。
    case remote(String)

    /// 一个子模块的状态与配置，`path` 是它在仓库里的相对路径。
    case submodule(path: String)

    /// 一个工作树的详情，`path` 是它在仓库所在机器上的绝对路径。
    case worktree(path: String)

    /// 一个文件的历史。
    case fileHistory(path: String)

    /// 某个版本的文件原文或逐行追溯；`revision` 为 nil 时跟随 HEAD。
    case file(path: String, revision: String?, mode: FileContentMode)

    /// 文字形式里的视图名。
    private enum Name: String {
        /// 工作区。
        case workingCopy

        /// 历史。
        case history

        /// 提交整页详情。
        case commit

        /// 储藏。
        case stashes

        /// 引用日志。
        case reflog

        /// Pull Request 或 Merge Request。
        case pullRequests

        /// 分支整理。
        case branchesReview

        /// 仓库设置。
        case settings

        /// 远端设置。
        case remote

        /// 子模块。
        case submodule

        /// 工作树。
        case worktree

        /// 文件历史。
        case fileHistory

        /// 文件原文与逐行追溯。
        case file
    }

    /// 写进文字形式的参数，视图名在前。
    fileprivate var parameters: [(String, String)] {
        switch self {
        case .workingCopy:
            [("view", Name.workingCopy.rawValue)]

        case .history(let references):
            [("view", Name.history.rawValue)] + references.map { ("ref", $0) }

        case .commit(let commit):
            [("view", Name.commit.rawValue), ("commit", commit)]

        case .stashes:
            [("view", Name.stashes.rawValue)]

        case .reflog:
            [("view", Name.reflog.rawValue)]

        case .pullRequests:
            [("view", Name.pullRequests.rawValue)]

        case .branchesReview:
            [("view", Name.branchesReview.rawValue)]

        case .settings:
            [("view", Name.settings.rawValue)]

        case .remote(let name):
            [("view", Name.remote.rawValue), ("remote", name)]

        case .submodule(let path):
            [("view", Name.submodule.rawValue), ("path", path)]

        case .worktree(let path):
            [("view", Name.worktree.rawValue), ("path", path)]

        case .fileHistory(let path):
            [("view", Name.fileHistory.rawValue), ("path", path)]

        case .file(let path, let revision, let mode):
            [("view", Name.file.rawValue), ("path", path)]
                + (revision.map { [("revision", $0)] } ?? [])
                + [("mode", mode == .blame ? "blame" : "raw")]
        }
    }

    /// 从解析出的参数还原视图；视图名无法识别或缺少必需的参数时返回 nil。
    init?(parameters: [String: [String]]) {
        guard let name = parameters["view"]?.first.flatMap(Name.init(rawValue:)) else {
            return nil
        }

        let value: (String) -> String? = { key in
            parameters[key]?.first.flatMap { $0.isEmpty ? nil : $0 }
        }

        switch name {
        case .workingCopy:
            self = .workingCopy

        case .history:
            self = .history(references: (parameters["ref"] ?? []).filter { !$0.isEmpty }.sorted())

        case .commit:
            guard let commit = value("commit") else { return nil }
            self = .commit(commit)

        case .stashes:
            self = .stashes

        case .reflog:
            self = .reflog

        case .pullRequests:
            self = .pullRequests

        case .branchesReview:
            self = .branchesReview

        case .settings:
            self = .settings

        case .remote:
            guard let remote = value("remote") else { return nil }
            self = .remote(remote)

        case .submodule:
            guard let path = value("path") else { return nil }
            self = .submodule(path: path)

        case .worktree:
            guard let path = value("path") else { return nil }
            self = .worktree(path: path)

        case .fileHistory:
            guard let path = value("path") else { return nil }
            self = .fileHistory(path: path)

        case .file:
            guard let path = value("path") else { return nil }
            self = .file(path: path, revision: value("revision"), mode: value("mode") == "blame" ? .blame : .raw)
        }
    }
}

// MARK: - RepositoryLocation + Display Path

extension RepositoryLocation {
    /// 由 `displayPath` 的写法还原位置：以 `/` 开头的是本机绝对路径，其余按第一个 `:` 拆成主机别名与远端路径。
    ///
    /// 主机别名以 `-` 开头或含空白、`/` 时不接受：它会作为 ssh 的参数传出，不能被当成选项。
    init?(displayPath: String) {
        if displayPath.hasPrefix("/") {
            self = .local(path: displayPath)
            return
        }

        guard let separator = displayPath.firstIndex(of: ":") else {
            return nil
        }

        let host = String(displayPath[..<separator])
        let path = String(displayPath[displayPath.index(after: separator)...])

        guard
            !host.isEmpty, !path.isEmpty, !host.hasPrefix("-"),
            !host.contains(where: { $0.isWhitespace || $0 == "/" })
        else { return nil }

        self = .remote(host: host, path: path)
    }
}
