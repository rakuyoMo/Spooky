import Foundation
import Subprocess
import Synchronization
import Testing

@testable import SpookyKit

// MARK: - RepositoryLFSTests

/// Git LFS：找不到或版本不足时在执行前报出能力缺失；启用、跟踪规则、对象的推送、获取与拉取，以及带 LFS 的克隆，都由仓库所在机器上的 Git LFS 完成。
///
/// 用到真实 git-lfs 的测试在测试进程的 PATH 与 Homebrew 的默认位置里都找不到它时跳过；找到的目录经自定义变量 PATH 交给 Git，与 App 修复 PATH 的方式相同。
struct RepositoryLFSTests {
    /// 找不到 git-lfs 时状态里没有版本；写操作报出能力缺失并带上 `git lfs version` 的原文，不改动仓库。
    @Test("找不到 Git LFS")
    func unavailable() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        try await temporary.initialize()
        let root = temporary.directory.path
        let lfs = RepositoryLFS(runner: lfsRunner(at: root, searchPath: "/usr/bin:/bin"))

        let status = try await lfs.status()
        #expect(status.version == nil && !status.isSupported && !status.isEnabled)

        let error = await #expect(throws: LFSError.self) { try await lfs.track(["*.psd"]) }

        guard case .unavailable(let result) = error else {
            Issue.record("找不到 Git LFS 时应报出能力缺失")
            return
        }

