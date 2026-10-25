import Foundation

// MARK: - FileVersion

/// 交给外部比较工具的一侧文件版本。
public enum FileVersion: Sendable, Hashable {
    /// 某个提交里的文件，参数是提交的完整哈希。
    case commit(String)

    /// 当前 HEAD 里的文件；还没有提交时这一侧没有文件。
    case head

    /// 暂存区里的文件。
    case index

    /// 工作区里的文件。
    case workingTree

    /// 指定对象的内容，如冲突的某一方；nil 表示这一侧没有文件。
    case blob(String?)
}

// MARK: - ComparedFile

/// 参与比较的一个文件：重命名时左侧按原路径读取。
public struct ComparedFile: Sendable, Hashable {
    /// 右侧的路径，相对仓库根目录。
    public let path: String

    /// 左侧的路径；没有重命名时为 nil，与右侧相同。
    public let originalPath: String?

    /// 左侧读取时使用的路径。
    var leftPath: String { originalPath ?? path }

    /// 创建一个比较文件。
    ///
    /// - Parameters:
    ///   - path: 右侧的路径。
    ///   - originalPath: 重命名前的路径，左侧按它读取。
    public init(path: String, originalPath: String? = nil) {
        self.path = path
        self.originalPath = originalPath
    }
}

// MARK: - ExternalToolError

/// 外部工具与编辑器副本写回前的核对失败，界面负责本地化。
public enum ExternalToolError: Error, Sendable, Equatable {
    /// 文件在仓库所在的机器上已被改动，与交给外部程序时的内容不同；覆盖前需要用户确认。
    case fileChanged
}

// MARK: - ExternalToolFiles

/// 把外部比较与合并工具要看的内容放到本机：各版本经 Git 取出写进会话缓存，工具只拿到本机路径。
///
/// 本机与服务器仓库走同一条路径；服务器上的工作区文件经 SFTP 读取，远端路径不交给本机程序。
public struct ExternalToolFiles: Sendable {
    /// 与仓库会话共用的文件缓存，关闭仓库时随它删除。
    public let cache: RepositoryFileCache

    /// 仓库所在机器上的命令执行器。
    var runner: GitRunner { cache.runner }

    /// 创建服务，不立即访问仓库。
    public init(cache: RepositoryFileCache) {
        self.cache = cache
    }

    /// 单个文件一侧的本机路径；这一侧没有这个文件时是同名的空文件。
    ///
    /// 本机仓库的工作区文件直接使用原路径，工具里的修改即是工作区的修改；其余版本都写成缓存副本。
    ///
    /// - Parameters:
    ///   - path: 文件在仓库内的路径。
    ///   - version: 读取的版本。
    public func file(_ path: String, at version: FileVersion) async throws -> URL {
        if version == .workingTree, runner.remote == nil {
            let url = URL(fileURLWithPath: runner.location.path).appending(path: path)

            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        let data = try await contents(of: path, at: version) ?? Data()
        return try cache.store(data, named: path)
    }

    /// 目录对比的两侧：各是一个以版本名命名的目录，按仓库内的相对路径放入文件；一侧没有的文件不放入。
    ///
    /// - Parameters:
    ///   - files: 参与比较的文件。
    ///   - left: 左侧版本与目录名。
    ///   - right: 右侧版本与目录名。
    public func directories(
        _ files: [ComparedFile],
        left: (version: FileVersion, name: String),
        right: (version: FileVersion, name: String)
    ) async throws -> (left: URL, right: URL) {
        let leftDirectory = try cache.directory(named: left.name)
        let rightDirectory = try cache.directory(named: right.name)

        for file in files {
            if let data = try await contents(of: file.leftPath, at: left.version) {
                try Self.write(data, at: file.leftPath, in: leftDirectory)
            }

            if let data = try await contents(of: file.path, at: right.version) {
                try Self.write(data, at: file.path, in: rightDirectory)
            }
        }

        return (leftDirectory, rightDirectory)
    }

    /// 一个版本里的文件内容；这个版本里没有这个文件时为 nil。
    ///
    /// - Parameters:
    ///   - path: 文件在仓库内的路径。
    ///   - version: 读取的版本。
    func contents(of path: String, at version: FileVersion) async throws -> Data? {
        switch version {
        case .commit(let commit):
            return try await committedContents(of: path, in: commit)

        case .head:
            guard let head = try await headCommit() else { return nil }
            return try await committedContents(of: path, in: head)

        case .index:
            return try await indexContents(of: path)

        case .workingTree:
            let absolute = runner.location.path + "/" + path
            return try await RepositoryFiles(runner: runner).read([absolute])[absolute]

        case .blob(let object):
            guard let object else { return nil }
            return try await blob(object)
        }
    }

    /// 按哈希读取对象内容；对象内容不可变，结果按哈希复用。
    func blob(_ object: String) async throws -> Data {
        guard GitObjectID.isValid(object) else {
            throw RepositoryReadError.invalidQuery
        }

        return try await runner.immutableRun(["cat-file", "blob", object])
    }
}

// MARK: - Private

extension ExternalToolFiles {
    /// 把内容按仓库内的相对路径写进目录；“.” “..” 与空的路径段丢弃，文件不会落到目录之外。
    private static func write(_ data: Data, at path: String, in directory: URL) throws {
        let components = path.split(separator: "/")
            .map(String.init)
            .filter { !["", ".", ".."].contains($0) }

        guard !components.isEmpty else {
            return
        }

        let file = components.reduce(directory) { $0.appending(path: $1) }

        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        try data.write(to: file)
    }

    /// 提交里的文件内容：路径先按 Unicode 等价换成树中存储的形式；子模块与目录没有文件内容。
    private func committedContents(of path: String, in commit: String) async throws -> Data? {
        let views = RepositoryFileViews(runner: runner)

        guard let entry = try await views.storedEntry(for: path, in: commit), entry.type == "blob" else {
            return nil
        }

        return try await views.contents(of: entry)
    }

    /// 当前 HEAD 指向的提交；还没有提交时为 nil。
    private func headCommit() async throws -> String? {
        let result = try await runner.execute(
            ["rev-parse", "--verify", "--quiet", "HEAD^{commit}"],
            acceptedExitCodes: [0, 1]
        )

        let hash = String(decoding: result.standardOutput, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return result.exitCode == 0 && GitObjectID.isValid(hash) ? hash : nil
    }

    /// 暂存区里的文件内容：取 stage 0 的对象；文件不在暂存区或仍是冲突时为 nil。
    private func indexContents(of path: String) async throws -> Data? {
        let output = try await runner.run(
            RepositoryFileViews.storedPathOptions + ["ls-files", "--stage", "-z", "--", path]
        )

        // 每条记录是 “<模式> <哈希> <stage>\t<路径>”
        for record in output.split(separator: 0) {
            let fields = String(decoding: record, as: UTF8.self)
                .split(separator: "\t", maxSplits: 1)
                .first?
                .split(separator: " ")

            guard let fields, fields.count == 3, fields[2] == "0" else {
                continue
            }

            return try await blob(String(fields[1]))
        }

        return nil
    }
}
