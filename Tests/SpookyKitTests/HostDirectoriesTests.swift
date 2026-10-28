import Foundation
import Testing

@testable import SpookyKit

/// 目录浏览与路径检查：本机与服务器执行同一份脚本，这里在本机验证脚本与解析。
struct HostDirectoriesTests {
    /// 只列子目录，按名称排序；不能打开的目录与已是工作区的目录分别标出，符号链接按目标判断。
    @Test("列目录：只列目录、排序与可读、工作区标记")
    func listing() async throws {
        let fixture = try TemporaryRepository()
        let root = fixture.directory
        let locked = root.appending(path: "locked")

        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: locked.path)
            fixture.remove()
        }

        for name in ["b", "A", "仓 库'\"", ".hidden", "repo/.git", "worktree", "locked"] {
            try FileManager.default.createDirectory(at: root.appending(path: name), withIntermediateDirectories: true)
        }

        // 链接工作区与子模块的 .git 是文件，同样算作工作区
        try Data("gitdir: /elsewhere\n".utf8).write(to: root.appending(path: "worktree/.git"))
        try Data("file".utf8).write(to: root.appending(path: "f.txt"))
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "link"),
            withDestinationURL: root.appending(path: "b")
        )
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)

        let entries = try await HostDirectories.list(.local(path: root.path + "/"))
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })

        #expect(entries.map(\.name) == [".hidden", "A", "b", "link", "locked", "repo", "worktree", "仓 库'\""])
        #expect(byName["仓 库'\""]?.path == root.path + "/仓 库'\"")
        #expect(byName["repo"]?.isRepository ?? false)
        #expect(byName["worktree"]?.isRepository ?? false)
        #expect(!(byName["b"]?.isRepository ?? true))
        #expect(!(byName["locked"]?.isReadable ?? true))
        #expect(byName["link"]?.isReadable ?? false)
        #expect(byName["A"]?.isReadable ?? false)
    }

    /// 根目录不存在、不是目录或不能读取时分别报告，原始输出保留在结果里。
    @Test("列目录：不存在、不是目录与不能读取")
    func listingFailures() async throws {
        let fixture = try TemporaryRepository()
        let locked = fixture.directory.appending(path: "locked")

        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: locked.path)
            fixture.remove()
        }

        try Data("file".utf8).write(to: fixture.directory.appending(path: "f.txt"))
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)

        let missing = await #expect(throws: HostOperationError.self) {
            try await HostDirectories.list(.local(path: fixture.directory.path + "/missing"))
        }
        guard case .missingDirectory(let result) = missing else {
            Issue.record("不存在的目录应报告为不存在")
            return
        }
        #expect(result?.exitCode == 2)

        let file = await #expect(throws: HostOperationError.self) {
            try await HostDirectories.list(.local(path: fixture.directory.path + "/f.txt"))
        }
        #expect(isNotDirectory(file))

        let denied = await #expect(throws: HostOperationError.self) {
            try await HostDirectories.list(.local(path: locked.path))
        }
        guard case .permissionDenied(let deniedResult) = denied else {
            Issue.record("不能读取的目录应报告为没有权限")
            return
        }
        let deniedOutput = String(decoding: deniedResult?.standardError ?? Data(), as: UTF8.self)
        #expect(deniedOutput.contains("Permission denied"))

        await #expect(throws: HostOperationError.absolutePathRequired) {
            try await HostDirectories.list(.local(path: "relative/path"))
        }
    }

    /// 路径检查覆盖不存在、空目录、工作区与文件，不存在不算错误。
    @Test("路径检查：存在性、空目录、可写与工作区")
    func status() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let root = fixture.directory
        try FileManager.default.createDirectory(at: root.appending(path: "empty"), withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: root.appending(path: "repo/.git"), withIntermediateDirectories: true)
        try Data("file".utf8).write(to: root.appending(path: "f.txt"))

        let missing = try await HostDirectories.status(of: .local(path: root.path + "/missing"))
        #expect(!missing.exists && !missing.isDirectory && !missing.isReadable && !missing.isWritable)

        let empty = try await HostDirectories.status(of: .local(path: root.path + "/empty"))
        #expect(empty.exists && empty.isDirectory && empty.isReadable && empty.isWritable && empty.isEmpty)
        #expect(!empty.isRepository)

        let repository = try await HostDirectories.status(of: .local(path: root.path + "/repo"))
        #expect(repository.isRepository && !repository.isEmpty)

        let file = try await HostDirectories.status(of: .local(path: root.path + "/f.txt"))
        #expect(file.exists && !file.isDirectory && file.isReadable && !file.isEmpty)
    }

    /// 根目录下的路径不重复 “/”；格式不符的检查输出不被接受。
    @Test("列目录与路径检查：输出解析")
    func parsing() {
        let entries = HostDirectories.parseList(Data("10usr\u{0}01b\u{0}x\u{0}".utf8), in: "/")
        #expect(entries.map(\.path) == ["/b", "/usr"])
        #expect(entries.first { $0.name == "b" }?.isRepository ?? false)

        #expect(HostDirectories.parseStatus(Data("110110\n".utf8))?.isWritable ?? false)
        #expect(HostDirectories.parseStatus(Data("11011\n".utf8)) == nil)
        #expect(HostDirectories.parseStatus(Data("110112\n".utf8)) == nil)
    }

    /// 环境探测的输出：GIT_ 变量只留 Spooky 没有设置的，找不到 Git 或废纸篓程序时为 nil。
    @Test("B 端环境：主目录、PATH、Git、废纸篓与变量名")
    func environment() {
        let output = "/Users/b\u{0}/usr/bin:/opt/homebrew/bin\u{0}/opt/homebrew/bin/git\n\u{0}trash:/usr/bin/trash\u{0}"
            + "GIT_CONFIG_GLOBAL\u{0}GIT_TERMINAL_PROMPT\u{0}GIT_TRACE\u{0}"
        let environment = RemoteHostEnvironment(output: Data(output.utf8), excluding: ["GIT_TERMINAL_PROMPT"])

        #expect(environment?.homeDirectory == "/Users/b")
        #expect(environment?.searchPath == ["/usr/bin", "/opt/homebrew/bin"])
        #expect(environment?.gitPath == "/opt/homebrew/bin/git")
        #expect(environment?.trash == .macOS)
        #expect(environment?.gitVariables == ["GIT_CONFIG_GLOBAL", "GIT_TRACE"])

        let missing = RemoteHostEnvironment(output: Data("/Users/b\u{0}/usr/bin\u{0}\u{0}\u{0}".utf8), excluding: [])
        #expect(missing?.gitPath == nil)
        #expect(missing?.trash == nil)
        #expect(missing?.gitVariables.isEmpty ?? false)

        #expect(RemoteHostEnvironment(output: Data("relative\u{0}/usr/bin\u{0}\u{0}\u{0}".utf8), excluding: []) == nil)
        #expect(RemoteHostEnvironment(output: Data("/Users/b\u{0}/usr/bin\u{0}\u{0}".utf8), excluding: []) == nil)
    }

    /// 是否为 “不是目录” 的错误。
    private func isNotDirectory(_ error: HostOperationError?) -> Bool {
        guard case .notDirectory = error else { return false }
        return true
    }
}
