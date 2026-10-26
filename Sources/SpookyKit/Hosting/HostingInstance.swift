import Foundation

// MARK: - HostingService

/// 支持的托管服务：github.com 用 Pull Request，GitLab.com 与私有部署的 GitLab 用 Merge Request。
public enum HostingService: String, Codable, Sendable, CaseIterable {
    /// github.com。
    case github

    /// GitLab.com 或私有部署的 GitLab。
    case gitlab
}

// MARK: - HostingInstance

/// 托管服务的一个实例：github.com、GitLab.com 或一个私有部署的 GitLab；API 地址与网页链接都由网页地址推出。
public struct HostingInstance: Codable, Sendable, Hashable {
    /// github.com。
    // swiftlint:disable:next force_unwrapping
    public static let github = Self(service: .github, webURL: URL(string: "https://github.com")!)

    /// GitLab.com。
    // swiftlint:disable:next force_unwrapping
    public static let gitlabCom = Self(service: .gitlab, webURL: URL(string: "https://gitlab.com")!)

    /// github.com 的 REST API 根地址。
    // swiftlint:disable:next force_unwrapping
    private static let githubAPI = URL(string: "https://api.github.com")!

    /// 所属的服务。
    public let service: HostingService

    /// 网页地址：协议、主机、端口与部署路径，末尾不带 “/”，如 `https://git.example.com:8443/gitlab`。
    public let webURL: URL

    /// REST API 的根地址：github.com 是 `https://api.github.com`，GitLab 是网页地址后加 `/api/v4`。
    public var apiURL: URL {
        switch service {
        case .github: Self.githubAPI
        case .gitlab: webURL.appending(path: "api/v4")
        }
    }

    /// 列表与说明里显示的地址：主机，加上非默认的端口与部署路径。
    public var displayName: String {
        let host = webURL.host() ?? ""
        let port = webURL.port.map { ":\($0)" } ?? ""
        return host + port + webURL.path(percentEncoded: false)
    }

    /// 是私有部署的 GitLab。
    public var isSelfManaged: Bool {
        service == .gitlab && self != .gitlabCom
    }

    /// 创建实例；只在已知网页地址时使用，用户输入的地址经 ``gitlab(address:)`` 解析。
    public init(service: HostingService, webURL: URL) {
        self.service = service
        self.webURL = webURL
    }

    /// 解析私有部署 GitLab 的地址：只接受 http 与 https，可以带端口与部署路径；去掉末尾的 “/”、查询与片段。
    ///
    /// - Parameter address: 用户输入的地址，如 `https://git.example.com:8443/gitlab/`。
    /// - Returns: 地址不合法时为 nil。
    public static func gitlab(address: String) -> Self? {
        guard
            var components = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil
        else {
            return nil
        }

        var path = components.path

        while path.hasSuffix("/") {
            path.removeLast()
        }

        components.scheme = scheme
        components.host = host.lowercased()
        components.path = path
        components.query = nil
        components.fragment = nil

        return components.url.map { Self(service: .gitlab, webURL: $0) }
    }

    /// 远端地址在这个实例上的项目路径，如 `owner/repo` 或 `group/subgroup/project`；地址不属于这个实例时为 nil。
    ///
    /// HTTP(S) 地址的主机、端口与部署路径都要相同；SSH 与 scp 写法只比主机，路径里本来就没有部署路径。
    /// github.com 的项目是两段，GitLab 至少两段，组可以多层。
    ///
    /// - Parameter remoteURL: `remote.<名称>.url` 的值。
    public func projectPath(forRemote remoteURL: String) -> String? {
        guard let remote = RemoteConfiguration.webURL(for: remoteURL), let host = remote.host()?.lowercased() else {
            return nil
        }

        let isHTTP = remoteURL.lowercased().hasPrefix("http://") || remoteURL.lowercased().hasPrefix("https://")
        let instanceHost = webURL.host()?.lowercased()

        // github.com 的 SSH 也可以经 ssh.github.com 的 443 端口连接
        let sameHost = host == instanceHost || (service == .github && !isHTTP && host == "ssh.github.com")

        guard sameHost else {
            return nil
        }

        var path = remote.path(percentEncoded: false).split(separator: "/").joined(separator: "/")
        let prefix = webURL.path(percentEncoded: false).split(separator: "/").joined(separator: "/")

        if isHTTP {
            guard Self.port(of: remote) == Self.port(of: webURL) else {
                return nil
            }

            // HTTP(S) 地址里带着部署路径，项目路径在它之后
            if !prefix.isEmpty {
                guard path.hasPrefix(prefix + "/") else {
                    return nil
                }

                path.removeFirst(prefix.count + 1)
            }
        }

        let segments = path.split(separator: "/")

        switch service {
        case .github:
            return segments.count == 2 ? path : nil

        case .gitlab:
            return segments.count >= 2 ? path : nil
        }
    }
}

// MARK: - Private

extension HostingInstance {
    /// 地址的端口；没有写出时按协议取默认端口。
    private static func port(of url: URL) -> Int? {
        url.port ?? (url.scheme?.lowercased() == "http" ? 80 : 443)
    }
}
