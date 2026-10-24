import Foundation

// MARK: - ReferenceDivergence

/// 相对指定上游的双向提交数量。
public struct ReferenceDivergence: Sendable, Equatable {
    /// 本地独有的提交数。
    public let ahead: Int

    /// 上游独有的提交数。
    public let behind: Int

    /// 只接受 rev-list 的两个非负整数，不解析 branch 的人读文字。
    static func parse(_ data: Data) throws -> Self {
        let fields = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isWhitespace)
        guard
            fields.count == 2, let ahead = Int(fields[0]), let behind = Int(fields[1]), ahead >= 0,
            behind >= 0
        else {
            throw RepositoryReadError.malformedOutput("rev-list")
        }
        return Self(ahead: ahead, behind: behind)
    }
}

// MARK: - RepositoryReference

/// 同一次 for-each-ref 快照中的引用。
public struct RepositoryReference: Sendable, Equatable, Identifiable {
    /// `snapshot()` 的 for-each-ref 格式；字段以 NUL 结尾，顺序与 `parse(_:)` 一一对应。
    ///
    /// 标签说明只对附注标签输出，分支不带回提交说明。
    static let format = [
        "%(refname)", "%(objectname)", "%(objecttype)", "%(*objectname)", "%(*objecttype)",
        "%(upstream)", "%(upstream:remotename)", "%(upstream:remoteref)", "%(symref)",
        "%(creatordate:unix)",
        "%(if:equals=tag)%(objecttype)%(then)%(contents:subject)%(end)",
        "%(if:equals=tag)%(objecttype)%(then)%(contents:body)%(end)",
    ]
    .map { $0 + "%00" }
    .joined()

    /// 每条记录的字段数。
    private static let fieldCount = 12

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

    /// 引用指向对象的创建时间：分支是顶端提交的提交时间，附注标签是打标签的时间；读不到时为 nil。
    public let date: Date?

    /// 附注标签的说明，不含签名；轻量标签与其它引用为 nil。
    public let message: String?

    /// 引用是否为本地分支。
    public var isLocal: Bool { id.hasPrefix("refs/heads/") }

    /// 引用是否为远端跟踪分支。
    public var isRemote: Bool { id.hasPrefix("refs/remotes/") }

    /// 引用是否为标签。
    public var isTag: Bool { id.hasPrefix("refs/tags/") }

    /// 供界面展示的名称，保留远端前缀。
    public var name: String {
        for prefix in ["refs/heads/", "refs/remotes/", "refs/tags/"] where id.hasPrefix(prefix) {
            return String(id.dropFirst(prefix.count))
        }
        return id
    }

    /// 创建一条引用；时间与标签说明可省略，供只关心引用关系的调用方使用。
    init(
        id: String,
        objectID: String,
        objectType: String,
        upstream: String?,
        upstreamRemote: String?,
        upstreamBranch: String?,
        symbolicTarget: String?,
        date: Date? = nil,
        message: String? = nil
    ) {
        self.id = id
        self.objectID = objectID
        self.objectType = objectType
        self.upstream = upstream
        self.upstreamRemote = upstreamRemote
        self.upstreamBranch = upstreamBranch
        self.symbolicTarget = symbolicTarget
        self.date = date
        self.message = message
    }

    /// 解析固定 NUL 字段，仅移除 Git 在记录间额外插入的一个换行。
    static func parse(_ data: Data) throws -> [Self] {
        guard !data.isEmpty else { return [] }
        let fields = data.split(separator: 0, omittingEmptySubsequences: false)
        guard fields.count % fieldCount == 1, fields.last == Data([10]) else {
            throw RepositoryReadError.malformedOutput("for-each-ref")
        }

        return try stride(from: 0, to: fields.count - 1, by: fieldCount)
            .map { start in
                var values = fields[start ..< (start + fieldCount)].map { String(decoding: $0, as: UTF8.self) }
                if start > 0, values[0].hasPrefix("\n") { values[0].removeFirst() }
                guard
                    values[0].hasPrefix("refs/"), GitObjectID.isValid(values[1]),
                    values[3].isEmpty || GitObjectID.isValid(values[3])
                else {
                    throw RepositoryReadError.malformedOutput("for-each-ref")
                }

                // 时间是 Unix 秒数；符号引用等读不到时间的记录留空
                let date: Date?

                if values[9].isEmpty {
                    date = nil
                } else if let seconds = Int64(values[9]) {
                    date = Date(timeIntervalSince1970: TimeInterval(seconds))
                } else {
                    throw RepositoryReadError.malformedOutput("for-each-ref")
                }

                return Self(
                    id: values[0],
                    objectID: values[3].isEmpty ? values[1] : values[3],
                    objectType: values[4].isEmpty ? values[2] : values[4],
                    upstream: values[5].isEmpty ? nil : values[5],
                    upstreamRemote: values[6].isEmpty ? nil : values[6],
                    upstreamBranch: values[7].isEmpty ? nil : values[7],
                    symbolicTarget: values[8].isEmpty ? nil : values[8],
                    date: date,
                    message: tagMessage(subject: values[10], body: values[11])
                )
            }
    }

