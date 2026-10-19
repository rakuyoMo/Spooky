import Foundation

/// 相对指定上游的双向提交数量。
public struct ReferenceDivergence: Sendable, Equatable {
    /// 本地独有的提交数。
    public let ahead: Int

    /// 上游独有的提交数。
    public let behind: Int

    /// 只接受 rev-list 的两个非负整数，不解析 branch 的人读文字。
    static func parse(_ data: Data) throws -> Self {
        let fields = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isWhitespace)
        guard fields.count == 2, let ahead = Int(fields[0]), let behind = Int(fields[1]), ahead >= 0,
            behind >= 0
        else {
            throw RepositoryReadError.malformedOutput("rev-list")
        }
        return Self(ahead: ahead, behind: behind)
    }
}

/// 同一次 for-each-ref 快照中的引用。
public struct RepositoryReference: Sendable, Equatable, Identifiable {
    /// 完整引用名，操作不使用有歧义的缩写。
    public let id: String

    /// 已剥离附注标签的目标对象。
    public let objectID: String

    /// 目标对象类型，历史只读取提交。
    public let objectType: String

    /// Git 按 fetch refspec 换算出的上游引用。
    public let upstream: String?

    /// 上游所在远端；本机跟踪使用点号。
    public let upstreamRemote: String?

    /// 上游在目标远端上的完整引用名。
    public let upstreamBranch: String?

    /// 符号引用的目标，用于远端 HEAD。
    public let symbolicTarget: String?

    /// 引用是否为本地分支。
    public var isLocal: Bool { id.hasPrefix("refs/heads/") }

    /// 引用是否为远端跟踪分支。
    public var isRemote: Bool { id.hasPrefix("refs/remotes/") }

    /// 供界面展示的名称，保留远端前缀。
    public var name: String {
        for prefix in ["refs/heads/", "refs/remotes/", "refs/tags/"] where id.hasPrefix(prefix) {
            return String(id.dropFirst(prefix.count))
        }
        return id
    }

    /// 解析固定 NUL 字段，仅移除 Git 在记录间额外插入的一个换行。
    static func parse(_ data: Data) throws -> [Self] {
        guard !data.isEmpty else { return [] }
        let fields = data.split(separator: 0, omittingEmptySubsequences: false)
        guard fields.count % 9 == 1, fields.last == Data([10]) else {
            throw RepositoryReadError.malformedOutput("for-each-ref")
        }

        return try stride(from: 0, to: fields.count - 1, by: 9)
            .map { start in
                var values = fields[start..<(start + 9)].map { String(decoding: $0, as: UTF8.self) }
                if start > 0, values[0].hasPrefix("\n") { values[0].removeFirst() }
                guard values[0].hasPrefix("refs/"), GitObjectID.isValid(values[1]),
                    values[3].isEmpty || GitObjectID.isValid(values[3])
                else {
                    throw RepositoryReadError.malformedOutput("for-each-ref")
                }

                return Self(
                    id: values[0],
                    objectID: values[3].isEmpty ? values[1] : values[3],
                    objectType: values[4].isEmpty ? values[2] : values[4],
                    upstream: values[5].isEmpty ? nil : values[5],
                    upstreamRemote: values[6].isEmpty ? nil : values[6],
                    upstreamBranch: values[7].isEmpty ? nil : values[7],
                    symbolicTarget: values[8].isEmpty ? nil : values[8]
                )
            }
    }
}

/// 配置远端的名称及其分支归属，不额外访问服务器的仓库列表。
public struct RepositoryRemote: Sendable, Equatable, Identifiable {
    /// Git 配置中的远端名。
    public let name: String

    /// 默认 fetch 布局的分组身份。
    public var id: String { name }
}

/// 一致读取的引用与远端名单。
public struct ReferenceSnapshot: Sendable, Equatable {
    /// 本地、远端与标签引用；标签用于历史标记。
    public let references: [RepositoryReference]

    /// 即使尚未 Fetch，空远端也保留分组。
    public let remotes: [RepositoryRemote]

    /// 用最长前缀匹配带斜杠的远端名。
    public func remote(for reference: RepositoryReference) -> RepositoryRemote? {
        remotes.filter { reference.id.hasPrefix("refs/remotes/" + $0.name + "/") }
            .max { $0.name.count < $1.name.count }
    }

    /// 远端默认分支只取本地符号引用，不猜测 main 或 master。
    public func defaultBranch(for remote: RepositoryRemote) -> String? {
        references.first { $0.id == "refs/remotes/" + remote.name + "/HEAD" }?.symbolicTarget
    }
}

/// 引用读写的业务边界，名称校验和写入都经过统一 Git 执行器。
public struct RepositoryReferences: Sendable {
    /// 本机与服务器使用相同参数协议。
    public let runner: GitRunner

