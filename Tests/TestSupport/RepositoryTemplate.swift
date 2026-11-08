import Foundation
import Synchronization

// MARK: - RepositoryTemplate

/// 空的测试仓库：每种对象格式在测试进程里只经 Git 建一次，之后每个测试直接写出同样的 `.git`。
///
/// 写出的内容与在隔离了系统、用户配置的环境里执行 `git -c init.templateDir= init -q -b main --object-format=<格式>`，
/// 再在仓库配置里写入提交身份、关掉提交签名的结果相同；每个测试因此省去四次 Git 调用。
public enum RepositoryTemplate {
    /// 仓库配置里的提交者名字。
    public static let userName = "Spooky Test"

    /// 仓库配置里的提交者邮箱。
    public static let userEmail = "spooky@example.invalid"

    /// 每种对象格式的 `.git` 内容，第一次用到时建出。
    private static let snapshots = Mutex<[String: Task<[Entry], any Error>]>([:])

    /// 在目录里写出空仓库的 `.git`，目录本身须已存在。
    ///
    /// - Parameters:
    ///   - directory: 仓库的工作区。
    ///   - objectFormat: 对象格式，`sha1` 或 `sha256`。
    public static func create(at directory: URL, objectFormat: String = "sha1") async throws {
        let entries = try await snapshot(objectFormat).value
        let root = directory.appending(path: ".git", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)

        for entry in entries {
            let url = root.appending(path: entry.path)

            if let contents = entry.contents {
                try contents.write(to: url)
            } else {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }
}

// MARK: - Entry

extension RepositoryTemplate {
    /// `.git` 里的一项。
    private struct Entry: Sendable {
        /// 相对 `.git` 的路径。
        let path: String

        /// 文件内容；目录为 nil。
        let contents: Data?
    }

    /// 建模板时 Git 以非零状态退出。
    private struct GitFailure: Error, CustomStringConvertible {
        /// Git 的参数。
        let arguments: [String]

        /// 退出码。
        let status: Int32

        /// 失败的命令与退出码。
        var description: String {
            "git \(arguments.joined(separator: " ")) 以 \(status) 退出"
        }
    }
}

// MARK: - Private

extension RepositoryTemplate {
    /// 取出对象格式对应的模板，还没建过时开始建。
    private static func snapshot(_ objectFormat: String) -> Task<[Entry], any Error> {
        snapshots.withLock { tasks in
            if let task = tasks[objectFormat] {
                return task
            }

            let task = Task { try await build(objectFormat) }
            tasks[objectFormat] = task
            return task
        }
    }

    /// 在临时目录里经 Git 建一个空仓库，读出 `.git` 的全部内容后删掉临时目录。
    private static func build(_ objectFormat: String) async throws -> [Entry] {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-template-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        try await git(
            ["-c", "init.templateDir=", "init", "-q", "-b", "main", "--object-format=" + objectFormat],
            in: directory
        )
        try await git(["config", "--local", "user.name", userName], in: directory)
        try await git(["config", "--local", "user.email", userEmail], in: directory)
        try await git(["config", "--local", "commit.gpgSign", "false"], in: directory)

        let root = directory.appending(path: ".git", directoryHint: .isDirectory)
        let paths = try FileManager.default.subpathsOfDirectory(atPath: root.path).sorted()

        // 路径排过序，目录排在它里面的文件之前
        return try paths.map { path in
            let url = root.appending(path: path)
            let isDirectory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false

            return Entry(path: path, contents: isDirectory ? nil : try Data(contentsOf: url))
        }
    }

    /// 在目录里执行一条 Git 命令，忽略系统与用户的全局配置。
    private static func git(_ arguments: [String], in directory: URL) async throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        var environment = ProcessInfo.processInfo.environment
        environment["GIT_CONFIG_GLOBAL"] = "/dev/null"
        environment["GIT_CONFIG_SYSTEM"] = "/dev/null"
        environment["GIT_CONFIG_NOSYSTEM"] = "1"
        environment["GIT_CONFIG_PARAMETERS"] = nil
        environment["GIT_CONFIG_COUNT"] = nil
        environment["GIT_DIR"] = nil
        environment["GIT_WORK_TREE"] = nil
        process.environment = environment

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            process.terminationHandler = { process in
                guard process.terminationStatus == 0 else {
                    continuation.resume(throwing: GitFailure(arguments: arguments, status: process.terminationStatus))
                    return
                }

                continuation.resume()
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
