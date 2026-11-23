import Foundation

// MARK: - RepositoryFileError

/// 文件访问失败的类别，界面负责本地化，底层诊断保留在关联的命令结果中。
public enum RepositoryFileError: Error, Sendable {
    /// SFTP 批处理无法表示换行或 NUL 路径。
    case unsupportedPath

    /// 文件超过当前内容读取上限。
    case tooLarge

    /// 服务器上没有可用的废纸篓。
    case trashUnavailable

    /// 要从废纸篓移回的项位置不明、已不在废纸篓里，或原位置已被占用。
    case trashedItemsUnavailable
}

// MARK: - RepositoryFiles

/// 工作区所在机器的文件访问边界：服务器上的文件由 B 上的包装器读写，超出内联预算的大文件经 SFTP 取回，远端路径不交给本机文件 API。
public struct RepositoryFiles: Sendable {
    /// 一次读取随记录取回的内容的总字节数上限，超出的文件经 SFTP 取回。
    static let inlineReadBudget = 16 * 1024 * 1024

    /// 随请求发出的写入内容的上限：常驻通道的请求上限里给包装器、路径等参数留出 64 KiB，超出时 ssh 从本机临时文件读取内容。
    private static let inlineWriteLimit = RemoteCommandChannel.requestLimit - 64 * 1024

    /// 文件访问与 Git 使用相同的仓库和 SSH 会话。
    let runner: GitRunner

    /// 建立文件访问服务，不立即访问磁盘或网络。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// SFTP 自动将引号内通配符视为字面值，只转义引号与反斜杠。
    static func quoted(_ path: String) throws -> String {
        guard !path.contains("\n"), !path.contains("\r"), !path.utf8.contains(0) else {
            throw RepositoryFileError.unsupportedPath
        }

        var result = "\""

        for character in path {
            if "\\\"".contains(character) { result.append("\\") }
            result.append(character)
        }

        return result + "\""
    }

