import Foundation
import SpookyKit

// MARK: - PullRequestTarget

/// 一个远端在托管服务上对应的账号与项目，或对应不上的原因。
enum PullRequestTarget: Equatable {
    /// 对应到账号与项目。
    case resolved(account: HostingAccount, project: String)

    /// 远端在已知的实例上，但还没有登录这个实例的账号。
    case noAccount(HostingInstance)

    /// 同一实例上有多个账号，需要选一个；带上候选与项目路径。
    case chooseAccount([HostingAccount], project: String)

    /// 远端地址不属于支持的托管服务，或别名、地址与实例不一致，需要手动关联。
    case unsupported

    /// 选中的远端对应的服务；对应不上时为 nil。
    var service: HostingService? {
        switch self {
        case .resolved(let account, _): account.instance.service
        case .noAccount(let instance): instance.service
        case .chooseAccount(let accounts, _): accounts.first?.instance.service
        case .unsupported: nil
        }
    }

    /// 按手动关联、已登录账号的实例与已知实例的顺序找出远端对应的账号与项目。
    ///
    /// - Parameters:
    ///   - remoteURL: 远端地址。
    ///   - accounts: 已登录的账号。
    ///   - associations: 手动关联与选定的账号。
    static func resolve(
        remoteURL: String,
        accounts: [HostingAccount],
        associations: [String: PullRequestAssociation]
    ) -> Self {
        // 手动关联优先，账号已被移除时当作没有关联
        if let association = associations[remoteURL], let account = accounts.first(where: { $0.id == association.account }) {
            guard let project = association.project ?? account.instance.projectPath(forRemote: remoteURL) else {
                return .unsupported
            }

            return .resolved(account: account, project: project)
        }

        // 地址属于某个已登录账号的实例
        let matches = accounts.compactMap { account in
            account.instance.projectPath(forRemote: remoteURL).map { (account, $0) }
        }

        if let (account, project) = matches.first {
            return matches.count == 1
                ? .resolved(account: account, project: project)
                : .chooseAccount(
                    matches.map(\.0),
                    project: project
                )
        }

        // 地址在 github.com 或 GitLab.com 上，只是还没有账号
        for instance in [HostingInstance.github, .gitlabCom] where instance.projectPath(forRemote: remoteURL) != nil {
            return .noAccount(instance)
        }

        return .unsupported
    }
}

// MARK: - PullRequestAssociation

/// 一个远端地址手动关联或选定的账号，以及手动填写的项目路径。
struct PullRequestAssociation: Codable, Equatable {
    /// 账号标识。
    var account: UUID

    /// 手动填写的项目路径；为 nil 时按账号的实例从地址推出。
    var project: String?
}

// MARK: - PullRequestAssociations

/// 远端地址到账号与项目的手动关联，存在偏好里，全部窗口共用。
enum PullRequestAssociations {
    /// 偏好键，值为远端地址到关联的 JSON。
    static let key = "hostingAssociations"

    /// 读出全部关联；内容损坏时视为没有关联。
    static func load(from defaults: UserDefaults = .standard) -> [String: PullRequestAssociation] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([String: PullRequestAssociation].self, from: $0) } ?? [:]
    }

    /// 保存或删除一个远端地址的关联。
    ///
    /// - Parameters:
    ///   - association: 新的关联；nil 表示删除。
    ///   - remoteURL: 远端地址。
    ///   - defaults: 存放关联的偏好。
    static func set(_ association: PullRequestAssociation?, for remoteURL: String, in defaults: UserDefaults = .standard) {
        var all = load(from: defaults)
        all[remoteURL] = association
        defaults.set(try? JSONEncoder().encode(all), forKey: key)
    }
}
