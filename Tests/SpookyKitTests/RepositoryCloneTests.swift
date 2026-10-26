import Foundation
import Synchronization
import Testing

@testable import SpookyKit

/// 本机新建与克隆：目标路径含空格、中文与引号，远端用本机的裸仓库。
struct RepositoryCloneTests {
    /// 不存在的多级目录一并创建；已是目录时在其中初始化；路径是文件或相对路径时不执行 Git。
    @Test("本机新建仓库：新目录、已有目录与无效路径", .timeLimit(.minutes(5)))
    func initialize() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let target = fixture.directory.path + "/新 建/仓'库\""
        let location = try await RepositoryCreation.initialize(.local(path: target + "/")) {
            fixture.runner(at: $0.path)
        }

        #expect(location == .local(path: target))
        #expect(FileManager.default.fileExists(atPath: target + "/.git/HEAD"))

        let existing = fixture.directory.appending(path: "existing")
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: false)
        try await RepositoryCreation.initialize(.local(path: existing.path)) { fixture.runner(at: $0.path) }
        #expect(FileManager.default.fileExists(atPath: existing.path + "/.git/HEAD"))

        let file = fixture.directory.appending(path: "file")
        try Data("x".utf8).write(to: file)
        await #expect(throws: HostOperationError.notDirectory(nil)) {
            try await RepositoryCreation.initialize(.local(path: file.path)) { fixture.runner(at: $0.path) }
        }

        await #expect(throws: HostOperationError.absolutePathRequired) {
            try await RepositoryCreation.initialize(.local(path: "relative")) { fixture.runner(at: $0.path) }
        }
    }

    /// 克隆成功后得到同一个提交；经 file:// 传输时报告进度，最后一条到 100%，事件流依次报告开始与完成。
    @Test("本机克隆：结果、进度与事件", .timeLimit(.minutes(5)))
    func clone() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let source = try await makeSource(in: fixture)
        let target = fixture.directory.path + "/克 隆'\""
        let progress = Mutex<[CloneProgress]>([])
        let clone = RepositoryClone(url: "file://" + source, destination: .local(path: target))

        let operation = clone.start(credentialHandler: nil, onProgress: { latest in
            progress.withLock { $0.append(latest) }
        }) { fixture.runner(at: $0.path) }

        var events: [String] = []

        for await event in operation.events {
            switch event {
            case .queued: events.append("queued")
            case .started: events.append("started")
            case .completed: events.append("completed")
            case .output, .failed, .cancelled: continue
            }
        }

        let result = try await operation.value
        #expect(result.arguments.prefix(3) == ["clone", "--progress", "--"])
        #expect(events == ["queued", "started", "completed"])
        #expect(progress.withLock { $0.last?.percent } == 100)

        let head = try await fixture.runner(at: target).run(["rev-parse", "HEAD"])
        let sourceHead = try await fixture.runner(at: source).run(["rev-parse", "HEAD"])
        #expect(head == sourceHead)
    }

    /// 克隆失败保留 Git 原文并删掉本次新建的目录；已有内容的目录原样保留。
    @Test("本机克隆：失败保留原文、清理新建的目录", .timeLimit(.minutes(5)))
    func failure() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let target = fixture.directory.path + "/target"
        let missing = RepositoryClone(url: fixture.directory.path + "/missing.git", destination: .local(path: target))
        let error = await #expect(throws: GitError.self) {
            try await missing.start(credentialHandler: nil, onProgress: nil) { fixture.runner(at: $0.path) }.value
        }

        #expect(error?.exitCode == 128)
        #expect(error?.message.contains("missing.git") ?? false)
        #expect(!FileManager.default.fileExists(atPath: target))

        // 目标里已有文件时 Git 拒绝克隆，已有内容不能被清理
        let source = try await makeSource(in: fixture)
        let occupied = fixture.directory.appending(path: "occupied")
        try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: false)
        try Data("keep".utf8).write(to: occupied.appending(path: "keep.txt"))

        let rejected = RepositoryClone(url: source, destination: .local(path: occupied.path))
        let occupiedError = await #expect(throws: GitError.self) {
            try await rejected.start(credentialHandler: nil, onProgress: nil) { fixture.runner(at: $0.path) }.value
        }

        #expect(occupiedError?.message.contains("already exists") ?? false)
        #expect(FileManager.default.fileExists(atPath: occupied.path + "/keep.txt"))
    }

    /// 取消不算失败：操作以取消结束，本机进程组被终止，新建的目录被删掉。
    @Test("本机克隆：取消", .timeLimit(.minutes(5)))
    func cancellation() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        // 假的 Git 先报告进度，再一直等待，直到被取消
        let executable = fixture.directory.appending(path: "git-test")
        try Data("#!/bin/sh\nprintf 'Receiving objects:  10%% (1/10)\\r' >&2\n/bin/sleep 30 &\nwait\n".utf8)
            .write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let target = fixture.directory.path + "/cancelled"
        let (progress, continuation) = AsyncStream<CloneProgress>.makeStream()
        let clone = RepositoryClone(url: "file:///unused", destination: .local(path: target))

        let operation = clone.start(credentialHandler: nil, onProgress: { continuation.yield($0) }) {
            fixture.runner(at: $0.path, executable: executable.path)
        }

        var iterator = progress.makeAsyncIterator()
        #expect(await iterator.next()?.percent == 10)

        operation.cancel()

        let error = await #expect(throws: GitError.self) { try await operation.value }
        #expect(error?.isCancelled ?? false)
        #expect(!FileManager.default.fileExists(atPath: target))
    }

    /// 选了 LFS 时先确认目标机器上的 Git LFS 可用；不可用时不执行克隆。
    @Test("本机克隆：LFS 不可用时在克隆前失败", .timeLimit(.minutes(5)))
    func lfsUnavailable() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        // 假的 Git 不认识 lfs 子命令，与没有安装 Git LFS 时一样以 1 退出
        let executable = fixture.directory.appending(path: "git-test")
        try Data("#!/bin/sh\necho \"git: 'lfs' is not a git command.\" >&2\nexit 1\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let target = fixture.directory.path + "/lfs"
        let clone = RepositoryClone(
            url: "file:///unused",
            destination: .local(path: target),
            options: CloneOptions(lfs: true)
        )
        let error = await #expect(throws: HostOperationError.self) {
            try await clone.start(credentialHandler: nil, onProgress: nil) {
                fixture.runner(at: $0.path, executable: executable.path)
            }.value
        }

        guard case .lfsUnavailable(let result) = error else {
            Issue.record("LFS 不可用应在克隆前报告")
            return
        }

        #expect(result.arguments == ["lfs", "version"])
        #expect(!FileManager.default.fileExists(atPath: target))
    }

    /// 地址放在 `--` 之后，以 “-” 开头的地址不会被当成选项；子模块选项在 `--` 之前。
    @Test("克隆参数：地址在 -- 之后")
    func arguments() {
        let clone = RepositoryClone(
            url: "--upload-pack=touch /tmp/x",
            destination: .remote(host: "b", path: "/srv/x"),
            options: CloneOptions(recurseSubmodules: true)
        )

        #expect(
            clone.arguments(path: "/srv/x") == [
                "clone", "--progress", "--recurse-submodules", "--", "--upload-pack=touch /tmp/x", "/srv/x",
            ]
        )
    }

    /// 目标目录的默认名与 Git 自己取的一致：去掉协议、结尾的斜杠与 .git，取最后一段。
    @Test("从地址取仓库名")
    func directoryNames() {
        #expect(RepositoryClone.directoryName(for: "git@github.com:rakuyoMo/Spooky.git") == "Spooky")
        #expect(RepositoryClone.directoryName(for: "https://example.com/team/app/") == "app")
        #expect(RepositoryClone.directoryName(for: "ssh://host/srv/仓库 名/.git") == "仓库 名")
        #expect(RepositoryClone.directoryName(for: "/Users/me/source 源") == "source 源")
        #expect(RepositoryClone.directoryName(for: "host:repo") == "repo")
        #expect(RepositoryClone.directoryName(for: "https://") == nil)
        #expect(RepositoryClone.directoryName(for: "..") == nil)
    }

    /// 在临时目录里建一个有两次提交的源仓库，返回它的路径。
    private func makeSource(in fixture: TemporaryRepository) async throws -> String {
        let source = fixture.directory.path + "/source 源"
        try FileManager.default.createDirectory(atPath: source, withIntermediateDirectories: false)

        let runner = fixture.runner(at: source)
        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])

        for index in 0 ..< 2 {
            try Data("content \(index)\n".utf8).write(to: URL(fileURLWithPath: source + "/file.txt"))
            _ = try await runner.run(["add", "file.txt"])
            _ = try await runner.run(["-c", "commit.gpgSign=false", "commit", "-q", "-m", "commit \(index)"])
        }

        return source
    }
}
