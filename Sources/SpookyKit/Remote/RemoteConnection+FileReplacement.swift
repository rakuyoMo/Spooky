import Foundation

// MARK: - FileReplacement

extension RemoteConnection {
    /// 替换 B 上的一个文件：包装器先把内容写进目标所在目录里独占的临时文件，写完再改名替换，中途出错、断线或取消时原文件不变。
    ///
    /// 与 Git 写命令一样占用本仓库的写槽与主机槽，在独立进程组里运行，取消经包装器确认。
    ///
    /// - Parameters:
    ///   - path: 目标文件的绝对路径；是符号链接时替换它最终指向的文件，已有文件的权限位照旧。
    ///   - file: 本机上存着新内容的文件，ssh 直接从它读取。
    ///   - size: 新内容的字节数，包装器读满才替换。
    func replaceFile(_ path: String, from file: URL, size: Int) async throws {
        if repository == nil { _ = try await open() }

        if let canonical {
            try await canonical.replaceFile(path, from: file, size: size)
            return
        }

        let location = RepositoryLocation.remote(host: host, path: repository?.path ?? requestedPath)

        _ = try await RepositoryOperationQueue.shared.perform(at: location, writing: true) {
            try await self.replaceConnected(path, from: file, size: size)
        }
    }
}

// MARK: - Private

extension RemoteConnection {
    /// 获得执行槽后再次确认连接与写入核对状态，排队期间的断线不能被忽略。
    private func replaceConnected(_ path: String, from file: URL, size: Int) async throws -> GitCommandResult {
        guard state == .connected, let wrapper else { throw failure ?? RemoteConnectionError(.unavailable) }
        guard !requiresReconciliation else { throw RemoteConnectionError(.interruptedWrite) }

        try await check()

        return try await runOperation(
            [wrapper, "replace", path, String(size)],
            arguments: ["replace"],
            inputFile: file,
            writing: true,
            onOutput: { _ in }
        )
    }
}
