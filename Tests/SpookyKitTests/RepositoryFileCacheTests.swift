import Foundation
import Testing

@testable import SpookyKit

/// 交给本机程序的副本只落在私有缓存目录，清理后不留下文件。
struct RepositoryFileCacheTests {
    /// 副本保留原文件名、同名互不覆盖，缓存目录只对当前用户开放；清理后仍可继续使用。
    @Test("缓存副本的文件名、权限与清理")
    func storeAndRemove() throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        let cache = RepositoryFileCache(runner: repository.runner)
        let first = try cache.store(Data("one".utf8), named: "目录/图 片 [*].png")
        let second = try cache.store(Data("two".utf8), named: "图 片 [*].png")

        #expect(first.lastPathComponent == "图 片 [*].png")
        #expect(first != second)
        #expect(try Data(contentsOf: first) == Data("one".utf8))
        #expect(try Data(contentsOf: second) == Data("two".utf8))

        // 根目录与每个副本目录都只允许当前用户访问
        let root = first.deletingLastPathComponent().deletingLastPathComponent()

        for directory in [root, first.deletingLastPathComponent()] {
            let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
            #expect(attributes[.posixPermissions] as? Int == 0o700)
        }

        cache.removeAll()
        #expect(!FileManager.default.fileExists(atPath: root.path))

        // 清理后按需重建目录；不能作为文件名的路径段换成固定名称
        let again = try cache.store(Data("three".utf8), named: "..")
        #expect(again.lastPathComponent == "file")
        #expect(try Data(contentsOf: again) == Data("three".utf8))
        cache.removeAll()
    }

    /// 本机仓库的工作区文件不复制，直接交出原路径；下载接口仍能把文件复制到指定位置。
    @Test("本机工作区文件使用原路径")
    func localWorkingTree() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let path = "子 目录/文件 [*].txt"
        let file = repository.directory.appending(path: path)

        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("content".utf8).write(to: file)

        let cache = RepositoryFileCache(runner: repository.runner)
        #expect(try await cache.workingTreeFile(path).standardizedFileURL == file.standardizedFileURL)

        let copy = repository.directory.appending(path: "copy.txt")
        try await RepositoryFiles(runner: repository.runner).download(file.path, to: copy)
        #expect(try Data(contentsOf: copy) == Data("content".utf8))
    }
}