        #expect(result.arguments == ["lfs", "version"] && result.exitCode == 1)
        #expect(!FileManager.default.fileExists(atPath: root + "/.gitattributes"))
    }

    /// 版本低于 2.9.0 同样算能力缺失；状态里仍写出它报告的版本。
    @Test("版本不足")
    func outdated() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        try await temporary.initialize()

        // 假的 git-lfs 只会报出旧版本
        let directory = temporary.directory.appending(path: "bin")
        let program = directory.appending(path: "git-lfs")
        let version = "git-lfs/2.8.0 (GitHub; darwin arm64; go 1.12.7)"

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try Data("#!/bin/sh\necho '\(version)'\n".utf8).write(to: program)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: program.path)

        let runner = lfsRunner(at: temporary.directory.path, searchPath: directory.path + ":/usr/bin:/bin")
        let lfs = RepositoryLFS(runner: runner)

        let status = try await lfs.status()
        #expect(status.version == version && !status.isSupported)

        await #expect(throws: LFSError.self) { try await lfs.install() }
        #expect(!(try await lfs.status().isEnabled))
    }

    /// 只认 `git-lfs/` 开头、至少三段数字的版本，按数值逐段比较。
    @Test("比较版本")
    func versions() {
        #expect(RepositoryLFS.isSupported("git-lfs/3.8.1 (GitHub; darwin arm64; go 1.27.3)"))
        #expect(RepositoryLFS.isSupported("git-lfs/2.9.0 (GitHub; linux amd64; go 1.12.7)"))
        #expect(RepositoryLFS.isSupported("git-lfs/2.10.0"))
        #expect(RepositoryLFS.isSupported("git-lfs/3.5.0-rc1 (GitHub; darwin arm64; go 1.21)"))
        #expect(!RepositoryLFS.isSupported("git-lfs/2.8.9 (GitHub; darwin arm64; go 1.12)"))
        #expect(!RepositoryLFS.isSupported("git-lfs/2.9"))
        #expect(!RepositoryLFS.isSupported("git-lfs/x.y.z"))
        #expect(!RepositoryLFS.isSupported("git: 'lfs' is not a git command. See 'git --help'."))
    }

    /// 启用只写仓库本地的过滤器与钩子；规则写进根目录的 `.gitattributes`，含空格的模式与逐字文件名按 Git LFS 的写法转义；
    /// 去掉规则后读回核对，Git LFS 认不出的转义规则报出仍然留着。
    @Test("启用与跟踪规则", .enabled(if: LFSProgram.directory != nil, "需要 git-lfs"))
    func trackingPatterns() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        try await temporary.initialize()
        let root = temporary.directory.path
        let lfs = RepositoryLFS(runner: lfsRunner(at: root))

        var status = try await lfs.status()
        #expect(status.isSupported && !status.isEnabled)

        try await lfs.install()
        try await lfs.update()

        status = try await lfs.status()
        #expect(status.isEnabled)
        #expect(try String(contentsOfFile: root + "/.git/hooks/pre-push", encoding: .utf8).contains("git lfs pre-push"))

        try await lfs.track(["*.psd", "设计 稿/*.sketch"])
        try await lfs.track(files: ["图 [1].bin"])

        let literal = #"图[[:space:]]\[1\].bin"#
        let tracked = try attributes(in: root)

        // 同一次 track 传入的几个模式，Git LFS 写进文件的先后不固定，排序后比较
        #expect(tracked.sorted() == ["*.psd", "设计[[:space:]]稿/*.sketch", literal].sorted())

        // 列表里显示的就是文件里写着的模式，去掉它们即可停止跟踪
        try await lfs.untrack(["*.psd", "设计[[:space:]]稿/*.sketch"])
        #expect(try attributes(in: root) == [literal])

        await #expect(throws: LFSError.patternsRemain([literal])) { try await lfs.untrack([literal]) }
    }

    /// 推送只上传 LFS 对象；克隆得到指针文件后，获取只下载对象，拉取把指针换成内容；传输进度留在输出里。
    @Test("推送、获取与拉取", .enabled(if: LFSProgram.directory != nil, "需要 git-lfs"))
    func transfer() async throws {
        let root = try transferDirectory()
        defer { try? FileManager.default.removeItem(atPath: root) }

        let remote = root + "/远 端.git"
        let content = try await makeSource(in: root, remote: remote)

        // 只推送引用时远端还没有 LFS 对象
        let work = lfsRunner(at: root + "/工作 区")
        _ = try await work.run(["push", "--no-verify", "-q", "origin", "main"])
        #expect(objectCount(in: remote + "/lfs/objects") == 0)

        let pushed = OutputLog()
        try await RepositoryLFS(runner: work).push(to: "origin", onOutput: pushed.append)
        #expect(objectCount(in: remote + "/lfs/objects") == 1)

        // 输出不是终端时 Git LFS 只写最后一行；强制写出进度后才有开始传输时的 0/1
        #expect(pushed.text.contains("Uploading LFS objects") && pushed.text.contains("(0/1)"))

        // 没有全局过滤器时克隆只检出指针文件
        let path = root + "/克 隆"
        _ = try await lfsRunner(at: root).run(["clone", "-q", "--", remote, path])

        let file = URL(fileURLWithPath: path + "/大 文件.bin")
        let pointer = try Data(contentsOf: file)
        #expect(pointer.starts(with: Data("version https://git-lfs.github.com/spec/v1".utf8)))

        let lfs = RepositoryLFS(runner: lfsRunner(at: path))
        try await lfs.install()

        let fetched = OutputLog()
        try await lfs.fetch(from: "origin", onOutput: fetched.append)
        #expect(fetched.text.contains("Downloading LFS objects") && fetched.text.contains("(0/1)"))
        #expect(objectCount(in: path + "/.git/lfs/objects") == 1)
        #expect(try Data(contentsOf: file) == pointer)

        try await lfs.pull(from: "origin")
        #expect(try Data(contentsOf: file) == content)
    }

    /// 选了 LFS 的克隆在检出时由过滤器换出内容：目标机器的全局配置登记了过滤器，与 `git lfs install` 之后相同。
    @Test("带 LFS 的克隆", .enabled(if: LFSProgram.directory != nil, "需要 git-lfs"))
    func cloneWithLFS() async throws {
        let root = try transferDirectory()
        defer { try? FileManager.default.removeItem(atPath: root) }

        let remote = root + "/远 端.git"
        let content = try await makeSource(in: root, remote: remote)
        _ = try await lfsRunner(at: root + "/工作 区").run(["push", "-q", "origin", "main"])

        // 全局配置只有 LFS 过滤器
        let global = root + "/全局.gitconfig"
        let configure = lfsRunner(at: root)

        for (key, value) in [
            ("filter.lfs.clean", "git-lfs clean -- %f"),
            ("filter.lfs.smudge", "git-lfs smudge -- %f"),
            ("filter.lfs.process", "git-lfs filter-process"),
            ("filter.lfs.required", "true"),
        ] {
            _ = try await configure.run(["config", "--file", global, key, value])
        }

        let path = root + "/克 隆"
        let clone = RepositoryClone(url: remote, destination: .local(path: path), options: CloneOptions(lfs: true))
        _ = try await clone.start(credentialHandler: nil, onProgress: nil) {
            lfsRunner(at: $0.path, globalConfig: global)
        }.value

        #expect(try Data(contentsOf: URL(fileURLWithPath: path + "/大 文件.bin")) == content)
    }
}

// MARK: - LFSProgram

