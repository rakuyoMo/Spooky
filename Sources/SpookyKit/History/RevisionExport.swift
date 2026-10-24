import Foundation
import Synchronization

// MARK: - RevisionExport

/// 把某个版本的文件导出、打成归档或存成补丁，写到本机；服务器仓库的输出由服务器上的 Git 流回本机。
///
/// 输出边读边写进目标所在卷上的临时位置，完成后再替换目标；失败或取消时删除写了一半的内容。
public struct RevisionExport: Sendable {
    /// 归档格式。
    public enum ArchiveFormat: String, Sendable {
        /// zip 归档，访达可以直接打开。
        case zip

        /// tar 归档。
        case tar
    }

    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 创建导出服务，不立即访问仓库。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// `format-patch` 的文件名：“四位序号-标题” 最多 57 个字符，再加上 `.patch`；标题已由 `%f` 整理成 ASCII。
    static func patchName(_ number: Int, subject: String) -> String {
        String((String(format: "%04d-", number) + subject).prefix(57)) + ".patch"
    }

    /// 把一个版本或其中的部分路径打成归档。
    ///
    /// - Parameters:
    ///   - revision: 提交的完整哈希。
    ///   - paths: 树中存储的路径；为空时归档整棵树。
    ///   - destination: 本机上的目标文件。
    public func archive(
        _ revision: String,
        paths: [String] = [],
        format: ArchiveFormat,
        to destination: URL
    ) async throws {
        guard GitObjectID.isValid(revision) else {
            throw RepositoryReadError.invalidQuery
        }

        try await Self.replacing(destination) { temporary in
            try await runner.stream(archiveArguments(revision, paths: paths, format: format), to: temporary)
        }
    }

    /// 把一个版本或其中的部分路径导出成本机目录，目录结构与仓库一致：先取 tar 归档，再在本机解包。
    ///
    /// - Parameter destination: 本机上的目标目录，已存在时整个替换。
    public func export(_ revision: String, paths: [String] = [], to destination: URL) async throws {
        guard GitObjectID.isValid(revision) else {
            throw RepositoryReadError.invalidQuery
        }

        try await Self.replacing(destination) { folder in
            let tarball = folder.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".tar")
            defer { try? FileManager.default.removeItem(at: tarball) }

            try await runner.stream(archiveArguments(revision, paths: paths, format: .tar), to: tarball)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)

            // 本机的 bsdtar 默认拒绝绝对路径、“..” 与经由符号链接写到目录外
            _ = try await CommandExecutor.execute(
                executable: "/usr/bin/tar",
                processArguments: ["-x", "-f", tarball.path, "-C", folder.path],
                arguments: ["tar"]
            )
        }
    }

    /// 每个提交存成一个补丁文件，文件名与 `format-patch` 写进目录时相同：四位序号加整理过的标题。
    ///
    /// 合并提交没有补丁，不写文件，序号仍按传入的位置计。
    ///
    /// - Parameters:
    ///   - commits: 提交的完整哈希，按传入顺序编号；调用方按从旧到新传入。
    ///   - omitsPrefixes: 补丁里的路径不带 `a/`、`b/` 前缀。
    ///   - directory: 本机上的目标目录，同名文件被替换。
    /// - Returns: 实际写入的补丁文件。
    public func savePatches(
        _ commits: [String],
        omitsPrefixes: Bool,
        to directory: URL
    ) async throws -> [URL] {
        guard !commits.isEmpty, commits.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.invalidQuery
        }

        let details = try await patchDetails(of: commits)
        var saved: [URL] = []

        // format-patch 遇到合并提交会跳过它、改取更早的提交，合并提交在这里先排除
        for (index, commit) in commits.enumerated() {
            guard let detail = details[commit], !detail.isMerge else {
                continue
            }

            let destination = directory.appendingPathComponent(Self.patchName(index + 1, subject: detail.subject))

            try await Self.replacing(destination) { temporary in
                try await runner.stream(
                    ["format-patch", "--stdout", "-1"] + (omitsPrefixes ? ["--no-prefix"] : []) + [commit],
                    to: temporary
                )
            }

            saved.append(destination)
        }

        return saved
    }
}

