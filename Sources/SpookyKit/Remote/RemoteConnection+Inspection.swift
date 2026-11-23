import Foundation

// MARK: - Inspection

extension RemoteConnection {
    /// 一次往返检查多个远端路径是否存在，状态文件读取据此跳过不存在的文件。
    func inspect(_ paths: [String]) async throws -> [Bool] {
        try await performQuery { try await $0.inspectFlags(paths) }
    }

    /// 包装器逐行返回存在标记，行数必须与输入路径一一对应，只检查存在性、不读内容。
    func inspectFlags(_ paths: [String]) async throws -> [Bool] {
        guard let wrapper else {
            throw RemoteConnectionError(.unavailable)
        }

        let inspected = try await probe([wrapper, "inspect"] + paths, kind: .protocolFailure)
        let flags = String(decoding: inspected.standardOutput, as: UTF8.self).split(separator: "\n")

        guard flags.count == paths.count, flags.allSatisfy({ $0 == "0" || $0 == "1" }) else {
            throw RemoteConnectionError(.protocolFailure, result: inspected)
        }

        return flags.map { $0 == "1" }
    }

    /// 在 B 上执行一次只读查询：与只读命令一样占用主机槽，子目录的连接交给规范连接执行。
    ///
    /// - Parameter query: 在执行查询的连接上调用。
    /// - Returns: 查询的结果。
    func performQuery<T: Sendable>(
        _ query: @escaping @Sendable (RemoteConnection) async throws -> T
    ) async throws -> T {
        try Task.checkCancellation()

        if repository == nil {
            _ = try await open()
        }

        if let canonical {
            return try await canonical.performQuery(query)
        }

        let location = RepositoryLocation.remote(host: host, path: repository?.path ?? requestedPath)

        return try await RepositoryOperationQueue.shared.perform(at: location, writing: false) {
            try await self.queryConnected(query)
        }
    }
}

// MARK: - Private

extension RemoteConnection {
    /// 获得主机槽后再确认连接状态；不另外确认主连接，主连接失效时查询以 SSH 的 255 结束，同样转为不可用状态。
    private func queryConnected<T: Sendable>(
        _ query: @Sendable (RemoteConnection) async throws -> T
    ) async throws -> T {
        guard state == .connected else { throw failure ?? RemoteConnectionError(.unavailable) }

        do {
            return try await query(self)
        } catch let error as RemoteConnectionError where error.kind == .unavailable {
            failure = error
            updateState(.unavailable)
            throw error
        }
    }
}
