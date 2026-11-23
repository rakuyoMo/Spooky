import Foundation

// MARK: - RemoteFileRecord

/// 包装器的读取模式为一个路径写出的记录。
enum RemoteFileRecord: Sendable, Equatable {
    /// 路径不存在。
    case missing

    /// 内容随记录一起取回；修改时间精确到秒。
    case content(Data, modified: Date)

    /// 超出内联预算，内容没有随记录取回；修改时间精确到秒。
    case oversized(modified: Date)
}

// MARK: - Files

extension RemoteConnection {
    /// 移动时目标已存在，包装器以这个退出码结束。
    static let destinationExistsCode: Int32 = 3

    /// 按顺序切开读取模式写出的记录。
    ///
    /// 每条记录的第一个字节是类别：0 不存在，1 带内容，2 超出内联预算；
    /// 1 与 2 接着是修改时间（整秒，不早于 1970 年）与大小，各是高 32 位、低 32 位两个大端整数，1 的内容紧跟在后面。
    ///
    /// - Parameters:
    ///   - output: 读取模式的标准输出。
    ///   - count: 请求的路径数。
    /// - Returns: 与路径一一对应的记录；记录数不符、类别不明或长度不对时为 nil。
    static func records(in output: Data, count: Int) -> [RemoteFileRecord]? {
        var records: [RemoteFileRecord] = []
        var index = output.startIndex

        while records.count < count, index < output.endIndex {
            let kind = output[index]
            index += 1

            if kind == 0 {
                records.append(.missing)
                continue
            }

            guard [1, 2].contains(kind), output.endIndex - index >= 16 else { return nil }

            let modified = Date(timeIntervalSince1970: TimeInterval(wideInteger(in: output, at: index)))
            let size = wideInteger(in: output, at: index + 8)
            index += 16

            guard kind == 1 else {
                records.append(.oversized(modified: modified))
                continue
            }

            guard size <= UInt64(output.endIndex - index) else { return nil }

            // 内容另建成下标从 0 开始的 Data：读取的结果交给调用方后，按整数下标取字节不会越界
            let end = index + Int(size)
            records.append(.content(Data(output[index ..< end]), modified: modified))
            index = end
        }

        return records.count == count && index == output.endIndex ? records : nil
    }

    /// 一次往返读取多个文件：前面已内联的字节数加上这个文件的大小不超过 `inlineBudget` 时，内容随记录取回。
    ///
    /// 与只读命令一样占用主机槽；没有权限、不是普通文件或读到一半出错时抛出 ``GitError``，诊断是包装器写出的 “路径: 原因”。
    ///
    /// - Parameters:
    ///   - paths: B 上的绝对路径。
    ///   - inlineBudget: 随记录取回的内容的总字节数上限。
    /// - Returns: 与 `paths` 一一对应的记录。
    func readFiles(_ paths: [String], inlineBudget: Int) async throws -> [RemoteFileRecord] {
        try await performQuery { try await $0.fileRecords(paths, inlineBudget: inlineBudget) }
    }

    /// 替换 B 上的一个文件：包装器先把内容写进目标所在目录里独占的临时文件，写完再改名替换，中途出错、断线或取消时原文件不变。
    ///
    /// - Parameters:
    ///   - path: 目标文件的绝对路径；是符号链接时替换它最终指向的文件，已有文件的权限位照旧。
    ///   - size: 新内容的字节数，包装器读满才替换。
    ///   - input: 内存里的新内容，随请求发出。
    ///   - inputFile: 本机上存着新内容的文件，ssh 直接从它读取。
    func replaceFile(_ path: String, size: Int, input: Data? = nil, inputFile: URL? = nil) async throws {
        _ = try await performWrite(arguments: ["replace"], input: input, inputFile: inputFile) {
            [$0, "replace", path, String(size)]
        }
    }

    /// 永久删除 B 上的文件：按顺序删除，遇到第一个失败就停下；不删目录。
    ///
    /// - Parameter paths: 文件的绝对路径。
    func removeFiles(_ paths: [String]) async throws {
        _ = try await performWrite(arguments: ["delete"]) { [$0, "delete"] + paths }
    }

