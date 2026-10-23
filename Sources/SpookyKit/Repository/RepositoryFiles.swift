import Foundation

// MARK: - RepositoryFileError

/// 文件访问失败的类别，界面负责本地化，底层诊断保留在关联的命令结果中。
public enum RepositoryFileError: Error, Sendable {
    /// SFTP 批处理无法表示换行或 NUL 路径。
    case unsupportedPath

    /// 文件超过当前内容读取上限。
    case tooLarge
}

// MARK: - RepositoryFiles

/// 工作区所在机器的文件访问边界；远端路径始终作为 SFTP 数据处理。
public struct RepositoryFiles: Sendable {
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
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-sftp-" + UUID().uuidString)
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

    /// 批量读取已定位的绝对路径；缺失文件不进入快照，权限与传输失败仍抛错。
    public func read(_ paths: [String]) async throws -> [String: Data] {
        guard !paths.isEmpty else { return [:] }

        guard let remote = runner.remote else {
            var result: [String: Data] = [:]

            for path in paths {
                do {
                    result[path] = try Self.boundedRead(URL(fileURLWithPath: path))
                } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                    continue
                }
            }

            return result
        }

        // 状态文件多数不存在：先用一次往返确认存在性，只为存在的文件启动 SFTP。
        let flags = try await remote.inspect(paths)
        let existing = zip(paths, flags).filter(\.1).map(\.0)

        guard !existing.isEmpty else {
            return [:]
        }

        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 独立编号避免把远端路径解释为本机路径，也避免文件名的规范化碰撞。
        let commands = try existing.enumerated().map {
            "-get " + (try Self.quoted($0.element)) + " "
                + (try Self.quoted(directory.appending(path: String($0.offset)).path))
        }
        let result = try await transfer(commands, writing: false)
        let diagnostics = String(decoding: result.standardError, as: UTF8.self)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                !$0.contains("No such file or directory")
                    && !($0.hasPrefix("File \"") && $0.hasSuffix("\" not found."))
                    && !$0.isEmpty
            }

        // -get 仅容忍缺失标记文件，不能把权限错误或中断误判为普通工作区。
        guard diagnostics.isEmpty else {
            throw GitError(result: result, category: .processIOFailed, diagnostic: nil)
        }

        var contents: [String: Data] = [:]

        for (index, path) in existing.enumerated() {
            let local = directory.appending(path: String(index))

            if FileManager.default.fileExists(atPath: local.path) {
                contents[path] = try Self.boundedRead(local)
            }
        }

        return contents
    }

    /// 经私有临时文件上传内容；本机写入沿用原文件的权限。
    public func write(_ data: Data, to path: String) async throws {
        try await runner.writeTransaction {
            guard runner.remote != nil else {
                try data.write(to: URL(fileURLWithPath: path))
                return
            }

            let directory = try Self.temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let file = directory.appending(path: "content")
            try data.write(to: file)

            _ = try await transfer([
                "put " + (try Self.quoted(file.path)) + " " + (try Self.quoted(path)),
            ], writing: true)
        }
    }

    /// 把工作区所在机器上的文件复制到本机指定位置；服务器路径只作为 SFTP 数据传递，不交给本机文件 API。
    ///
    /// - Parameters:
    ///   - path: 工作区所在机器上的绝对路径。
    ///   - destination: 本机目标文件，必须尚不存在。
    public func download(_ path: String, to destination: URL) async throws {
        guard runner.remote != nil else {
            try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: destination)
            return
        }

        // 不带 “-” 前缀的 get 失败时 SFTP 以非零状态退出，缺失与权限错误都会抛出
        _ = try await transfer(
            ["get " + (try Self.quoted(path)) + " " + (try Self.quoted(destination.path))],
            writing: false
        )
    }

    /// 丢弃未跟踪文件只删除明确选中的文件，不递归进入嵌套仓库。
    func remove(_ paths: [String]) async throws {
        guard !paths.isEmpty else { return }

        if runner.remote == nil {
            for path in paths {
                try FileManager.default.removeItem(at: URL(fileURLWithPath: path))
            }

            return
        }

        _ = try await transfer(try paths.map { "rm " + (try Self.quoted($0)) }, writing: true)
    }

    /// 把本机文件或目录移到废纸篓，用户可以从废纸篓找回；服务器文件不经过这里。
    ///
    /// - Returns: 各项在废纸篓里的位置。
    func moveToTrash(_ paths: [String]) throws -> [URL] {
        try paths.compactMap { path in
            // trashItem 只接受 NSURL 的输出参数
            // swiftlint:disable:next legacy_objc_type
            var trashed: NSURL?
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &trashed)

            return trashed as URL?
        }
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

            // 服务器支持 posix-rename 时 SFTP 的 rename 会覆盖目标，先确认目标不存在
            guard try await remote.inspect([destination]) == [false] else {
                throw WorkingCopyFileError.destinationExists
            }

            _ = try await transfer(
                ["rename " + (try Self.quoted(path)) + " " + (try Self.quoted(destination))],
                writing: true
            )
        }
    }

    /// 确保目录存在：本机逐级创建；服务器经 SFTP 创建最后一级，已存在时不算失败。
    func createDirectory(_ path: String) async throws {
        guard runner.remote != nil else {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: path),
                withIntermediateDirectories: true
            )
            return
        }

        // 批处理里带 “-” 前缀的命令失败时不中断，目录已存在属于这种情况
        _ = try await transfer(["-mkdir " + (try Self.quoted(path))], writing: true)
    }

    /// 执行一批 SFTP 命令；取消会直接结束本批子进程，SSH 主连接保留。
    private func transfer(_ commands: [String], writing: Bool) async throws -> GitCommandResult {
        guard let remote = runner.remote else { throw RepositoryFileError.unsupportedPath }
        return try await remote.transferSFTP(
            Data((commands.joined(separator: "\n") + "\n").utf8),
            writing: writing
        )
    }

}
