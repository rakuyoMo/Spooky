import Foundation
import Testing

@testable import SpookyKit

/// 扫描在选定目录下找仓库：不跟随符号链接、跳过隐藏与不能读取的目录，仓库内部不再报告。
struct RepositoryScanTests {
    /// 路径含空格、中文与引号；嵌套仓库、隐藏目录、不能读取的目录与指向外部的链接都不出现在结果里。
    @Test("本机扫描：结果、跳过规则与特殊路径", .timeLimit(.minutes(5)))
    func scan() async throws {
        let fixture = try TemporaryRepository()
        let outside = try TemporaryRepository()
        let root = fixture.directory.appending(path: "扫描 根'\"")
        let locked = root.appending(path: "locked")

        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: locked.path)
            fixture.remove()
            outside.remove()
        }

        let repositories = ["a", "b c/仓'库\"", "deep/er/repo"]
        let skipped = ["a/nested", ".hidden/repo", "locked/repo", "b c/仓'库\"/sub"]

        for path in repositories + skipped {
            try FileManager.default.createDirectory(
                at: root.appending(path: path + "/.git"),
                withIntermediateDirectories: true
            )
        }

        // 链接工作区的 .git 是文件；指向选定目录之外的链接不跟随
        try FileManager.default.createDirectory(at: root.appending(path: "worktree"), withIntermediateDirectories: true)
        try Data("gitdir: /elsewhere\n".utf8).write(to: root.appending(path: "worktree/.git"))
        try FileManager.default.createDirectory(
            at: outside.directory.appending(path: "external/.git"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "link"),
            withDestinationURL: outside.directory
        )
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)

        var found: [RepositoryLocation] = []

        for try await location in RepositoryScan.repositories(in: .local(path: root.path)) {
            found.append(location)
        }

        let expected = (repositories + ["worktree"]).map { RepositoryLocation.local(path: root.path + "/" + $0) }
        #expect(Set(found) == Set(expected))
        #expect(found.count == expected.count)
        #expect(found.allSatisfy { $0.host == nil })
    }

    /// 选定目录本身就是仓库时只报告它自己；根目录不存在或不能读取时以错误结束。
    @Test("本机扫描：根目录是仓库、不存在与不能读取", .timeLimit(.minutes(5)))
    func rootCases() async throws {
        let fixture = try TemporaryRepository()
        let locked = fixture.directory.appending(path: "locked")

        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: locked.path)
            fixture.remove()
        }

        try FileManager.default.createDirectory(
            at: fixture.directory.appending(path: "repo/.git"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: fixture.directory.appending(path: "repo/inner/.git"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)

        var found: [RepositoryLocation] = []
        let repository = fixture.directory.appending(path: "repo").path

        for try await location in RepositoryScan.repositories(in: .local(path: repository)) {
            found.append(location)
        }

        #expect(found == [.local(path: repository)])

        await #expect(throws: HostOperationError.self) {
            for try await _ in RepositoryScan.repositories(in: .local(path: fixture.directory.path + "/missing")) { }
        }

        let denied = await #expect(throws: HostOperationError.self) {
            for try await _ in RepositoryScan.repositories(in: .local(path: locked.path)) { }
        }
        guard case .permissionDenied = denied else {
            Issue.record("不能读取的根目录应报告为没有权限")
            return
        }
    }

    /// 取得第一个结果后停止迭代即取消扫描，之后同一主机的命令照常执行。
    @Test("本机扫描：提前结束迭代即取消", .timeLimit(.minutes(5)))
    func cancellation() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        for index in 0 ..< 50 {
            try FileManager.default.createDirectory(
                at: fixture.directory.appending(path: "r\(index)/.git"),
                withIntermediateDirectories: true
            )
        }

        var first: RepositoryLocation? = nil

        for try await location in RepositoryScan.repositories(in: .local(path: fixture.directory.path)) {
            first = location
            break
        }

        #expect(first != nil)
        #expect(try await HostDirectories.status(of: .local(path: fixture.directory.path)).isDirectory)
    }

    /// 输出块在路径中间切开时拼回完整路径；嵌套在已找到的仓库里的结果丢弃。
    @Test("扫描结果：跨块路径与嵌套过滤")
    func collector() {
        let collector = RepositoryScan.Collector(host: "b")
        let output = Data("/s/a/.git\u{0}/s/a/n/.git\u{0}/s/ab/.git\u{0}".utf8)

        let first = collector.receive(output.prefix(5))
        let rest = collector.receive(output.dropFirst(5))

        #expect(first.isEmpty)
        #expect(rest == [.remote(host: "b", path: "/s/a"), .remote(host: "b", path: "/s/ab")])
    }
}
