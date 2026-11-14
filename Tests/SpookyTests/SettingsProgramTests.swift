import AppKit
import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - SettingsProgramTests

/// 设置页里交给外部程序的两处选择：GPG 程序要满足最低版本，github.com 链接的候选同一 App 只列一份。
@MainActor
struct SettingsProgramTests {
    /// 选中或配置的 GPG 程序：不是 GnuPG 时提示无效，低于 2.1.0 时说明版本，正好 2.1.0 时没有问题。
    @Test("GPG 程序的最低版本")
    func gpgMinimumVersion() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let older = try Self.script("older", printing: "gpg (GnuPG) 2.0.30", in: directory)
        let minimum = try Self.script("minimum", printing: "gpg (GnuPG) 2.1.0", in: directory)
        let other = try Self.script("other", printing: "sq (Sequoia) 1.0.0", in: directory)

        guard case .outdatedGPG(let path, let version) = await GitSigningRows.gpgNotice(for: older) else {
            Issue.record("低于最低版本的 GnuPG 应当说明版本")
            return
        }

        #expect(path == older)
        #expect(version.description == "2.0.30")

        #expect(await GitSigningRows.gpgNotice(for: minimum) == nil)
        #expect(await GitSigningRows.gpgNotice(for: other) == .invalidGPG(other))
        #expect(await GitSigningRows.gpgNotice(for: nil) == nil)
    }

    /// 同一 Bundle ID 的几份拷贝只列系统选定的那一份；标题是 “名称 (版本)”，缺版本写名称，缺名称写 Bundle ID。
    @Test("github.com 链接的候选")
    func githubLinkCandidates() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let client = "com.example.client"
        let copy = try Self.application("Copy", identifier: client, name: "Client", version: "1.0", in: directory)
        let chosen = try Self.application("Chosen", identifier: client, name: "Client", version: "2.0", in: directory)
        let unversioned = try Self.application("Unversioned", identifier: "com.example.bare", name: "Bare", in: directory)
        let unnamed = try Self.application("Unnamed", identifier: "com.example.anonymous", in: directory)

        let candidates = GitHubLinksSettingsRow.candidates([copy, unnamed, chosen, unversioned]) {
            $0 == client ? chosen : nil
        }

        #expect(candidates.map(\.lastPathComponent) == ["Unversioned.app", "Chosen.app", "Unnamed.app"])
        #expect(candidates.map(GitHubLinksSettingsRow.title(of:)) == [
            "Bare",
            "Client (2.0)",
            "com.example.anonymous",
        ])
    }
}

// MARK: - Helpers

extension SettingsProgramTests {
    /// 新建一个测试结束后删除的临时目录。
    private static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-settings-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    /// 一个只输出一行版本的可执行脚本，返回它的路径。
    private static func script(_ name: String, printing line: String, in directory: URL) throws -> String {
        let file = directory.appending(path: name)
        try Data("#!/bin/sh\necho '\(line)'\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        return file.path
    }

    /// 一个只有 `Info.plist` 的 App 包；名称与版本为 nil 时不写这个键。
    private static func application(
        _ file: String,
        identifier: String,
        name: String? = nil,
        version: String? = nil,
        in directory: URL
    ) throws -> URL {
        let bundle = directory.appending(path: file + ".app")
        let contents = bundle.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        var info: [String: String] = ["CFBundleIdentifier": identifier, "CFBundlePackageType": "APPL"]
        info["CFBundleName"] = name
        info["CFBundleShortVersionString"] = version

        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appending(path: "Info.plist"))
        return bundle
    }
}
