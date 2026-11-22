import Foundation

// MARK: - Inspection

extension RemoteConnection {
    /// 一次往返检查多个远端路径是否存在，状态文件读取据此跳过不存在的文件。
    func inspect(_ paths: [String]) async throws -> [Bool] {
        try Task.checkCancellation()

        if repository == nil {
            _ = try await open()
        }

        if let canonical {
            return try await canonical.inspect(paths)
        }

        let location = RepositoryLocation.remote(host: host, path: repository?.path ?? requestedPath)
        return try await RepositoryOperationQueue.shared.perform(at: location, writing: false) {
            try await self.inspectConnected(paths)
        }
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

    /// 获得主机槽后再确认连接状态；不另外确认主连接，主连接失效时检查以 SSH 的 255 结束，同样转为不可用状态。
    private func inspectConnected(_ paths: [String]) async throws -> [Bool] {
        guard state == .connected else { throw failure ?? RemoteConnectionError(.unavailable) }

        do {
            return try await inspectFlags(paths)
        } catch let error as RemoteConnectionError where error.kind == .unavailable {
            failure = error
            updateState(.unavailable)
            throw error
        }
    }
}
