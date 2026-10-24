import Foundation

// MARK: - RemoteConfiguration

/// 一个远端在 Git 配置里的设置：地址、refspec 与自动获取排除项。
public struct RemoteConfiguration: Sendable, Equatable, Identifiable {
    /// 远端名。
    public let name: String

    /// `remote.<名称>.url` 的全部值；获取用第一个。
    public var urls: [String] = []

    /// `remote.<名称>.pushurl` 的全部值；为空时推送也用获取地址。
    public var pushURLs: [String] = []

    /// 获取用的 refspec，按配置顺序。
    public var fetchRefspecs: [String] = []

    /// 推送用的 refspec，按配置顺序。
    public var pushRefspecs: [String] = []

    /// `remote.<名称>.skipFetchAll`：自动获取与获取全部远端时跳过这个远端。
    public var skipsFetchAll = false

    /// 以远端名作身份。
    public var id: String { name }

    /// 获取地址。
    public var url: String? { urls.first }

    /// 推送实际使用的地址：有推送地址时用它，否则用获取地址。
    public var effectivePushURL: String? { pushURLs.first ?? urls.first }

    /// 在浏览器中打开的网页地址；获取地址换算不出时为 nil。
    public var webURL: URL? { url.flatMap(Self.webURL(for:)) }

    /// 创建一份只有名字的配置，其余设置为空。
    public init(name: String) {
        self.name = name
    }

    /// 解析 `config -z --get-regexp ^remote\.` 的记录：每条是键、换行、值，没有值的键只有键本身。
    ///
    /// 键的第一个点与最后一个点之间是远端名，远端名本身可以含点；结果按远端名排序。
    static func parse(_ data: Data) throws -> [Self] {
        var result: [String: Self] = [:]

        for record in data.split(separator: 0) {
            let key = String(decoding: record.prefix { $0 != 10 }, as: UTF8.self)
            let value = record.firstIndex(of: 10).map { String(decoding: record[($0 + 1)...], as: UTF8.self) }

            guard
                key.hasPrefix("remote."),
                let last = key.lastIndex(of: "."),
                last > key.index(key.startIndex, offsetBy: 6)
            else {
                throw RepositoryReadError.malformedOutput("remote config")
            }

            let name = String(key[key.index(key.startIndex, offsetBy: 7) ..< last])
            var remote = result[name] ?? Self(name: name)

            // 变量名不分大小写，Git 输出时已转成小写；不认识的变量只保留远端名
            switch key[key.index(after: last)...].lowercased() {
            case "url":
                remote.urls += value.map { [$0] } ?? []

            case "pushurl":
                remote.pushURLs += value.map { [$0] } ?? []

            case "fetch":
                remote.fetchRefspecs += value.map { [$0] } ?? []

            case "push":
                remote.pushRefspecs += value.map { [$0] } ?? []

            case "skipfetchall":
                remote.skipsFetchAll = BranchMetadata.isTrue(value)

            default:
                break
            }

            result[name] = remote
        }

        return result.values.sorted { $0.name < $1.name }
    }

    /// 由远端地址换算网页地址：HTTP(S) 保留协议与端口，SSH、git 协议与 scp 写法换成 HTTPS 并去掉端口；
    /// 用户名、口令、末尾的 “/” 与 “.git” 都去掉。本机路径、`file://` 与其它协议换算不出，返回 nil。
    public static func webURL(for remoteURL: String) -> URL? {
        var components = URLComponents()
        let value = remoteURL.trimmingCharacters(in: .whitespaces)
        var path: String

        if value.contains("://") {
            guard
                let parsed = URLComponents(string: value),
                let scheme = parsed.scheme?.lowercased(),
                let host = parsed.host,
                !host.isEmpty
            else {
                return nil
            }

            switch scheme {
            case "http", "https":
                components.scheme = scheme
                components.port = parsed.port

            case "ssh", "git", "git+ssh", "ssh+git":
                components.scheme = "https"

            default:
                return nil
            }

            components.host = host
            path = parsed.path
        } else if let scp = scpParts(of: value) {
            components.scheme = "https"
            components.host = scp.host
            path = "/" + scp.path.drop { $0 == "/" }
        } else {
            return nil
        }

        while path.hasSuffix("/") {
            path.removeLast()
        }

        if path.lowercased().hasSuffix(".git") {
            path.removeLast(4)
        }

        guard path.count > 1 else {
            return nil
        }

        components.path = path
        return components.url
    }

    /// scp 写法 `[用户@]主机:路径` 的主机与路径；冒号前含 “/” 的是本机路径，不是 scp 写法。
    private static func scpParts(of value: String) -> (host: String, path: String)? {
        guard let colon = value.firstIndex(of: ":") else {
            return nil
        }

        let authority = value[..<colon]
        let path = String(value[value.index(after: colon)...])
        let host = authority.split(separator: "@", omittingEmptySubsequences: false).last.map(String.init) ?? ""

        guard !host.isEmpty, !authority.contains("/"), !path.isEmpty else {
            return nil
        }

        return (host, path)
    }
}

// MARK: - RepositoryRemotes