    /// 标题与正文之间按 Git 的写法空一行；两者都空时没有说明。
    private static func tagMessage(subject: String, body: String) -> String? {
        let body = body.trimmingCharacters(in: .newlines)

        if body.isEmpty {
            return subject.isEmpty ? nil : subject
        }

        return subject + "\n\n" + body
    }
}

// MARK: - RepositoryRemote

/// 配置远端的名称及其分支归属，不额外访问服务器的仓库列表。
public struct RepositoryRemote: Sendable, Equatable, Identifiable {
    /// Git 配置中的远端名。
    public let name: String

    /// 默认 fetch 布局的分组身份。
    public var id: String { name }
}

// MARK: - ReferenceSnapshot

/// 一致读取的引用、远端名单与本地分支的附加信息。
public struct ReferenceSnapshot: Sendable, Equatable {
    /// 本地、远端与标签引用；标签用于历史标记。
    public let references: [RepositoryReference]

    /// 即使尚未 Fetch，空远端也保留分组。
    public let remotes: [RepositoryRemote]

    /// 本地分支的置顶、归档与父分支，以完整引用名为键；没有任何记录的分支不在表中。
    public let metadata: [String: BranchMetadata]

    /// 创建快照；附加信息可省略，供只关心引用关系的调用方使用。
    init(
        references: [RepositoryReference],
        remotes: [RepositoryRemote],
        metadata: [String: BranchMetadata] = [:]
    ) {
        self.references = references
        self.remotes = remotes
        self.metadata = metadata
    }

    /// 本地分支的附加信息；没有记录时是默认值：不置顶、不归档、没有父分支。
    public func metadata(for branch: String) -> BranchMetadata {
        metadata[branch] ?? BranchMetadata()
    }

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

// MARK: - RepositoryReferences

/// 引用读写的业务边界，名称校验和写入都经过统一 Git 执行器。
public struct RepositoryReferences: Sendable {
    /// 本机与服务器使用相同参数协议。
    public let runner: GitRunner

    /// 创建引用服务，不执行隐式操作。
    public init(runner: GitRunner) {
        self.runner = runner
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

    /// 一次读取全部引用，另一次读取远端名字，再一次读取分支的附加信息；三者并发，空仓库也是合法快照。
    public func snapshot() async throws -> ReferenceSnapshot {
        async let refs = runner.run([
            "for-each-ref", "--sort=refname",
            "--format=" + RepositoryReference.format,
            "refs/heads", "refs/remotes", "refs/tags",
        ])
        async let config = runner.execute(
            ["config", "-z", "--get-regexp", "^remote\\."],
            acceptedExitCodes: [0, 1]
        )
        async let branchMetadata = metadata()
        let references = try RepositoryReference.parse(await refs)
        let configuration = try await config.standardOutput
        var names = Set<String>()

        // 配置键的第一和最后一个点包住远端名，名字本身可含点。
        for record in configuration.split(separator: 0) {
            let key = String(decoding: record.prefix { $0 != 10 }, as: UTF8.self)
            guard
                key.hasPrefix("remote."), let last = key.lastIndex(of: "."),
                last > key.index(key.startIndex, offsetBy: 6)
            else {
                throw RepositoryReadError.malformedOutput("remote config")
            }
            names.insert(String(key[key.index(key.startIndex, offsetBy: 7) ..< last]))
        }
        return try await ReferenceSnapshot(
            references: references,
            remotes: names.sorted().map { RepositoryRemote(name: $0) },
            metadata: branchMetadata
        )
    }

    /// 两侧均用快照中的哈希查询，避免刷新途中引用移动改变计数含义；同一对哈希的计数不变，按哈希复用。
    public func divergence(local: String, upstream: String) async throws -> ReferenceDivergence {
        guard GitObjectID.isValid(local), GitObjectID.isValid(upstream) else {
            throw RepositoryReadError.invalidQuery
        }
        return try ReferenceDivergence.parse(
            await runner.immutableRun([
                "rev-list", "--left-right", "--count", local + "..." + upstream, "--",
            ])
        )
    }

    /// 快照中所有本地分支相对上游的计数；各分支并发查询，上游已删除的分支不计数。
    public func divergences(in snapshot: ReferenceSnapshot) async throws -> [String: ReferenceDivergence] {
        let pairs = snapshot.references.filter(\.isLocal).compactMap { reference in
            snapshot.references.first { $0.id == reference.upstream }
                .map { (reference.id, reference.objectID, $0.objectID) }
        }

        // 并发度由仓库队列的主机槽统一限制，服务器上不会超出会话上限。
        return try await withThrowingTaskGroup(of: (String, ReferenceDivergence).self) { group in
            for (id, local, upstream) in pairs {
                group.addTask {
                    (id, try await divergence(local: local, upstream: upstream))
                }
            }

            var counts: [String: ReferenceDivergence] = [:]

            for try await (id, divergence) in group {
                counts[id] = divergence
            }

            return counts
        }
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

}