    /// 中继文件只落在本次调用独占的 0700 目录中。
    private static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-transfer-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        return directory
    }

    /// 使用映射读取并验证上限，避免把异常大的状态文件复制进内存。
    private static func boundedRead(_ url: URL) throws -> Data {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= 256 * 1024 * 1024 else { throw RepositoryFileError.tooLarge }
        return data
    }

    /// 本机文件的修改时间；读不到属性时为 nil。
    private static func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// 批量读取已定位的绝对路径；缺失文件不进入快照，权限与传输失败仍抛错。
    public func read(_ paths: [String]) async throws -> [String: Data] {
        try await snapshot(paths, preservingDates: false).mapValues(\.data)
    }

    /// 批量读取已定位的绝对路径，连同文件在工作区所在机器上的修改时间；缺失文件不进入结果。
    ///
    /// 服务器上的修改时间精确到秒。
    public func readWithModificationDates(_ paths: [String]) async throws -> [String: (data: Data, modified: Date?)] {
        try await snapshot(paths, preservingDates: true)
    }

    /// 读取文件内容与修改时间。
    ///
    /// - Parameters:
    ///   - paths: 工作区所在机器上的绝对路径。
    ///   - preservingDates: 是否取修改时间；不取时结果里的时间都是 nil。
    private func snapshot(
        _ paths: [String],
        preservingDates: Bool
    ) async throws -> [String: (data: Data, modified: Date?)] {
        guard !paths.isEmpty else { return [:] }

        guard let remote = runner.remote else {
            var result: [String: (data: Data, modified: Date?)] = [:]

            for path in paths {
                let url = URL(fileURLWithPath: path)

                do {
                    result[path] = (
                        try Self.boundedRead(url),
                        preservingDates ? Self.modificationDate(url) : nil
                    )
                } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                    continue
                }
            }

            return result
        }

        // 一次往返取回内容与修改时间，不存在的文件不进结果；超出内联预算的大文件再经 SFTP 取回
        let records = try await remote.readFiles(paths, inlineBudget: Self.inlineReadBudget)
        var contents: [String: (data: Data, modified: Date?)] = [:]
        var oversized: [(path: String, modified: Date)] = []

        for (path, record) in zip(paths, records) {
            switch record {
            case .missing:
                continue

            case .content(let data, let modified):
                contents[path] = (data, preservingDates ? modified : nil)

            case .oversized(let modified):
                oversized.append((path, modified))
            }
        }

        let fetched = try await fetchOversized(oversized.map(\.path))

        // 读取之后又被删掉的大文件同样按不存在处理
        for (path, modified) in oversized {
            guard let data = fetched[path] else { continue }

            contents[path] = (data, preservingDates ? modified : nil)
        }

        return contents
    }

    /// 写入文件；本机写入沿用原文件的权限。
    ///
    /// 服务器上先写进目标所在目录的临时文件，写完再改名替换，中途出错、断线或取消时原文件不变；
    /// 目标是符号链接时替换它最终指向的文件，已有文件的权限位照旧。
    public func write(_ data: Data, to path: String) async throws {
        try await runner.writeTransaction {
            guard let remote = runner.remote else {
                try data.write(to: URL(fileURLWithPath: path))
                return
            }

            // 内容装得进一个请求时随请求发出
            guard data.count > Self.inlineWriteLimit else {
                try await remote.replaceFile(path, size: data.count, input: data)
                return
            }

            // 装不下时先落到私有临时文件，ssh 直接读它：连接中途断开时本进程没有写到一半的管道
            let directory = try Self.temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let file = directory.appending(path: "content")
            try data.write(to: file)

            try await remote.replaceFile(path, size: data.count, inputFile: file)
        }
    }

    /// 把工作区所在机器上的文件复制到本机指定位置；文件不存在、没有权限时都抛出。
    ///
    /// - Parameters:
    ///   - path: 工作区所在机器上的绝对路径。
    ///   - destination: 本机目标文件，必须尚不存在。
    public func download(_ path: String, to destination: URL) async throws {
        guard let remote = runner.remote else {
            try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: destination)
            return
        }

        // 先一次往返读取，内容在内联预算之内时直接写到目标
        let record = try await remote.readFiles([path], inlineBudget: Self.inlineReadBudget).first ?? .missing

        switch record {
        case .content(let data, _):
            try data.write(to: destination)

        case .oversized:
            // 大文件经 SFTP 取回：不带 “-” 前缀的 get 失败时 SFTP 以非零状态退出
            _ = try await transfer(["get " + (try Self.quoted(path)) + " " + (try Self.quoted(destination.path))])

        case .missing:
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: path])
        }
    }

    /// 永久删除明确选中的文件，不递归进入嵌套仓库。
    func remove(_ paths: [String]) async throws {
        guard !paths.isEmpty else { return }

        guard let remote = runner.remote else {
            for path in paths {
                try FileManager.default.removeItem(at: URL(fileURLWithPath: path))
            }

            return
        }

        try await remote.removeFiles(paths)
    }

    /// 把工作区所在机器上的文件移到新位置，目标已存在时不覆盖。
    ///
    /// - Parameters:
    ///   - path: 原文件的绝对路径。
    ///   - destination: 目标的绝对路径，所在目录必须已存在。
    func move(_ path: String, to destination: String) async throws {
        try await runner.writeTransaction {
            guard let remote = runner.remote else {
                guard !FileManager.default.fileExists(atPath: destination) else {
                    throw WorkingCopyFileError.destinationExists
                }

                try FileManager.default.moveItem(
                    at: URL(fileURLWithPath: path),
                    to: URL(fileURLWithPath: destination)
                )
                return
            }

            try await remote.moveFile(path, to: destination)
        }
    }

    /// 确保目录存在：本机与服务器都逐级创建，已存在的各级目录不算失败。
    ///
    /// - Parameter path: 目录的绝对路径。
    func createDirectory(_ path: String) async throws {
        guard let remote = runner.remote else {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: path),
                withIntermediateDirectories: true
            )
            return
        }

        try await remote.createDirectory(path)
    }

    /// 删掉工作区所在机器上的一个目录及其全部内容，目录不存在时什么也不做。
    ///
    /// ``remove(_:)`` 只删文件，服务器经主机连接在 B 上执行 `rm -rf`。
    ///
    /// - Parameter path: 目录的绝对路径。
    func removeTree(_ path: String) async throws {
        guard let remote = runner.remote else {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
            return
        }

        _ = try await HostExecution.run(
            ["/bin/rm", "-rf", "--", path],
            at: .remote(host: remote.host, path: path),
            writing: true
        )
    }

    /// 经 SFTP 取回超出内联预算的文件；取回之前已被删掉的文件不进结果，权限与传输失败仍抛错。
    ///
    /// - Parameter paths: 工作区所在机器上的绝对路径。
    /// - Returns: 取回的内容。
    private func fetchOversized(_ paths: [String]) async throws -> [String: Data] {
        guard !paths.isEmpty else { return [:] }

        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 独立编号避免把远端路径解释为本机路径，也避免文件名的规范化碰撞
        let commands = try paths.enumerated().map {
            "-get " + (try Self.quoted($0.element)) + " "
                + (try Self.quoted(directory.appending(path: String($0.offset)).path))
        }
        let result = try await transfer(commands)
        let diagnostics = String(decoding: result.standardError, as: UTF8.self)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                !$0.contains("No such file or directory")
                    && !($0.hasPrefix("File \"") && $0.hasSuffix("\" not found."))
                    && !$0.isEmpty
            }

        // -get 只容忍已被删掉的文件，不能把权限错误或中断当成文件不存在
        guard diagnostics.isEmpty else {
            throw GitError(result: result, category: .processIOFailed, diagnostic: nil)
        }

        var contents: [String: Data] = [:]

        for (index, path) in paths.enumerated() {
            let local = directory.appending(path: String(index))

            if FileManager.default.fileExists(atPath: local.path) {
                contents[path] = try Self.boundedRead(local)
            }
        }

        return contents
    }

    /// 执行一批 SFTP 命令取回文件；取消会直接结束本批子进程，SSH 主连接保留。
    private func transfer(_ commands: [String]) async throws -> GitCommandResult {
        guard let remote = runner.remote else { throw RepositoryFileError.unsupportedPath }
        return try await remote.transferSFTP(Data((commands.joined(separator: "\n") + "\n").utf8))
    }

}
