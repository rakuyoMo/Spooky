import Foundation
import Testing

@testable import SpookyKit

/// 提交区据以判断签名、注释与钩子的配置，必须与 Git 实际采用的值一致。
struct CommitConfigurationTests {
    /// 同一键以最后一个为准，无值布尔键为真，值里的空格与中文原样保留；未配置时使用 Git 的默认值，
    /// auto 注释字符不会把用户输入当成注释；仓库设置的正文折行只认正整数与 Git 的布尔写法；
    /// 截断或错位的输出不能被当成 “未配置签名”；档案里的签名密钥按写法决定签名格式。
    @Test("解析生效的提交配置")
    func parsing() throws {
        let output = Data(
            (
                "user.name\n旧名字\0user.name\n新 名字 ' \"\0user.email\nme@example.invalid\0"
                    + "user.signingkey\n~/.ssh/签名 key.pub\0gpg.format\nssh\0commit.gpgsign\0"
                    + "core.commentchar\n;\0"
            ).utf8
        )
        let configuration = try CommitConfiguration.parse(output, hasCommitHooks: true)

        #expect(configuration.userName == "新 名字 ' \"")
        #expect(configuration.userEmail == "me@example.invalid")
        #expect(configuration.signingKey == "~/.ssh/签名 key.pub")
        #expect(configuration.signingFormat == .ssh)
        #expect(configuration.signsCommits)
        #expect(configuration.commentPrefix == ";")
        #expect(configuration.hasCommitHooks)

        // 缺省值
        let empty = try CommitConfiguration.parse(Data(), hasCommitHooks: false)
        #expect(empty.userName == nil)
        #expect(empty.signingFormat == .openpgp)
        #expect(!empty.signsCommits)
        #expect(empty.commentPrefix == "#")

        // auto 注释字符没有固定前缀；两个别名中后读到的生效
        let auto = try CommitConfiguration.parse(
            Data("commit.gpgsign\noff\0core.commentstring\n//\0core.commentchar\nauto\0".utf8),
            hasCommitHooks: false
        )
        #expect(!auto.signsCommits)
        #expect(auto.commentPrefix == nil)

        let string = try CommitConfiguration.parse(
            Data("core.commentchar\n;\0core.commentstring\n//\0".utf8),
            hasCommitHooks: false
        )
        #expect(string.commentPrefix == "//")

        // 仓库设置的正文折行覆盖 Editor 设置页的值
        let configured = try CommitConfiguration.parse(
            Data("spooky.commitbodylimit\n80\0spooky.commitshowsguide\nno\0".utf8),
            hasCommitHooks: false
        )
        #expect(configured.bodyLineLimit == 80)
        #expect(configured.showsBodyGuide == Optional(false))

        let invalid = try CommitConfiguration.parse(
            Data("spooky.commitbodylimit\n0\0".utf8),
            hasCommitHooks: false
        )
        #expect(invalid.bodyLineLimit == nil)
        #expect(invalid.showsBodyGuide == nil)

        // 截断的值与不在查询范围内的键
        for malformed in ["user.name\nTruncated", "remote.origin.url\nx\0"] {
            #expect(throws: RepositoryReadError.malformedOutput("commit config")) {
                try CommitConfiguration.parse(Data(malformed.utf8), hasCommitHooks: false)
            }
        }

        // 按密钥写法推断签名格式
        #expect(SigningFormat(key: "ABCDEF0123456789") == .openpgp)
        #expect(SigningFormat(key: "me@example.invalid") == .openpgp)
        #expect(SigningFormat(key: "~/.ssh/id_ed25519.pub") == .ssh)
        #expect(SigningFormat(key: "/Users/me/keys/签名") == .ssh)
        #expect(SigningFormat(key: "key::ssh-ed25519 AAAA") == .ssh)
        #expect(SigningFormat(key: "ssh-ed25519 AAAA me") == .ssh)
    }

    /// 真实仓库里的签名配置与钩子：钩子经 core.hooksPath 定位，不可执行的钩子 Git 会忽略；
    /// 选用档案只改写本仓库的配置，以短横线开头的值不会被当作选项，没有密钥时不动签名配置。
    @Test("读取仓库的签名配置与提交钩子，选用身份档案")
    func repositoryConfiguration() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)
        let config = { (key: String) in
            String(decoding: try await repository.runner.run(["config", "--local", "--get", key]), as: UTF8.self)
                .trimmingCharacters(in: .newlines)
        }

        _ = try await repository.runner.run(["config", "--local", "commit.gpgsign", "yes"])
        _ = try await repository.runner.run(["config", "--local", "user.signingkey", "0123ABCD"])
        #expect(try await service.commitConfiguration().signsCommits)
        #expect(try await service.commitConfiguration().signingKey == "0123ABCD")
        #expect(try await !service.commitConfiguration().hasCommitHooks)

        // 相对 core.hooksPath 以工作区根为基准；只有可执行的钩子才算启用
        let hooks = repository.directory.appending(path: "钩子 [*]")
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)
        _ = try await repository.runner.run(["config", "--local", "core.hooksPath", "钩子 [*]"])

        let hook = hooks.appending(path: "commit-msg")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: hook)
        #expect(try await !service.commitConfiguration().hasCommitHooks)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)
        #expect(try await service.commitConfiguration().hasCommitHooks)

        // 选用带密钥的档案，签名格式按密钥写法取 SSH
        try await service.applyIdentity(
            name: "-渡边 ' \"",
            email: "-me@example.invalid",
            signingKey: "~/.ssh/key.pub"
        )
        #expect(try await config("user.name") == "-渡边 ' \"")
        #expect(try await config("user.email") == "-me@example.invalid")
        #expect(try await config("user.signingkey") == "~/.ssh/key.pub")
        #expect(try await config("gpg.format") == "ssh")

        // 再选用没有密钥的档案，签名配置保持
        try await service.applyIdentity(name: "Second", email: "second@example.invalid", signingKey: nil)
        #expect(try await config("user.name") == "Second")
        #expect(try await config("user.signingkey") == "~/.ssh/key.pub")

        let configuration = try await service.commitConfiguration()
        #expect(configuration.userName == "Second")
        #expect(configuration.signingFormat == .ssh)
    }
}