    /// 把 B 上的文件或目录移到新位置，目标已存在时不覆盖。
    ///
    /// - Parameters:
    ///   - path: 原位置的绝对路径。
    ///   - destination: 目标的绝对路径，所在目录必须已存在。
    /// - Throws: 目标已存在时抛出 ``WorkingCopyFileError/destinationExists``。
    func moveFile(_ path: String, to destination: String) async throws {
        let result = try await performWrite(
            arguments: ["move"],
            acceptedExitCodes: [0, Self.destinationExistsCode]
        ) {
            [$0, "move", path, destination]
        }

        guard result.exitCode == 0 else { throw WorkingCopyFileError.destinationExists }
    }

    /// 在 B 上从根目录起逐级建出目录，已存在的各级目录不算失败；新目录按登录时的 umask 取权限。
    ///
    /// - Parameter path: 目录的绝对路径。
    func createDirectory(_ path: String) async throws {
        _ = try await performWrite(arguments: ["mkdir"]) { [$0, "mkdir", path] }
    }

    /// 在 B 上执行一个写入命令：与 Git 写命令一样占用本仓库的写槽与主机槽，在独立进程组里运行，取消经包装器确认。
    ///
    /// 获得执行槽后再次确认连接与写入核对状态，排队期间的断线不能被忽略。
    ///
    /// - Parameters:
    ///   - arguments: 记进结果与错误的业务参数。
    ///   - input: 内存里的标准输入。
    ///   - inputFile: 标准输入改从这个本机文件读取。
    ///   - acceptedExitCodes: 算作成功的退出码。
    ///   - command: 由包装器的路径得出 B 上的命令。
    /// - Returns: 命令的结果。
    func performWrite(
        arguments: [String],
        input: Data? = nil,
        inputFile: URL? = nil,
        acceptedExitCodes: Set<Int32> = [0],
        command: @escaping @Sendable (String) -> [String]
    ) async throws -> GitCommandResult {
        if repository == nil { _ = try await open() }

        if let canonical {
            return try await canonical.performWrite(
                arguments: arguments,
                input: input,
                inputFile: inputFile,
                acceptedExitCodes: acceptedExitCodes,
                command: command
            )
        }

        let location = RepositoryLocation.remote(host: host, path: repository?.path ?? requestedPath)

        return try await RepositoryOperationQueue.shared.perform(at: location, writing: true) {
            try await self.writeConnected(
                arguments: arguments,
                input: input,
                inputFile: inputFile,
                acceptedExitCodes: acceptedExitCodes,
                command: command
            )
        }
    }
}

// MARK: - Private

extension RemoteConnection {
    /// 读出记录里的一个整数：从 `index` 起的高 32 位、低 32 位两个大端整数。
    private static func wideInteger(in data: Data, at index: Data.Index) -> UInt64 {
        let high = data[index ..< index + 4].reduce(0) { $0 << 8 | UInt64($1) }
        let low = data[index + 4 ..< index + 8].reduce(0) { $0 << 8 | UInt64($1) }
        return high << 32 | low
    }

    /// 执行包装器的读取模式并切开它写出的记录。
    private func fileRecords(_ paths: [String], inlineBudget: Int) async throws -> [RemoteFileRecord] {
        guard let wrapper else { throw RemoteConnectionError(.unavailable) }

        let result = try await commandChannel(
            [wrapper, "read", String(inlineBudget)] + paths,
            arguments: ["read"]
        )

        if result.exitCode == 255 { throw RemoteConnectionError.ssh(result) }

        // 没有权限、不是普通文件或读到一半出错：包装器写出 “路径: 原因” 并失败退出
        guard result.exitCode == 0 else {
            throw GitError(result: result, category: .processIOFailed, diagnostic: nil)
        }

        guard let records = Self.records(in: result.standardOutput, count: paths.count) else {
            throw RemoteConnectionError(.protocolFailure, result: result)
        }

        return records
    }

    /// 获得执行槽后再次确认连接与写入核对状态，再经包装器运行写入命令。
    private func writeConnected(
        arguments: [String],
        input: Data?,
        inputFile: URL?,
        acceptedExitCodes: Set<Int32>,
        command: (String) -> [String]
    ) async throws -> GitCommandResult {
        guard state == .connected, let wrapper else { throw failure ?? RemoteConnectionError(.unavailable) }
        guard !requiresReconciliation else { throw RemoteConnectionError(.interruptedWrite) }

        try await check()

        return try await runOperation(
            command(wrapper),
            arguments: arguments,
            input: input,
            inputFile: inputFile,
            acceptedExitCodes: acceptedExitCodes,
            writing: true,
            onOutput: { _ in }
        )
    }
}
