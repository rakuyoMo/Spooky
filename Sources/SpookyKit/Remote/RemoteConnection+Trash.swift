import Foundation

// MARK: - Trash

extension RemoteConnection {
    /// 逐项执行 macOS 的 `/usr/bin/trash -v`，每一项的输出后补一个 NUL，输出与传入的路径一一对应；任何一项失败时以它的退出码结束。
    static let trashScript = """
        for path do
            /usr/bin/trash -v "$path" || exit
            printf '\\0'
        done
        """

    /// 把废纸篓里的项移回原处：参数两两一组，依次是废纸篓里的位置与原来的路径。
    ///
    /// 先核对全部：任何一项不在废纸篓里、或原位置已被占用时以 3 退出，一项也不移动。
    static let putBackScript = """
        check() {
            while [ "$#" -gt 1 ]; do
                { [ -e "$1" ] || [ -L "$1" ]; } || exit 3
                if [ -e "$2" ] || [ -L "$2" ]; then exit 3; fi
                shift 2
            done
        }

        move() {
            while [ "$#" -gt 1 ]; do
                parent=${2%/*}
                /bin/mkdir -p -- "${parent:-/}" && /bin/mv -- "$1" "$2" || exit
                shift 2
            done
        }

        check "$@"
        move "$@"
        """

    /// 从 ``trashScript`` 的输出里取出各项在废纸篓里的位置；某一项的输出格式不符时它的位置为 nil。
    ///
    /// - Parameters:
    ///   - paths: 传给脚本的路径。
    ///   - output: 脚本的标准输出，每一项是 `# Moved "<原路径>" to "<废纸篓里的路径>"` 加换行，以 NUL 隔开。
    static func trashedItems(_ paths: [String], output: Data) -> [TrashedItem] {
        let records = output
            .split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }

        return paths.enumerated().map { index, path in
            TrashedItem(path: path, location: index < records.count ? location(of: path, in: records[index]) : nil)
        }
    }

    /// 把 B 上的文件或目录移进 B 的废纸篓，使用连接体检找到的程序。
    ///
    /// macOS 的 `/usr/bin/trash -v` 写出每一项在废纸篓里的位置；Linux 上的程序不报告位置，这些项的位置为 nil。
    ///
    /// - Parameter paths: B 上的绝对路径。
    /// - Throws: B 上没有可用的废纸篓时抛出 ``RepositoryFileError/trashUnavailable``。
    func moveToTrash(_ paths: [String]) async throws -> [TrashedItem] {
        if repository == nil { _ = try await open() }
        if let canonical { return try await canonical.moveToTrash(paths) }

        guard let trash = environment?.trash else {
            throw RepositoryFileError.trashUnavailable
        }

        switch trash {
        case .macOS:
            let result = try await runProgram(["/bin/sh", "-c", Self.trashScript, "spooky-trash"] + paths)
            return Self.trashedItems(paths, output: result.standardOutput)

        case .gio(let program):
            _ = try await runProgram([program, "trash"] + paths)
            return paths.map { TrashedItem(path: $0, location: nil) }

        case .trashPut(let program):
            _ = try await runProgram([program] + paths)
            return paths.map { TrashedItem(path: $0, location: nil) }
        }
    }

    /// 把 B 的废纸篓里的项移回原处，缺少的上级目录一并建出；先核对全部，任何一项不满足时一项也不移动。
    ///
    /// - Parameter moves: 每一项在废纸篓里的位置与原来的路径，都是 B 上的绝对路径。
    /// - Throws: 有的项已不在废纸篓里或原位置已被占用时抛出 ``RepositoryFileError/trashedItemsUnavailable``。
    func putBack(_ moves: [(from: String, to: String)]) async throws {
        if repository == nil { _ = try await open() }

        if let canonical {
            try await canonical.putBack(moves)
            return
        }

        let result = try await runProgram(
            ["/bin/sh", "-c", Self.putBackScript, "spooky-put-back"] + moves.flatMap { [$0.from, $0.to] },
            acceptedExitCodes: [0, 3]
        )

        guard result.exitCode == 0 else {
            throw RepositoryFileError.trashedItemsUnavailable
        }
    }
}

// MARK: - Private

extension RemoteConnection {
    /// 在 B 上执行废纸篓相关的程序：与 Git 写命令一样占用本仓库的写槽与主机槽，经包装器在独立进程组里运行。
    private func runProgram(_ program: [String], acceptedExitCodes: Set<Int32> = [0]) async throws -> GitCommandResult {
        let location = RepositoryLocation.remote(host: host, path: repository?.path ?? requestedPath)

        return try await RepositoryOperationQueue.shared.perform(at: location, writing: true) {
            try await self.runConnectedProgram(program, acceptedExitCodes: acceptedExitCodes)
        }
    }

    /// 获得执行槽后再次确认连接与写入核对状态，排队期间的断线不能被忽略。
    private func runConnectedProgram(_ program: [String], acceptedExitCodes: Set<Int32>) async throws -> GitCommandResult {
        guard state == .connected else { throw failure ?? RemoteConnectionError(.unavailable) }
        guard !requiresReconciliation else { throw RemoteConnectionError(.interruptedWrite) }

        try await check()

        return try await runOperation(
            program,
            arguments: ["trash"],
            acceptedExitCodes: acceptedExitCodes,
            writing: true,
            onOutput: { _ in }
        )
    }
}

// MARK: - Helpers

extension RemoteConnection {
    /// 一项的输出：去掉 `# Moved "<原路径>" to "` 与结尾的引号、换行，剩下的就是废纸篓里的绝对路径。
    private static func location(of path: String, in record: String) -> String? {
        let prefix = "# Moved \"" + path + "\" to \""

        guard record.hasPrefix(prefix) else { return nil }

        var rest = record.dropFirst(prefix.count)

        if rest.hasSuffix("\n") { rest = rest.dropLast() }

        guard rest.count > 1, rest.hasSuffix("\""), rest.hasPrefix("/") else { return nil }

        return String(rest.dropLast())
    }
}