    /// 创建引用服务，不执行隐式操作。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 一次读取全部引用，另一次读取远端名字，空仓库也是合法快照。
    public func snapshot() async throws -> ReferenceSnapshot {
        async let refs = runner.run([
            "for-each-ref", "--sort=refname",
            "--format=%(refname)%00%(objectname)%00%(objecttype)%00%(*objectname)%00%(*objecttype)%00%(upstream)%00%(upstream:remotename)%00%(upstream:remoteref)%00%(symref)%00",
            "refs/heads", "refs/remotes", "refs/tags",
        ])
        async let config = runner.execute(
            ["config", "-z", "--get-regexp", "^remote\\."],
            acceptedExitCodes: [0, 1]
        )
        let references = try RepositoryReference.parse(await refs)
        let configuration = try await config.standardOutput
        var names = Set<String>()

        // 配置键的第一和最后一个点包住远端名，名字本身可含点。
        for record in configuration.split(separator: 0) {
            let key = String(decoding: record.prefix { $0 != 10 }, as: UTF8.self)
            guard key.hasPrefix("remote."), let last = key.lastIndex(of: "."),
                last > key.index(key.startIndex, offsetBy: 6)
            else {
                throw RepositoryReadError.malformedOutput("remote config")
            }
            names.insert(String(key[key.index(key.startIndex, offsetBy: 7)..<last]))
        }
        return ReferenceSnapshot(
            references: references,
            remotes: names.sorted().map { RepositoryRemote(name: $0) }
        )
    }

    /// 两侧均用快照中的哈希查询，避免刷新途中引用移动改变计数含义。
    public func divergence(local: String, upstream: String) async throws -> ReferenceDivergence {
        guard GitObjectID.isValid(local), GitObjectID.isValid(upstream) else {
            throw RepositoryReadError.invalidQuery
        }
        return try ReferenceDivergence.parse(
            await runner.run([
                "rev-list", "--left-right", "--count", local + "..." + upstream, "--",
            ])
        )
    }

    /// 以 Git 的分支规则校验，拒绝前一分支快捷写法及选项形式。
    public func validate(name: String) async throws {
        guard !name.isEmpty, !name.hasPrefix("-"), !name.contains("@{") else {
            throw RepositoryReadError.invalidQuery
        }
        _ = try await runner.run(["check-ref-format", "--branch", name])
    }

    /// 新建并检出使用同一条 switch，检出失败不会遗留已创建的分支。
    public func create(name: String, startingAt start: String, track: Bool, checkout: Bool) async throws {
        try await runner.writeTransaction {
            try await validate(name: name)
            let revision = try await resolve(start)
            let target = track ? start : revision
            guard !track || start.hasPrefix("refs/heads/") || start.hasPrefix("refs/remotes/") else {
                throw RepositoryReadError.invalidQuery
            }
            let command = checkout ? ["switch", "-c", name] : ["branch", name]
            _ = try await runner.run(command + [track ? "--track=direct" : "--no-track", target])
        }
    }

    /// 只检出明确的本地分支；不存在时不猜测远端，也不把名字解释为文件。
    public func checkout(_ reference: String) async throws {
        guard reference.hasPrefix("refs/heads/") else { throw RepositoryReadError.invalidQuery }
        _ = try await runner.run(["switch", "--no-guess", "--", String(reference.dropFirst(11))])
    }

    /// 普通删除保留 Git 的未合并保护；失败由调用方展示原始输出。
    public func delete(_ references: [String]) async throws {
        guard !references.isEmpty, references.allSatisfy({ $0.hasPrefix("refs/heads/") }) else {
            throw RepositoryReadError.invalidQuery
        }
        _ = try await runner.run(["branch", "-d", "--"] + references.map { String($0.dropFirst(11)) })
    }

    /// 起点解析只接受一个提交，--end-of-options 阻止输入成为 Git 选项。
    public func resolve(_ revision: String) async throws -> String {
        let output = try await runner.run([
            "rev-parse", "--verify", "--end-of-options", revision + "^{commit}",
        ])
        let value = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
        guard GitObjectID.isValid(value) else { throw RepositoryReadError.malformedOutput("rev-parse") }
        return value
    }

    /// 输入时清理必然非法的字符；尾部约束留给 Git 校验，保留打字过程。
    public static func normalizedName(_ value: String) -> String {
        var result = ""

        for scalar in value.precomposedStringWithCanonicalMapping.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                result.append("-")
            } else if scalar.value >= 32, scalar.value != 127, !"~^:?*[\\".unicodeScalars.contains(scalar) {
                result.unicodeScalars.append(scalar)
            }
        }

        result = result.replacingOccurrences(of: "@{", with: "")
        while result.contains("..") { result = result.replacingOccurrences(of: "..", with: ".") }
        while result.contains("//") { result = result.replacingOccurrences(of: "//", with: "/") }
        while let first = result.first, "-/.".contains(first) { result.removeFirst() }
        result = result.replacingOccurrences(of: "/.", with: "/")
        return result
    }
}