// MARK: - Private

extension RevisionExport {
    /// 在目标所在卷上的临时目录里写好，再替换目标；临时目录无论成败都删除。
    private static func replacing(_ destination: URL, write: (URL) async throws -> Void) async throws {
        let staging = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: destination.deletingLastPathComponent(),
            create: true
        )

        defer { try? FileManager.default.removeItem(at: staging) }

        let item = staging.appendingPathComponent(destination.lastPathComponent)
        try await write(item)
        try Task.checkCancellation()

        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: item)
        } else {
            try FileManager.default.moveItem(at: item, to: destination)
        }
    }

    /// 归档参数：路径按字面匹配并保留树中存储的 Unicode 形式，读取工作区里的 `.gitattributes`。
    private func archiveArguments(_ revision: String, paths: [String], format: ArchiveFormat) -> [String] {
        RepositoryFileViews.storedPathOptions
            + ["archive", "--worktree-attributes", "--format=" + format.rawValue, revision]
            + (paths.isEmpty ? [] : ["--"] + paths)
    }

    /// 各提交是否为合并提交，以及 `%f` 整理过的标题；提交信息只由哈希决定，按哈希复用。
    private func patchDetails(of commits: [String]) async throws -> [String: (subject: String, isMerge: Bool)] {
        let output = try await runner.immutableRun(
            RepositoryHistory.logOptions + [
                "log", "--no-walk=unsorted", "--no-color", "--no-patch", "-z", "--format=tformat:%H%x00%P%x00%f",
                "--stdin", "--",
            ],
            input: Data((commits.joined(separator: "\n") + "\n").utf8)
        )

        guard !output.isEmpty else {
            return [:]
        }

        let fields = output.dropLast()
            .split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }

        guard output.last == 0, fields.count.isMultiple(of: 3) else {
            throw RepositoryReadError.malformedOutput("log")
        }

        var details: [String: (subject: String, isMerge: Bool)] = [:]

        for start in stride(from: 0, to: fields.count, by: 3) {
            details[fields[start]] = (fields[start + 2], fields[start + 1].split(separator: " ").count > 1)
        }

        return details
    }
}

// MARK: - Streaming

extension GitRunner {
    /// 把只读命令的标准输出边读边写进本机文件，不整份留在内存里；失败或取消时删除写了一半的文件。
    func stream(_ arguments: [String], to destination: URL) async throws {
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: destination.path])
        }

        let sink = try OutputFileSink(destination)

        do {
            _ = try await CommandExecutor.$streamsStandardOutput.withValue(true) {
                try await execute(arguments) { event in
                    if case .standardOutput(let data) = event {
                        sink.write(data)
                    }
                }
            }

            try sink.finish()
        } catch {
            try? sink.finish()
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}

// MARK: - OutputFileSink

/// 输出回调里写文件；回调不能抛错，第一次写入失败记下来，之后的数据丢弃，结束时再报告。
private final class OutputFileSink: Sendable {
    /// 打开的文件与第一次写入失败。
    private let state: Mutex<(handle: FileHandle?, failure: (any Error)?)>

    /// 以写入方式打开已创建的空文件。
    init(_ url: URL) throws {
        state = Mutex((try FileHandle(forWritingTo: url), nil))
    }

    /// 追加一段输出。
    func write(_ data: Data) {
        state.withLock { state in
            guard state.failure == nil, let handle = state.handle else {
                return
            }

            do {
                try handle.write(contentsOf: data)
            } catch {
                state.failure = error
            }
        }
    }

    /// 关闭文件，报告写入中的失败。
    func finish() throws {
        let failure = try state.withLock { state -> (any Error)? in
            try state.handle?.close()
            state.handle = nil
            return state.failure
        }

        if let failure {
            throw failure
        }
    }
}
