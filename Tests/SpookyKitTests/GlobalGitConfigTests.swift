import Foundation
import Testing

@testable import SpookyKit

// MARK: - GlobalGitConfigTests

/// Settings → Git Config 与 Integration 读写本机全局配置；读写必须落在 Git 实际使用的文件上，失败时保留 Git 的原文。
struct GlobalGitConfigTests {
    /// 同一键以最后一个为准，无值布尔键为真，未知格式名不当作任何格式。
    @Test("解析全局配置")
    func parsesValues() throws {
        let records = [
            "user.name\n旧名字",
            "user.name\n新 名字",
            "user.email\nme@example.invalid",
            "user.signingkey\nkey::ssh-ed25519 AAAA",
            "gpg.format\nssh",
            "commit.gpgsign",
            "gpg.program\n/opt/homebrew/bin/gpg",
            "gpg.ssh.program\n/Applications/签 名",
            "gpg.ssh.allowedsignersfile\n~/.ssh/allowed_signers",
            "spooky.issuetrackertemplate\nhttps://example.invalid/{ISSUE_NUMBER}",
            "spooky.issuenumberprefix\n#",
        ]
        let output = Data(records.map { $0 + "\0" }.joined().utf8)
        let configuration = try GlobalGitConfiguration.parse(output)

        #expect(configuration.userName == "新 名字")
        #expect(configuration.userEmail == "me@example.invalid")
        #expect(configuration.signingKey == "key::ssh-ed25519 AAAA")
        #expect(configuration.signingFormat == SigningFormat.ssh)
        #expect(configuration.signsCommits)
        #expect(configuration.gpgProgram == "/opt/homebrew/bin/gpg")
        #expect(configuration.sshProgram == "/Applications/签 名")
        #expect(configuration.allowedSignersFile == "~/.ssh/allowed_signers")
        #expect(configuration.issueTrackerTemplate == "https://example.invalid/{ISSUE_NUMBER}")
        #expect(configuration.issueNumberPrefix == "#")

        let unknown = try GlobalGitConfiguration.parse(Data("gpg.format\nsomething\0commit.gpgsign\nfalse\0".utf8))
        #expect(unknown.signingFormat == nil)
        #expect(!unknown.signsCommits)
        #expect(try GlobalGitConfiguration.parse(Data()) == GlobalGitConfiguration())
    }

    /// 截断或混进其它键的输出说明解析已错位，不能当作 “未配置”。
    @Test("格式错误的全局配置输出被拒绝")
    func rejectsMalformedOutput() {
        #expect(throws: RepositoryReadError.malformedOutput("global config")) {
            try GlobalGitConfiguration.parse(Data("user.name\nTruncated".utf8))
        }

