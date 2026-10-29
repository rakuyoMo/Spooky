import Foundation
import Synchronization

// MARK: - RevisionExport

/// 把某个版本的文件导出、打成归档或存成补丁，写到本机；服务器仓库的输出由服务器上的 Git 流回本机。
///
/// 输出边读边写进目标所在卷上的临时位置，完成后再替换目标；失败或取消时删除写了一半的内容。
/// 存进仓库根目录的补丁是例外：由仓库所在机器上的 Git 直接写出，服务器仓库的补丁留在服务器上。
public struct RevisionExport: Sendable {
    /// 包住一个提交那一次 `format-patch` 的执行，供调用方在前后记录；参数是提交的完整哈希与这次执行，执行要调用一次。
    public typealias PatchFormatting = @Sendable (
        _ commit: String,
        _ format: () async throws -> Void
    ) async throws -> Void

    /// 归档格式。
    public enum ArchiveFormat: String, Sendable {
        /// zip 归档，访达可以直接打开。
        case zip

        /// tar 归档。
        case tar
    }

    /// `format-patch` 写进目录时封面信的文件名；后缀与补丁一样写死成 `.patch`。
    static let coverLetterName = "0000-cover-letter.patch"

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
    /// 仓库的 `format.coverLetter` 为真时，另写一封 `0000-cover-letter.patch`，补丁标题随之编号；
    /// 每个提交都重写它，留下的是最后一个提交生成的。
    ///
    /// - Parameters:
    ///   - commits: 提交的完整哈希，按传入顺序编号；调用方按从旧到新传入。
    ///   - omitsPrefixes: 补丁里的路径不带 `a/`、`b/` 前缀。
    ///   - directory: 本机上的目标目录，同名文件被替换。
    ///   - formatting: 包住每个提交那一次 `format-patch`；合并提交不执行，也不经过它。默认直接执行。
    /// - Returns: 实际写入的文件；写了封面信时它只出现一次，排在最前。
    public func savePatches(
        _ commits: [String],
        omitsPrefixes: Bool,
        to directory: URL,
        formatting: PatchFormatting = { _, format in try await format() }
    ) async throws -> [URL] {
        guard !commits.isEmpty, commits.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.invalidQuery
        }

        let details = try await patchDetails(of: commits)
        let coverLetter = try await writesCoverLetter()
            ? directory.appendingPathComponent(Self.coverLetterName)
            : nil

        var saved: [URL] = []

        // format-patch 遇到合并提交会跳过它、改取更早的提交，合并提交在这里先排除
        for (index, commit) in commits.enumerated() {
            guard let detail = details[commit], !detail.isMerge else {
                continue
            }

            // 取消后不再执行后面的提交，已写好的补丁保留
            try Task.checkCancellation()

            let destination = directory.appendingPathComponent(Self.patchName(index + 1, subject: detail.subject))

            // 编号与快速保存相同；配了封面信时补丁标题按它写成 [PATCH k/k]
            let arguments = ["format-patch", "--stdout", "--start-number=\(index + 1)", "-1"]
                + (omitsPrefixes ? ["--no-prefix"] : [])
                + [commit]

            var written: URL? = nil

            try await formatting(commit) {
                written = try await savePatch(
                    arguments,
                    of: commit,
                    to: destination,
                    coverLetter: coverLetter
                )
            }

            // 每个提交都重写同一封封面信，只记一次，排在最前
            if let written, !saved.contains(written) {
                saved.insert(written, at: 0)
            }

            saved.append(destination)
        }

