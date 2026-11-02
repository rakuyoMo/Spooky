import Foundation
import SpookyKit

// MARK: - AccountGitCredentials

/// 用托管账号的令牌回答 Git 的凭据请求：HTTPS 远端属于已登录的账号时，Git 用账号的令牌认证，不询问用户名与密码。
///
/// 远端属于哪个账号沿用 Pull Request 的对应：先看手动关联，再按账号的实例匹配；同一实例几个账号又没有关联时不回答。
/// Git 拒绝了令牌之后，这个账号的远端回到询问，直到重新认证或移除账号。
@MainActor
final class AccountGitCredentials {
    /// App 共用的实例。
    static let shared = AccountGitCredentials()

    /// 最多记住的回答条数，足够覆盖同时进行的网络操作。
    private static let answerLimit = 64

    /// 已登录的账号。
    private let accounts: HostingAccounts

    /// 存放手动关联的偏好。
    private let defaults: UserDefaults

    /// 最近用账号令牌回答过的请求；Git 为同一操作与地址发来 `erase` 时，说明这个账号的令牌被拒了。
    private var answers: [Answer] = []

    /// 偏好变化的订阅：账号列表与手动关联都存在偏好里。
    private var observer: (any NSObjectProtocol)? = nil

    /// 创建回答者。
    ///
    /// - Parameters:
    ///   - accounts: 已登录的账号。
    ///   - defaults: 存放手动关联的偏好。
    init(accounts: HostingAccounts = .shared, defaults: UserDefaults = .standard) {
        self.accounts = accounts
        self.defaults = defaults
    }

    /// App 启动时把地址前缀交给核心库，之后账号或手动关联变化时重新交出。
    func start() {
        GitCredentialScopes.current = scopes()

        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }

                GitCredentialScopes.current = self.scopes()
            }
        }
    }

    /// 交给 Spooky 回答凭据的地址前缀：各账号实例的网页地址，加上关联到已登录账号的远端地址去掉用户名；只取 HTTPS，去重。
    func scopes() -> [String] {
        let items = accounts.items
        let instances = items.map(\.instance.webURL.absoluteString)

        let remotes = PullRequestAssociations.load(from: defaults)
            .filter { association in items.contains { $0.id == association.value.account } }
            .keys
            .sorted()
            .compactMap(Self.withoutCredentials)

        var seen = Set<String>()
        return (instances + remotes).filter { Self.isHTTPS($0) && seen.insert($0).inserted }
    }

    /// 回答一条凭据助手的请求：`get` 用账号令牌回答，`erase` 对照之前的回答记下令牌被拒。
    ///
    /// 不管发起的操作能否询问用户都回答，自动获取同样用账号令牌；对不上账号时为 nil，Git 接着问 askpass。
    func respond(to request: RemoteCallbackRequest) async -> String? {
        guard let address = request.content, Self.isHTTPS(address) else {
            return nil
        }

        switch request.prompt {
        case "get":
            return await answer(address, operation: request.operation)

        case "erase":
            reject(address, operation: request.operation)
            return ""

        default:
            return nil
        }
    }

    /// 地址对应的账号：先看手动关联，再按账号的实例匹配；同一实例几个账号又没有关联时为 nil。
    ///
    /// - Parameter address: 远端地址，可以带用户名。
    func account(for address: String) -> HostingAccount? {
        let items = accounts.items

        // 关联的键是远端地址原文：两边都去掉用户名、结尾的 “/” 与 “.git”，主机不分大小写
        if
            let key = Self.normalized(address),
            let association = PullRequestAssociations.load(from: defaults)
                .sorted(by: { $0.key < $1.key })
                .first(where: { Self.normalized($0.key) == key }),
            let account = items.first(where: { $0.id == association.value.account })
        {
            return account
        }

        let target = PullRequestTarget.resolve(remoteURL: address, accounts: items, associations: [:])

        guard case .resolved(let account, _) = target else {
            return nil
        }

        return account
    }

    /// askpass 提示里的地址属于 Git 拒绝过令牌的账号时，返回这个账号。
    ///
    /// - Parameter prompt: Git 的提示，如 `Username for 'https://example.com/owner/repo.git': `。
    func rejectedAccount(forPrompt prompt: String) -> HostingAccount? {
        guard
            let start = prompt.firstIndex(of: "'"),
            let end = prompt.lastIndex(of: "'"),
            start < end,
            let account = account(for: String(prompt[prompt.index(after: start) ..< end]))
        else {
            return nil
        }

        return accounts.gitRejectedAccounts.contains(account.id) ? account : nil
    }

    /// 用账号令牌回答 `get`，并记下这次回答，供之后的 `erase` 对照。
    private func answer(_ address: String, operation: String) async -> String? {
        guard
            let account = account(for: address),
            !account.needsReauthentication,
            !accounts.gitRejectedAccounts.contains(account.id),
            let token = try? await accounts.token(for: account)
        else {
            return nil
        }

        // 用户名与密码登录换来的 OAuth 令牌配用户名 oauth2，其余令牌当密码用、配账号的用户名
        let username = account.authentication == .password ? "oauth2" : account.username

        // 凭据助手协议按行分隔，带换行的值会改写别的字段
        guard !(username + token).contains(where: \.isNewline) else {
            return nil
        }

        answers.append(Answer(operation: operation, address: address, account: account.id))
        answers.removeFirst(max(0, answers.count - Self.answerLimit))

        return "username=\(username)\npassword=\(token)\n"
    }

    /// Git 为刚用账号令牌回答过的同一操作与地址发来 `erase`：令牌没能通过认证，标记这个账号。
    private func reject(_ address: String, operation: String) {
        guard let index = answers.lastIndex(where: { $0.operation == operation && $0.address == address }) else {
            return
        }

        let answer = answers.remove(at: index)

        guard let account = accounts.items.first(where: { $0.id == answer.account }) else {
            return
        }

        accounts.markGitTokenRejected(account)
    }
}

// MARK: AccountGitCredentials.Answer

extension AccountGitCredentials {
    /// 一次用账号令牌的回答：发起请求的操作、请求的地址与回答所用的账号。
    private struct Answer {
        /// 发起请求的 Git 操作标识。
        let operation: String

        /// 请求的地址。
        let address: String

        /// 回答所用的账号标识。
        let account: UUID
    }
}

// MARK: - Helpers

extension AccountGitCredentials {
    /// 地址是 HTTPS：账号令牌只交给 HTTPS 地址。
    private static func isHTTPS(_ address: String) -> Bool {
        address.lowercased().hasPrefix("https://")
    }

    /// 去掉地址里的用户名与口令；解析不了时为 nil。
    private static func withoutCredentials(_ address: String) -> String? {
        guard var components = URLComponents(string: address) else {
            return nil
        }

        components.user = nil
        components.password = nil
        return components.string
    }

    /// 比较用的地址：去掉用户名、口令、结尾的 “/” 与 “.git”，主机转小写；不是 HTTPS 地址时为 nil。
    private static func normalized(_ address: String) -> String? {
        guard
            isHTTPS(address),
            let url = RemoteConfiguration.webURL(for: address),
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        components.host = components.host?.lowercased()
        return components.string
    }
}
