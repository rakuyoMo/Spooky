import Foundation
import SpookyKit

// MARK: - SpookyURL

/// App 接收的链接：打开仓库并切到某个视图、提交或分支，或者打开克隆对话框。
///
/// - `spooky://open?repository=<位置>[&view=…][&commit=<哈希>][&branch=<分支>]`：位置是本机绝对路径，或 `<主机别名>:<远端路径>`；
///   `view` 取 `workingCopy`、`history`、`stashes`、`reflog`、`branchesReview`，另可带 `ref`、`remote`、`path`、`revision`、`mode`，
///   与窗口恢复的视图引用相同
/// - `spooky://clone?url=<远端地址>`
/// - github.com 的 “Open with Desktop” 链接 `x-github-client://openRepo/<仓库网址>` 与 `github-mac://openRepo/<仓库网址>`：
///   只接受 github.com 的 https 仓库网址，打开克隆对话框
///
/// 解析不出、参数不全或地址不可信的链接为 nil，App 只显示错误、不执行任何动作。
enum SpookyURL: Equatable {
    /// 打开仓库；视图为 nil 时显示仓库保存的视图状态。
    case open(RepositoryLocation, RepositoryDestination?)

    /// 打开克隆对话框，预填远端地址。
    case clone(String)

    /// App 自己的链接协议。
    static let scheme = "spooky"

    /// github.com 的 “Open with Desktop” 链接使用的两个协议。
    static let githubSchemes = ["x-github-client", "github-mac"]

    /// 解析链接；不认识或不可信时返回 nil。
    init?(_ url: URL) {
        guard let scheme = url.scheme?.lowercased() else {
            return nil
        }

        if Self.githubSchemes.contains(scheme) {
            guard let clone = Self.githubRepository(in: url) else { return nil }
            self = .clone(clone)
            return
        }

        guard scheme == Self.scheme, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        // 同名参数只取第一个；ref 可以出现多次，按视图引用的规则收集
        var parameters: [String: [String]] = [:]

        for item in components.queryItems ?? [] {
            if let value = item.value {
                parameters[item.name, default: []].append(value)
            }
        }

        switch components.host {
        case "open":
            guard let request = Self.open(parameters) else { return nil }
            self = request

        case "clone":
            guard let url = parameters["url"]?.first, (try? RepositoryReferences.validate(url: url)) != nil else {
                return nil
            }

            self = .clone(url)

        default:
            return nil
        }
    }
}

// MARK: - Private

extension SpookyURL {
    /// `open` 的参数：位置必填，`branch` 与 `commit` 是视图引用的简写。
    private static func open(_ parameters: [String: [String]]) -> Self? {
        guard let location = parameters["repository"]?.first.flatMap(RepositoryLocation.init(displayPath:)) else {
            return nil
        }

        var view = parameters

        if let branch = parameters["branch"]?.first {
            view["view"] = ["history"]
            view["ref"] = ["refs/heads/" + branch]
        } else if let commit = parameters["commit"]?.first {
            view["view"] = ["commit"]
            view["commit"] = [commit]
        }

        // 没有视图时打开仓库保存的视图状态；写了视图但不认识时整个链接无效
        guard view["view"] != nil else {
            return .open(location, nil)
        }

        guard let destination = RepositoryDestination(parameters: view) else {
            return nil
        }

        return .open(location, destination)
    }

    /// “Open with Desktop” 链接里的仓库网址：只接受 github.com 上 `/<所有者>/<仓库>` 形式的 https 网址，返回它的克隆地址。
    private static func githubRepository(in url: URL) -> String? {
        let text = url.absoluteString
        let prefix = (url.scheme ?? "") + "://openRepo/"

        guard
            text.lowercased().hasPrefix(prefix.lowercased()),
            let repository = URLComponents(string: String(text.dropFirst(prefix.count))),
            repository.scheme == "https",
            repository.host?.lowercased() == "github.com"
        else {
            return nil
        }

        let segments = repository.path.split(separator: "/").map(String.init)

        guard segments.count == 2, segments.allSatisfy({ !$0.hasPrefix(".") && !$0.hasPrefix("-") }) else {
            return nil
        }

        let name = segments[1].hasSuffix(".git") ? String(segments[1].dropLast(4)) : segments[1]
        return "https://github.com/" + segments[0] + "/" + name + ".git"
    }
}