        return saved
    }

    /// 每个提交存成一个补丁文件，由仓库所在机器上的 Git 直接写进仓库根目录；服务器仓库的补丁写在服务器上。
    ///
    /// 文件名由 Git 生成，是四位序号加整理过的标题，同名文件被覆盖；合并提交不写文件，序号仍按传入的位置计。
    /// 仓库的 `format.coverLetter` 为真时，Git 另写一封 `0000-cover-letter.patch`，补丁标题随之编号；
    /// 每个提交都重写它，留下的是最后一个提交生成的。
    ///
    /// - Parameters:
    ///   - commits: 提交的完整哈希，按传入顺序编号；调用方按从旧到新传入。
    ///   - omitsPrefixes: 补丁里的路径不带 `a/`、`b/` 前缀。
    ///   - formatting: 包住每个提交那一次 `format-patch`；合并提交不执行，也不经过它。默认直接执行。
    /// - Returns: 实际写入的文件在仓库所在机器上的路径；写了封面信时它只出现一次，排在最前。
    public func savePatchesToRepositoryRoot(
        _ commits: [String],
        omitsPrefixes: Bool,
        formatting: PatchFormatting = { _, format in try await format() }
    ) async throws -> [String] {
        guard !commits.isEmpty, commits.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.invalidQuery
        }

        let details = try await patchDetails(of: commits)
        var saved: [String] = []

        // format-patch 遇到合并提交会跳过它、改取更早的提交，合并提交在这里先排除
        for (index, commit) in commits.enumerated() {
            guard let detail = details[commit], !detail.isMerge else {
                continue
            }

            // 取消后不再执行后面的提交，已写好的补丁保留
            try Task.checkCancellation()

            // 后缀写死，仓库配置的 format.suffix 不改变文件名；封面信随仓库的 format.coverLetter
            let arguments = [
                "format-patch",
                "-o", runner.location.path,
                "--start-number=\(index + 1)",
                "--suffix=.patch",
                "-1",
            ]

            var output = Data()

            // Git 写完文件后在标准输出逐行打出它的路径，封面信排在补丁之前
            try await formatting(commit) {
                output = try await runner.run(
                    arguments + (omitsPrefixes ? ["--no-prefix"] : []) + [commit]
                )
            }

            let paths = String(decoding: output, as: UTF8.self)
                .split(separator: "\n")
                .map(String.init)

            // 每个提交都重写同一封封面信，路径只留第一次的
            for path in paths where !saved.contains(path) {
                saved.append(path)
            }
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

    /// 把两封邮件在第二封的 `From <哈希> Mon Sep 17 00:00:00 2001` 一行拆开：之前的替换封面信，其余写进补丁。
    ///
    /// 两封的这一行都写这个提交的哈希，第一封从文件开头开始；文件按映射读取，不整段载入内存。
    ///
    /// - Returns: 写了封面信时是它；找不到第二封时整段移作补丁，返回 nil。
    private static func splitCoverLetter(
        _ mail: URL,
        of commit: String,
        coverLetter: URL,
        patch: URL
    ) async throws -> URL? {
        let content = try Data(contentsOf: mail, options: .alwaysMapped)
        let boundary = Data("\nFrom \(commit) Mon Sep 17 00:00:00 2001\n".utf8)

        guard let separator = content.range(of: boundary) else {
            try FileManager.default.moveItem(at: mail, to: patch)
            return nil
        }

        // 分界的换行属于封面信
        let start = separator.lowerBound + 1

        try await replacing(coverLetter) { temporary in
            try content[..<start].write(to: temporary)
        }

        try content[start...].write(to: patch)
        return coverLetter
    }

    /// 把一个提交的 `format-patch --stdout` 写成补丁文件，失败或取消时不留下写了一半的文件。
    ///
    /// 给了封面信的位置时，标准输出是封面信在前、补丁在后的两封邮件，先写进同一临时目录，再拆成两个文件。
    ///
    /// - Returns: 写了封面信时是它，否则为 nil。
    private func savePatch(
        _ arguments: [String],
        of commit: String,
        to destination: URL,
        coverLetter: URL?
    ) async throws -> URL? {
        var written: URL? = nil

        try await Self.replacing(destination) { temporary in
            guard let coverLetter else {
                try await runner.stream(arguments, to: temporary)
                return
            }

            // 两封邮件先整段写在补丁旁边，随临时目录一起删除
            let mail = temporary.appendingPathExtension("mbox")
            try await runner.stream(arguments, to: mail)

            written = try await Self.splitCoverLetter(
                mail,
                of: commit,
                coverLetter: coverLetter,
                patch: temporary
            )
        }

        return written
    }

    /// 仓库生效的配置是否让 `format-patch` 写封面信。
    ///
    /// 按 Git 的布尔写法判断；`auto` 不是布尔写法，判为假，与 Git 只存一个提交时不写封面信相同。
    private func writesCoverLetter() async throws -> Bool {
        let pattern = "^format\\.coverletter$"

        let result = try await runner.execute(
            ["config", "-z", "--get-regexp", pattern],
            acceptedExitCodes: [0, 1]
        )

        let values = try ConfigRecords.parse(
            result.standardOutput,
            pattern: pattern,
            context: "format config"
        )

        return values["format.coverletter"].map(ConfigRecords.boolean) ?? false
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
