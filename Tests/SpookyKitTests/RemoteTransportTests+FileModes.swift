import Foundation
import Testing

@testable import SpookyKit

/// 包装器的文件模式在本机直接运行：读取的记录与内联预算，删除、移动与建目录的结果和失败。
extension RemoteTransportTests {
    /// 读取模式按顺序写出记录：不存在与上级不是目录都记作不存在，内联按累计的预算判断，超出预算的不带内容、也不占预算，
    /// 早于 1970 年的修改时间记作 1970 年；没有权限或是目录时写出 “路径: 原因” 并失败退出；
    /// 输出是更大一段数据的切片时照样切得开，记录不完整或类别不明时切不开。
    @Test("包装器读取的记录、累计预算与失败")
    func wrapperRead() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-read-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let modified = Date(timeIntervalSince1970: 1_700_000_000)
        let small = directory.appending(path: "文件 ' [*]\n.txt")
        let large = directory.appending(path: "large")
        let old = directory.appending(path: "old")

        try Data("hello".utf8).write(to: small)
        try Data("world!".utf8).write(to: large)
        try Data().write(to: old)

        for file in [small, large] {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: file.path)
        }

        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: -86_400)],
            ofItemAtPath: old.path
        )

        // 预算 10：5 字节的内联；6 字节的超出剩下的 5，不带内容；再读 5 字节的正好用完剩下的预算，空文件不占预算
        let output = try await standaloneWrapper([
            "read", "10", small.path, directory.path + "/missing", small.path + "/child", large.path, small.path,
            old.path,
        ])
        let records = try #require(RemoteConnection.records(in: output.standardOutput, count: 6))

        #expect(output.exitCode == 0)
        #expect(records == [
            .content(Data("hello".utf8), modified: modified),
            .missing,
            .missing,
            .oversized(modified: modified),
            .content(Data("hello".utf8), modified: modified),
            .content(Data(), modified: Date(timeIntervalSince1970: 0)),
        ])

        // 输出是切片、下标不从 0 开始时切出同样的记录
        let slice = (Data([9]) + output.standardOutput).dropFirst()

        #expect(RemoteConnection.records(in: slice, count: 6) == records)

        // 记录被截断、多出字节或类别不明时切不开
        #expect(RemoteConnection.records(in: output.standardOutput.dropLast(), count: 6) == nil)
        #expect(RemoteConnection.records(in: output.standardOutput + Data([0]), count: 6) == nil)
        #expect(RemoteConnection.records(in: Data([7]), count: 1) == nil)

        // 没有权限与目录：写出路径与原因，失败退出
        let locked = directory.appending(path: "locked")
        try Data("x".utf8).write(to: locked)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)

        let denied = try await standaloneWrapper(["read", "10", locked.path])
        let folder = try await standaloneWrapper(["read", "10", directory.path])

        #expect(denied.exitCode == 1)
        #expect(String(decoding: denied.standardError, as: UTF8.self) == locked.path + ": Permission denied\n")
        #expect(folder.exitCode == 1)
        #expect(String(decoding: folder.standardError, as: UTF8.self) == directory.path + ": Is a directory\n")
    }

    /// 删除遇到第一个失败就停下、不删目录；移动的目标已存在时以专用的退出码结束，悬空的符号链接也算已存在；
    /// 建目录逐级建出，已存在的上级不算失败，新目录按启动时的 umask 取权限，某一级是文件时失败。
    @Test("包装器删除、移动与建目录")
    func wrapperFileWrites() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-files-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appending(path: "first")
        let second = directory.appending(path: "second")
        let folder = directory.appending(path: "folder")
        let link = directory.appending(path: "link")
        let moved = directory.appending(path: "moved")

        try Data("1".utf8).write(to: first)
        try Data("2".utf8).write(to: second)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "nowhere")

        // 删除：删掉第一个，停在目录上，后面的留着
        let removal = try await standaloneWrapper(["delete", first.path, folder.path, second.path])

        #expect(removal.exitCode == 1)
        #expect(String(decoding: removal.standardError, as: UTF8.self) == folder.path + ": Is a directory\n")
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
        #expect(FileManager.default.fileExists(atPath: folder.path))

        // 移动：目标已存在或是悬空的符号链接时不覆盖，原文件不动；目标空着时移过去
        let occupied = try await standaloneWrapper(["move", second.path, folder.path])
        let dangling = try await standaloneWrapper(["move", second.path, link.path])
        let free = try await standaloneWrapper(["move", second.path, moved.path])

        #expect(occupied.exitCode == RemoteConnection.destinationExistsCode)
        #expect(dangling.exitCode == RemoteConnection.destinationExistsCode)
        #expect(free.exitCode == 0)
        #expect(try Data(contentsOf: moved) == Data("2".utf8))

        // 建目录：按启动时的 umask 逐级建出，包装器自己的 0077 不影响新目录
        let nested = folder.appending(path: "a/b")
        let created = try await CommandExecutor.execute(
            executable: "/bin/sh",
            processArguments: ["-c", #"umask 002 && exec /usr/bin/perl "$0" mkdir "$1""#, Self.wrapper.path, nested.path]
        )

        #expect(created.exitCode == 0)

        for level in [folder.appending(path: "a"), nested] {
            #expect(try FileManager.default.attributesOfItem(atPath: level.path)[.posixPermissions] as? Int == 0o775)
        }

        // 某一级是文件时失败
        let blocked = try await standaloneWrapper(["mkdir", moved.path + "/child"])

        #expect(blocked.exitCode == 1)
        #expect(String(decoding: blocked.standardError, as: UTF8.self) == moved.path + ": File exists\n")
    }
}
