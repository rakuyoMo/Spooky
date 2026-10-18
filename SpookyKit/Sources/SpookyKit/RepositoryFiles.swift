import Foundation

/// 文件访问失败的类别，界面负责本地化，底层诊断保留在关联的命令结果中。
public enum RepositoryFileError: Error, Sendable {
    /// SFTP 批处理无法表示换行或 NUL 路径。
    case unsupportedPath

    /// 文件超过当前内容读取上限。
    case tooLarge
}

/// 工作区所在机器的文件访问边界；远端路径始终作为 SFTP 数据处理。
public struct RepositoryFiles: Sendable {
    /// 文件访问与 Git 使用相同的仓库和 SSH 会话。
    let runner: GitRunner

    /// 建立文件访问服务，不立即访问磁盘或网络。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 批量读取已定位的绝对路径；缺失文件不进入快照，权限与传输失败仍抛错。
    public func read(_ paths: [String]) async throws -> [String: Data] {
        guard !paths.isEmpty else { return [:] }

        if runner.remote == nil {
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

        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 独立编号避免把远端路径解释为本机路径，也避免文件名的规范化碰撞。
        let commands = try paths.enumerated().map {
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

        for (index, path) in paths.enumerated() {
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

    /// 执行一批 SFTP 命令；取消会直接结束本批子进程，SSH 主连接保留。
    private func transfer(_ commands: [String], writing: Bool) async throws -> GitCommandResult {
        guard let remote = runner.remote else { throw RepositoryFileError.unsupportedPath }
        return try await remote.transferSFTP(
            Data((commands.joined(separator: "\n") + "\n").utf8),
            writing: writing
        )
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
}