        #expect(throws: RepositoryReadError.malformedOutput("global config")) {
            try GlobalGitConfiguration.parse(Data("core.editor\nvim\0".utf8))
        }
    }

    /// 页面上写明的文件位置要与 Git 写入 `--global` 时选的文件一致。
    @Test("全局配置文件的位置")
    func locatesFile() {
        let home = ["HOME": "/Users/test"]

        #expect(GlobalGitConfig.filePath(environment: home, fileExists: { _ in false }) == "/Users/test/.gitconfig")

        // 只有 XDG 的文件存在时写进它；两者都在时仍是 ~/.gitconfig
        let xdg = "/Users/test/.config/git/config"
        #expect(GlobalGitConfig.filePath(environment: home, fileExists: { $0 == xdg }) == xdg)
        #expect(GlobalGitConfig.filePath(environment: home, fileExists: { _ in true }) == "/Users/test/.gitconfig")

        let custom = home.merging(["XDG_CONFIG_HOME": "/tmp/配置"]) { $1 }
        #expect(GlobalGitConfig.filePath(environment: custom, fileExists: { $0 == "/tmp/配置/git/config" }) == "/tmp/配置/git/config")

        let overridden = home.merging(["GIT_CONFIG_GLOBAL": "/tmp/指定 文件"]) { $1 }
        #expect(GlobalGitConfig.filePath(environment: overridden, fileExists: { _ in false }) == "/tmp/指定 文件")
    }

    /// 读全局配置不必排在写操作后面，写入仍走写队列。
    @Test("读全局配置登记为只读命令")
    func registersReadAsReadOnly() {
        let read = ["config", "--global", "--includes", "-z", "--get-regexp", GlobalGitConfiguration.pattern]
        #expect(RepositoryOperationQueue.isReadOnly(read))
        #expect(!RepositoryOperationQueue.isReadOnly(["config", "--global", "--replace-all", "--", "user.name", "x"]))
        #expect(!RepositoryOperationQueue.isReadOnly(["config", "--global", "--unset-all", "--", "user.name"]))
    }

    /// 写入、读回、删除都落在临时 HOME 的 ~/.gitconfig；不存在的文件与键都按未配置处理。
    @Test("在隔离的 HOME 里读写全局配置")
    func readsAndWritesGlobalConfig() async throws {
        let home = try IsolatedHome()
        defer { home.remove() }

        let config = GlobalGitConfig(runner: home.runner)
        #expect(try await config.read() == GlobalGitConfiguration())

        try await config.set([
            (GlobalGitConfiguration.Key.userName, "-名字 带空格"),
            (GlobalGitConfiguration.Key.userEmail, "me@example.invalid"),
            (GlobalGitConfiguration.Key.signingKey, "key::ssh-ed25519 AAAA test"),
            (GlobalGitConfiguration.Key.signingFormat, "ssh"),
            (GlobalGitConfiguration.Key.signsCommits, "true"),
            (GlobalGitConfiguration.Key.issueTrackerTemplate, "https://example.invalid/issues/{ISSUE_NUMBER}"),
        ])

        var read = try await config.read()
        #expect(read.userName == "-名字 带空格")
        #expect(read.userEmail == "me@example.invalid")
        #expect(read.signingKey == "key::ssh-ed25519 AAAA test")
        #expect(read.signingFormat == SigningFormat.ssh)
        #expect(read.signsCommits)
        #expect(read.issueTrackerTemplate == "https://example.invalid/issues/{ISSUE_NUMBER}")
        #expect(FileManager.default.fileExists(atPath: home.directory.appending(path: ".gitconfig").path))

        // 删除已有的键与本来就没有的键
        try await config.set([
            (GlobalGitConfiguration.Key.signingKey, nil),
            (GlobalGitConfiguration.Key.gpgProgram, nil),
        ])

        read = try await config.read()
        #expect(read.signingKey == nil)
        #expect(read.userName == "-名字 带空格")
    }

    /// `[include]` 引入的文件里的值也是 Git 实际生效的值。
    @Test("读取跟随 include")
    func followsIncludes() async throws {
        let home = try IsolatedHome()
        defer { home.remove() }

        let included = home.directory.appending(path: "身份.inc")
        try "[user]\n\temail = included@example.invalid\n".write(to: included, atomically: true, encoding: .utf8)
        try "[include]\n\tpath = \(included.path)\n"
            .write(to: home.directory.appending(path: ".gitconfig"), atomically: true, encoding: .utf8)

        let read = try await GlobalGitConfig(runner: home.runner).read()
        #expect(read.userEmail == "included@example.invalid")
    }

    /// 配置文件写不进、内容无效时抛出带 Git 原文的错误，退出码与 Git 一致。
    @Test("写不进与无效的全局配置")
    func reportsFailures() async throws {
        let home = try IsolatedHome()
        defer { home.remove() }

        let config = GlobalGitConfig(runner: home.runner)

        // 目录不可写时 Git 拿不到锁文件
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: home.directory.path)
        let locked = await #expect(throws: GitError.self) {
            try await config.set([(GlobalGitConfiguration.Key.userName, "x")])
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: home.directory.path)
        let lockMessage = String(decoding: locked?.result.standardError ?? Data(), as: UTF8.self)
        #expect(locked?.exitCode == 255)
        #expect(lockMessage.contains("could not lock config file"))

        try "[user\n name = x\n".write(to: home.directory.appending(path: ".gitconfig"), atomically: true, encoding: .utf8)
        let invalid = await #expect(throws: GitError.self) {
            try await config.read()
        }
        let invalidMessage = String(decoding: invalid?.result.standardError ?? Data(), as: UTF8.self)
        #expect(invalid?.exitCode == 128)
        #expect(invalidMessage.contains("bad config line 1"))
    }
}

// MARK: - IsolatedHome

/// 每个测试独占的临时 HOME：`--global` 读写其中的 `.gitconfig`，不碰用户真实的配置。
struct IsolatedHome {
    /// 临时 HOME 目录。
    let directory: URL

    /// 以临时目录为 HOME、忽略系统配置的执行器。
    var runner: GitRunner {
        GitRunner(
            location: .local(path: directory.path),
            environment: .inherit.updating([
                "HOME": directory.path,
                "GIT_CONFIG_GLOBAL": nil,
                "XDG_CONFIG_HOME": nil,
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_PARAMETERS": nil,
                "GIT_CONFIG_COUNT": nil,
            ])
        )
    }

    /// 新建临时目录，路径里带空格与中文。
    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "Spooky-HOME-\(UUID().uuidString) 主目录")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// 删除临时目录。
    func remove() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try? FileManager.default.removeItem(at: directory)
    }
}