/// 测试机器上的 git-lfs。
private enum LFSProgram {
    /// git-lfs 所在的目录：先找测试进程的 PATH，再找 Homebrew 的两处默认位置；都没有时为 nil。
    static let directory: String? = {
        let inherited = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []

        return (inherited + ["/opt/homebrew/bin", "/usr/local/bin"]).first {
            FileManager.default.isExecutableFile(atPath: $0 + "/git-lfs")
        }
    }()
}

// MARK: - OutputLog

/// 收集命令的输出：Git LFS 的传输进度按情形写进标准输出或标准错误。
private final class OutputLog: Sendable {
    /// 收到的数据。
    private let data = Mutex(Data())

    /// 收到的全部文本。
    var text: String {
        data.withLock { String(decoding: $0, as: UTF8.self) }
    }

    /// 记下一块输出。
    func append(_ event: GitOutputEvent) {
        switch event {
        case .standardOutput(let chunk), .standardError(let chunk):
            data.withLock { $0.append(chunk) }
        }
    }
}

// MARK: - Helpers

/// 忽略用户与系统配置的执行器，只在给定的 PATH 里找程序。
///
/// - Parameters:
///   - path: 执行命令的目录。
///   - searchPath: 交给 Git 的 PATH；默认是 git-lfs 所在的目录加上系统目录。
///   - globalConfig: 当作全局配置的文件。
private func lfsRunner(
    at path: String,
    searchPath: String = (LFSProgram.directory ?? "/usr/bin") + ":/usr/bin:/bin",
    globalConfig: String = "/dev/null"
) -> GitRunner {
    GitRunner(
        location: .local(path: path),
        settings: LocalExecutionSettings(customVariables: ["PATH": searchPath]),
        environment: .inherit.updating([
            "GIT_CONFIG_GLOBAL": globalConfig,
            "GIT_CONFIG_SYSTEM": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_PARAMETERS": nil,
            "GIT_CONFIG_COUNT": nil,
            "GIT_ATTR_NOSYSTEM": "1",
        ])
    )
}

/// 建出裸仓库作远端，并在 `工作 区` 里提交一个交给 LFS 的文件；工作区的 origin 指向远端，还没有推送。
///
/// - Returns: 交给 LFS 的文件内容。
private func makeSource(in root: String, remote: String) async throws -> Data {
    let path = root + "/工作 区"
    let setup = lfsRunner(at: root)

    _ = try await setup.run(["-c", "init.templateDir=", "init", "-q", "--bare", "-b", "main", "--", remote])
    _ = try await setup.run(["-c", "init.templateDir=", "init", "-q", "-b", "main", "--", path])

    let work = lfsRunner(at: path)
    _ = try await work.run(["config", "--local", "user.name", "Spooky Test"])
    _ = try await work.run(["config", "--local", "user.email", "spooky@example.invalid"])
    _ = try await work.run(["remote", "add", "origin", remote])

    let lfs = RepositoryLFS(runner: work)
    try await lfs.install()
    try await lfs.track(["*.bin"])

    // 不可压缩的内容，确认存进 LFS 的是对象而不是原文
    let content = Data((0 ..< 65_536).map { _ in UInt8.random(in: 0 ... 255) })
    try content.write(to: URL(fileURLWithPath: path + "/大 文件.bin"))

    _ = try await work.run(["add", "--", ".gitattributes", "大 文件.bin"])
    _ = try await work.run(["commit", "-q", "-m", "添加大文件"])

    let stored = try await work.run(["cat-file", "-p", "HEAD:大 文件.bin"])
    #expect(stored.starts(with: Data("version https://git-lfs.github.com/spec/v1".utf8)))

    return content
}

/// 传输测试独占的临时目录，路径含空格、中文与引号。
///
/// 不用 ``TemporaryRepository`` 的目录：仓库路径含 `*`、`?` 或 `\[` 时，Git LFS 扫描引用会报 “syntax error in pattern”。
private func transferDirectory() throws -> String {
    let directory = FileManager.default.temporaryDirectory.appending(path: "Spooky-LFS-\(UUID().uuidString)-仓 库'\"")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.path
}

/// `.gitattributes` 里交给 LFS 的规则。
private func attributes(in root: String) throws -> [String] {
    try RepositorySettings.lfsPatterns(in: Data(contentsOf: URL(fileURLWithPath: root + "/.gitattributes")))
}

/// 目录下的文件数；目录不存在时为 0。
private func objectCount(in directory: String) -> Int {
    let enumerator = FileManager.default.enumerator(
        at: URL(fileURLWithPath: directory),
        includingPropertiesForKeys: [.isRegularFileKey]
    )

    return (enumerator?.allObjects as? [URL] ?? []).count {
        (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
    }
}