/// 远端的增删改名、地址、refspec 与自动获取排除项；配置只写仓库自己的 `.git/config`。
public struct RepositoryRemotes: Sendable {
    /// 本机与服务器使用相同参数协议。
    public let runner: GitRunner

    /// 创建远端服务，不执行隐式操作。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 一次读取全部远端的设置；没有远端时为空。
    public func configurations() async throws -> [RemoteConfiguration] {
        let result = try await runner.execute(
            ["config", "-z", "--get-regexp", "^remote\\."],
            acceptedExitCodes: [0, 1]
        )

        return try RemoteConfiguration.parse(result.standardOutput)
    }

    /// 确认地址能连上并通过认证：列一次远端分支，凭据经回调询问；服务器仓库在服务器上连接。
    public func checkConnection(
        to url: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try RepositoryReferences.validate(url: url)
        _ = try await runner.execute(["ls-remote", "--heads", "--", url], onOutput: onOutput)
    }

    /// 先确认地址能连上，再添加远端；不获取远端分支。
    public func add(
        name: String,
        url: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            try await RepositoryReferences(runner: runner).validate(remote: name)
            try await checkConnection(to: url, onOutput: onOutput)
            _ = try await runner.run(["remote", "add", "--", name, url])
        }
    }

    /// 删除远端：Git 一并删除它的远端跟踪分支，以及本地分支对它的跟踪设置。
    public func remove(_ name: String) async throws {
        guard !name.isEmpty else {
            throw RepositoryReadError.invalidQuery
        }

        _ = try await runner.run(["remote", "remove", "--", name])
    }

    /// 重命名远端，远端跟踪分支与本地分支的跟踪设置随之改名。
    ///
    /// 只差大小写时经一个临时名字中转两次：引用以文件保存时，大小写不敏感的文件系统会把新旧名字当成同一个目录。
    public func rename(_ name: String, to newName: String) async throws {
        try await runner.writeTransaction {
            try await RepositoryReferences(runner: runner).validate(remote: newName)

            guard name.lowercased() == newName.lowercased(), name != newName else {
                _ = try await runner.run(["remote", "rename", "--", name, newName])
                return
            }

            let temporary = newName + "-" + UUID().uuidString.lowercased()
            _ = try await runner.run(["remote", "rename", "--", name, temporary])
            _ = try await runner.run(["remote", "rename", "--", temporary, newName])
        }
    }

    /// 修改获取地址或推送地址；先确认新地址能连上。
    ///
    /// - Parameter push: 为 true 时写 `pushurl`，否则写 `url`；多个值一并换成这一个。
    public func setURL(
        _ url: String,
        of name: String,
        push: Bool,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            try await RepositoryReferences(runner: runner).validate(remote: name)
            try await checkConnection(to: url, onOutput: onOutput)
            _ = try await runner.run(["config", "--local", "--replace-all", key(name, push ? "pushurl" : "url"), url])
        }
    }

    /// 删除推送地址，此后推送用获取地址。
    public func unsetPushURL(of name: String) async throws {
        try await unset(key(name, "pushurl"))
    }

    /// 添加一条 refspec，排在已有的之后。
    public func addRefspec(_ refspec: String, to name: String, push: Bool) async throws {
        try await runner.writeTransaction {
            try await RepositoryReferences(runner: runner).validate(refspec: refspec, push: push)
            _ = try await runner.run(["config", "--local", "--add", key(name, push ? "push" : "fetch"), refspec])
        }
    }

    /// 把一条 refspec 换成新值；按原值精确匹配，同名远端的其它 refspec 不动。
    public func replaceRefspec(_ refspec: String, with newValue: String, in name: String, push: Bool) async throws {
        try await runner.writeTransaction {
            try await RepositoryReferences(runner: runner).validate(refspec: newValue, push: push)
            _ = try await runner.run([
                "config", "--local", "--fixed-value", "--replace-all", key(name, push ? "push" : "fetch"), newValue,
                refspec,
            ])
        }
    }

    /// 删除一条 refspec；按原值精确匹配。
    public func removeRefspec(_ refspec: String, from name: String, push: Bool) async throws {
        _ = try await runner.execute(
            ["config", "--local", "--fixed-value", "--unset-all", key(name, push ? "push" : "fetch"), refspec],
            acceptedExitCodes: [0, 5]
        )
    }

    /// 设置自动获取与获取全部远端时是否跳过这个远端；不跳过时删除这个键。
    public func setSkipsFetchAll(_ skips: Bool, for name: String) async throws {
        guard skips else {
            try await unset(key(name, "skipFetchAll"))
            return
        }

        _ = try await runner.run(["config", "--local", "--bool", key(name, "skipFetchAll"), "true"])
    }

    /// 远端配置键 `remote.<名称>.<变量>`。
    private func key(_ name: String, _ variable: String) -> String {
        "remote." + name + "." + variable
    }

    /// 键本来就不存在时 Git 以 5 退出，结果与删除成功相同。
    private func unset(_ key: String) async throws {
        _ = try await runner.execute(["config", "--local", "--unset-all", key], acceptedExitCodes: [0, 5])
    }
}
