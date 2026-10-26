import Foundation

// MARK: - HostingOwner

/// 可以在其下新建仓库的所有者：账号本人，或 GitHub 的组织、GitLab 的 Group。
public struct HostingOwner: Sendable, Hashable, Identifiable {
    /// GitHub 是登录名，GitLab 是命名空间编号。
    public let id: String

    /// 显示与拼项目路径用的名字：GitHub 的登录名，GitLab 的完整命名空间路径。
    public let path: String

    /// 是账号本人。
    public let isUser: Bool

    /// 创建所有者；解析与测试使用。
    public init(id: String, path: String, isUser: Bool) {
        self.id = id
        self.path = path
        self.isUser = isUser
    }
}

// MARK: - HostingVisibility

/// 新仓库的可见性；`internal` 只有 GitLab 有。
public enum HostingVisibility: String, Sendable, Hashable, CaseIterable {
    /// 只有成员可见。
    case `private`

    /// 实例里登录的用户都可见。
    case `internal`

    /// 所有人可见。
    case `public`
}

// MARK: - HostingRepository

/// 新建好的远端仓库：项目路径、网页地址与两种克隆地址。
public struct HostingRepository: Sendable, Hashable {
    /// 项目路径，如 `owner/repo`。
    public let project: String

    /// 网页地址。
    public let webURL: URL?

    /// HTTPS 克隆地址。
    public let httpsURL: String

    /// SSH 克隆地址。
    public let sshURL: String

    /// 创建仓库描述；解析与测试使用。
    public init(project: String, webURL: URL?, httpsURL: String, sshURL: String) {
        self.project = project
        self.webURL = webURL
        self.httpsURL = httpsURL
        self.sshURL = sshURL
    }
}

// MARK: - Repositories

extension HostingClient {
    /// 可以在其下新建仓库的所有者：账号本人在前，其后是 GitHub 的组织或 GitLab 的 Group。
    public func owners() async throws -> [HostingOwner] {
        switch instance.service {
        case .github:
            let user = try await currentUser()
            let organizations: HostingResponse<[GitHubOrganization]> = try await send(
                "GET",
                "user/orgs",
                query: [URLQueryItem(name: "per_page", value: "100")]
            )

            return [HostingOwner(id: user.username, path: user.username, isUser: true)]
                + organizations.value.map { HostingOwner(id: $0.login, path: $0.login, isUser: false) }

        case .gitlab:
            let namespaces: HostingResponse<[GitLabNamespace]> = try await send(
                "GET",
                "namespaces",
                query: [URLQueryItem(name: "per_page", value: "100")]
            )

            return namespaces.value
                .map { HostingOwner(id: String($0.id), path: $0.fullPath, isUser: $0.kind == "user") }
                .sorted { $0.isUser && !$1.isUser }
        }
    }

    /// 项目是否已经存在；看不到的项目同样按不存在处理。
    ///
    /// - Parameter project: 项目路径，如 `owner/repo`。
    public func repositoryExists(_ project: String) async throws -> Bool {
        let path = instance.service == .github ? Self.githubRepository(project) : Self.gitlabProject(project)

        do {
            try await perform("GET", path)
            return true
        } catch HostingError.notFound {
            return false
        }
    }

    /// 新建空的远端仓库。
    ///
    /// - Parameters:
    ///   - name: 仓库名。
    ///   - description: 描述。
    ///   - visibility: 可见性；GitHub 没有 `internal`，按私有处理。
    ///   - owner: 所有者。
    public func createRepository(
        named name: String,
        description: String,
        visibility: HostingVisibility,
        owner: HostingOwner
    ) async throws -> HostingRepository {
        switch instance.service {
        case .github:
            let payload = try JSONEncoder().encode(
                GitHubNewRepository(name: name, description: description, private: visibility != .public)
            )
            let path = owner.isUser ? "user/repos" : "orgs/" + Self.encodedSegment(owner.id) + "/repos"
            let created: HostingResponse<GitHubCreatedRepository> = try await send("POST", path, body: payload)
            let value = created.value

            return HostingRepository(
                project: value.fullName,
                webURL: value.htmlURL,
                httpsURL: value.cloneURL,
                sshURL: value.sshURL
            )

        case .gitlab:
            let payload = try JSONEncoder().encode(
                GitLabNewProject(
                    name: name,
                    path: name,
                    namespaceID: Int(owner.id) ?? 0,
                    description: description,
                    visibility: visibility.rawValue
                )
            )
            let created: HostingResponse<GitLabCreatedProject> = try await send("POST", "projects", body: payload)
            let value = created.value

            return HostingRepository(
                project: value.pathWithNamespace,
                webURL: value.webURL,
                httpsURL: value.httpURLToRepo,
                sshURL: value.sshURLToRepo
            )
        }
    }
}

// MARK: - GitHubOrganization

/// GitHub 的组织。
private struct GitHubOrganization: Decodable, Sendable {
    /// 登录名。
    let login: String
}

// MARK: - GitHubNewRepository

/// GitHub 新仓库的请求体。
private struct GitHubNewRepository: Encodable, Sendable {
    /// 仓库名。
    let name: String

    /// 描述。
    let description: String

    /// 私有。
    let `private`: Bool
}

// MARK: - GitHubCreatedRepository

/// GitHub 建好的仓库。
private struct GitHubCreatedRepository: Decodable, Sendable {
    /// 字段名：解码器先把蛇形字段转成驼峰，`html_url` 转成 `htmlUrl`。
    private enum CodingKeys: String, CodingKey {
        case fullName
        case htmlURL = "htmlUrl"
        case cloneURL = "cloneUrl"
        case sshURL = "sshUrl"
    }

    /// `owner/repo`。
    let fullName: String

    /// 网页地址。
    let htmlURL: URL?

    /// HTTPS 克隆地址。
    let cloneURL: String

    /// SSH 克隆地址。
    let sshURL: String
}

// MARK: - GitLabNamespace

/// GitLab 的命名空间。
private struct GitLabNamespace: Decodable, Sendable {
    /// 编号。
    let id: Int

    /// 完整路径。
    let fullPath: String

    /// `user` 或 `group`。
    let kind: String
}

// MARK: - GitLabNewProject

/// GitLab 新项目的请求体。
private struct GitLabNewProject: Encodable, Sendable {
    /// 字段名：请求体用蛇形写法。
    private enum CodingKeys: String, CodingKey {
        case name, path, description, visibility
        case namespaceID = "namespace_id"
    }

    /// 项目名。
    let name: String

    /// 项目路径。
    let path: String

    /// 命名空间编号。
    let namespaceID: Int

    /// 描述。
    let description: String

    /// 可见性。
    let visibility: String
}

// MARK: - GitLabCreatedProject

/// GitLab 建好的项目。
private struct GitLabCreatedProject: Decodable, Sendable {
    /// 字段名：解码器先把蛇形字段转成驼峰，`web_url` 转成 `webUrl`。
    private enum CodingKeys: String, CodingKey {
        case pathWithNamespace
        case webURL = "webUrl"
        case httpURLToRepo = "httpUrlToRepo"
        case sshURLToRepo = "sshUrlToRepo"
    }

    /// 完整路径。
    let pathWithNamespace: String

    /// 网页地址。
    let webURL: URL?

    /// HTTPS 克隆地址。
    let httpURLToRepo: String

    /// SSH 克隆地址。
    let sshURLToRepo: String
}
