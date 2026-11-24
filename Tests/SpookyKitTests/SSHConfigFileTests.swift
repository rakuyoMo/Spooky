import Foundation
import Testing

@testable import SpookyKit

// MARK: - SSHConfigFileTests

/// SSH 配置文件里主机别名的列出与增删改：改动只落在涉及的行上，别的主机、注释与选项逐字保留；
/// 写错一行会让 SSH 拒绝整份配置，所以写出的内容还要由 OpenSSH 读回核对。
struct SSHConfigFileTests {
    /// 只有一个名称、名称不是模式的 `Host` 段才列出；`Host *`、几个名称共用的段与带通配符的段不列。
    /// 值按 SSH 的规则读：等号分隔、引号与转义、行尾注释、带引号的关键字、大小写不同的关键字与行尾的回车都认得；
    /// 同一个选项出现几次时取第一行，`Match` 行结束上一段，没有参数的选项当作没有。
    @Test("列出能管理的别名")
    func listsAliases() {
        let file = SSHConfigFile(text: """
            # 全局默认
            Host *
                AddKeysToAgent yes
                User fallback

            # 工作
            Host work   # 行尾注释
            \tHostName = 10.0.0.8   # 机房
            \tuser "al ex"
            \tPort=2222
            \tIdentityFile "~/Library/Application Support/k\\"e\\\\y"
            \tIdentityFile ~/.ssh/second
            \tHostName ignored.example.com

            "Host" quoted
                HostName quoted.example.com

            Host first second
                User shared

            Host *.example.com !skip
                User pattern

            Host bare
            Match host bare
                User matched

            Host crlf\r
                HostName crlf.example.com\r
                Port\r

            """)

        #expect(file.aliases == [
            SSHHostAlias(
                alias: "work",
                hostName: "10.0.0.8",
                user: "al ex",
                port: "2222",
                identityFile: "~/Library/Application Support/k\"e\\y"
            ),
            SSHHostAlias(alias: "quoted", hostName: "quoted.example.com"),
            SSHHostAlias(alias: "bare"),
            SSHHostAlias(alias: "crlf", hostName: "crlf.example.com"),
        ])

        // 查重看全部 Host 行里的名称，几个名称共用的行也算；编辑时不和自己比较
        #expect(file.containsHost(named: "second"))
        #expect(file.containsHost(named: "work"))
        #expect(!file.containsHost(named: "work", except: 0))
        #expect(file.containsHost(named: "quoted", except: 0))
        #expect(!file.containsHost(named: "fallback"))
    }

    /// 改名只换 `Host` 行里的那个词，改值只换那一行的第一个参数：缩进、等号、行尾注释与别的选项照旧，值没变的行逐字不动；
    /// 清空的选项删掉那一行，新加的选项按先后插在已有选项之后、缩进同这一段。
    @Test("修改别名只动涉及的行")
    func replacesInPlace() {
        var file = SSHConfigFile(text: """
            # 说明
            Host *
                User fallback

            # 工作
            Host work   # 行尾注释
            \tHostName = 10.0.0.8   # 机房
            \tProxyJump bastion
            \tuser alex
            \tIdentityFile "~/.ssh/work key"

            Host other
                HostName other.example.com
                User first
                User second

            """)

        file.replace(
            at: 0,
            with: SSHHostAlias(alias: "office", hostName: "10.0.0.9", port: "2200", identityFile: "~/.ssh/work key")
        )

        // 同一个选项出现两次时只改第一行
        file.replace(at: 1, with: SSHHostAlias(alias: "other", hostName: "other.example.com", user: "changed"))

        // 超出范围的位置不改动
        file.replace(at: 2, with: SSHHostAlias(alias: "missing"))

        #expect(file.text == """
            # 说明
            Host *
                User fallback

            # 工作
            Host office   # 行尾注释
            \tHostName = 10.0.0.9   # 机房
            \tPort 2200
            \tProxyJump bastion
            \tIdentityFile "~/.ssh/work key"

            Host other
                HostName other.example.com
                User changed
                User second

            """)

        // 段里还没有任何选项时，新加的各行紧跟 Host 行，缩进四个空格；原文不以换行结尾时照旧
        var bare = SSHConfigFile(text: "Host bare")

        bare.replace(
            at: 0,
            with: SSHHostAlias(alias: "bare", hostName: "h", user: "u", port: "22", identityFile: "~/k")
        )

        #expect(bare.text == "Host bare\n    HostName h\n    User u\n    Port 22\n    IdentityFile ~/k")
    }

    /// 删掉的是 `Host` 行到这一段最后一条配置，之间的注释一起删；段前的注释、段后的注释与别的段留下。
    /// 删完前后都是空行时只留一处，文件的开头与结尾不留多出的空行。
    @Test(
        "删除别名",
        arguments: [
            // 中间的一段：上方的注释、最后一条配置之后的注释都留下，前后的空行并成一处
            (
                "Host a\n  x 1\n\n# 关于 b\nHost b\n  # 段内\n  y 2\n  # 段尾\n\nHost c\n  z 3\n",
                1,
                "Host a\n  x 1\n\n# 关于 b\n  # 段尾\n\nHost c\n  z 3\n"
            ),
            ("Host a\n  x 1\n\nHost b\n  y 2\n\nHost c\n  z 3\n", 1, "Host a\n  x 1\n\nHost c\n  z 3\n"),

            // 最后一段、第一段与唯一的一段
            ("Host a\n  x 1\n\nHost b\n  y 2\n", 1, "Host a\n  x 1\n"),
            ("Host a\n  x 1\n\nHost b\n  y 2\n", 0, "Host b\n  y 2\n"),
            ("Host a\n  x 1\n", 0, ""),

            // 段与段之间没有空行；后面紧跟 Match 段
            ("Host a\n  x 1\nHost b\n  y 2\nHost c\n  z 3", 1, "Host a\n  x 1\nHost c\n  z 3"),
            ("Host a\n  x 1\nMatch all\n  y 2\n", 0, "Match all\n  y 2\n"),

            // 没有选项的段只删 Host 行；超出范围的位置不改动
            ("Host a\nHost b\n  y 2\n", 0, "Host b\n  y 2\n"),
            ("Host a\n  x 1\n", 1, "Host a\n  x 1\n"),
        ] as [(String, Int, String)]
    )
    func removes(text: String, index: Int, expected: String) {
        var file = SSHConfigFile(text: text)

        file.remove(at: index)

        #expect(file.text == expected)
    }

    /// 新的一段只写有值的选项，含空格、引号的值加引号写出，读回来与填的相同。
    /// 它写在第一个适用于多个主机的段和紧贴那一段的注释之前，没有这样的段时写在文件末尾，与前后的内容各隔一个空行。
    @Test(
        "添加别名",
        arguments: [
            ("", "Host new\n    HostName 203.0.113.10\n    IdentityFile \"~/my keys/k\\\"1\"\n", 0),
            (
                "Host a\n  x 1",
                "Host a\n  x 1\n\nHost new\n    HostName 203.0.113.10\n    IdentityFile \"~/my keys/k\\\"1\"\n",
                1
            ),
            ("# 说明\n\n", "# 说明\n\nHost new\n    HostName 203.0.113.10\n    IdentityFile \"~/my keys/k\\\"1\"\n", 0),
            (
                "Host a\n  x 1\n\n# 默认\nHost *\n  y 2\n",
                "Host a\n  x 1\n\nHost new\n    HostName 203.0.113.10\n    IdentityFile \"~/my keys/k\\\"1\"\n\n# 默认\nHost *\n  y 2\n",
                1
            ),
            (
                "Host a\n  x 1\nMatch all\n  y 2\n\nHost b",
                "Host a\n  x 1\n\nHost new\n    HostName 203.0.113.10\n    IdentityFile \"~/my keys/k\\\"1\"\n\nMatch all\n  y 2\n\nHost b",
                1
            ),
            (
                "Host *.example.com !a\n  y 2\n",
                "Host new\n    HostName 203.0.113.10\n    IdentityFile \"~/my keys/k\\\"1\"\n\nHost *.example.com !a\n  y 2\n",
                0
            ),
        ]
    )
    func adds(text: String, expected: String, index: Int) {
        let alias = SSHHostAlias(alias: "new", hostName: "203.0.113.10", identityFile: "~/my keys/k\"1")
        var file = SSHConfigFile(text: text)

        #expect(file.add(alias) == index)
        #expect(file.text == expected)
        #expect(file.aliases.firstIndex(of: alias) == index)
    }

    /// 别名要能交给 SSH 连接、不是模式；地址与用户名不含空白；端口是 1–65535 的整数；私钥路径可以有空格，不能有换行。
    @Test(
        "保存前的字段校验",
        arguments: [
            (SSHHostAlias(alias: "driftwood-server", hostName: "203.0.113.10", user: "alex", port: "22"), nil),
            (SSHHostAlias(alias: "nas", identityFile: "~/Library/Application Support/key"), nil),
            (SSHHostAlias(alias: ""), .alias),
            (SSHHostAlias(alias: "-oProxyCommand"), .alias),
            (SSHHostAlias(alias: "two words"), .alias),
            (SSHHostAlias(alias: "alex@host"), .alias),
            (SSHHostAlias(alias: "*.example.com"), .alias),
            (SSHHostAlias(alias: "host?"), .alias),
            (SSHHostAlias(alias: "!host"), .alias),
            (SSHHostAlias(alias: "host", hostName: "exam ple.com"), .hostName),
            (SSHHostAlias(alias: "host", user: "al\tex"), .user),
            (SSHHostAlias(alias: "host", port: "0"), .port),
            (SSHHostAlias(alias: "host", port: "65536"), .port),
            (SSHHostAlias(alias: "host", port: "ssh"), .port),
            (SSHHostAlias(alias: "host", port: "+22"), .port),
            (SSHHostAlias(alias: "host", port: "65535"), nil),
            (SSHHostAlias(alias: "host", identityFile: "~/key\nHost *"), .identityFile),
        ] as [(SSHHostAlias, SSHHostAlias.Field?)]
    )
    func validates(alias: SSHHostAlias, invalid: SSHHostAlias.Field?) {
        #expect(alias.invalidField == invalid)
    }

    /// 添加再修改之后的文件交给本机的 `ssh -G` 解析：改过的别名读出的就是填的值，后面的通配符段盖不过它、只补上它没写的选项；
    /// 别的主机的选项照旧。
    @Test("写出的配置由 OpenSSH 读回")
    func readableByOpenSSH() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appending(path: "config")
        var file = SSHConfigFile(
            text: "Host old\n    HostName = old.example.com # 旧\n\nHost *\n    User fallback\n    ServerAliveInterval 30\n"
        )

        let added = file.add(SSHHostAlias(alias: "driftwood-server", hostName: "203.0.113.10", user: "alex"))

        file.replace(
            at: added,
            with: SSHHostAlias(
                alias: "driftwood-server",
                hostName: "203.0.113.11",
                user: "alex",
                port: "2222",
                identityFile: "~/Library/Application Support/k\"e\\y"
            )
        )

        file.replace(at: 0, with: SSHHostAlias(alias: "renamed", hostName: "new.example.com"))
        try file.write(to: url)

        let server = try Self.effectiveOptions(of: "driftwood-server", in: url)

        #expect(server["hostname"] == ["203.0.113.11"])
        #expect(server["user"] == ["alex"])
        #expect(server["port"] == ["2222"])
        #expect(server["identityfile"] == ["~/Library/Application Support/k\"e\\y"])
        #expect(server["serveraliveinterval"] == ["30"])

        let renamed = try Self.effectiveOptions(of: "renamed", in: url)

        #expect(renamed["hostname"] == ["new.example.com"])
        #expect(renamed["user"] == ["fallback"])
        #expect(try Self.effectiveOptions(of: "old", in: url)["hostname"] == ["old"])
    }

    /// 文件不存在时读出空的配置，写入时建出只有本人可进的目录与只有本人可读写的文件；已有文件的权限位照旧。
    /// 位置是符号链接时写进它指向的文件，链接还在；不是 UTF-8 文本的文件读不出，不会被当成空文件覆盖。
    @Test("读写配置文件")
    func readsAndWritesFile() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = FileManager.default
        let url = directory.appending(path: ".ssh/config")
        let permissions = { (path: URL) in try manager.attributesOfItem(atPath: path.path)[.posixPermissions] as? Int }

        // 文件与目录都还没有
        var file = try SSHConfigFile(contentsOf: url)
        #expect(file.text.isEmpty)

        file.add(SSHHostAlias(alias: "first"))
        try file.write(to: url)

        #expect(try SSHConfigFile(contentsOf: url) == file)
        #expect(try permissions(url.deletingLastPathComponent()) == 0o700)
        #expect(try permissions(url) == 0o600)

        // 已有文件的权限位照旧
        try manager.setAttributes([.posixPermissions: 0o640], ofItemAtPath: url.path)
        file.add(SSHHostAlias(alias: "second"))
        try file.write(to: url)

        #expect(try permissions(url) == 0o640)

        // 经符号链接写入：改的是它指向的文件
        let link = directory.appending(path: "link")
        try manager.createSymbolicLink(at: link, withDestinationURL: url)

        file.add(SSHHostAlias(alias: "third"))
        try file.write(to: link)

        #expect(try manager.destinationOfSymbolicLink(atPath: link.path) == url.path)
        #expect(try SSHConfigFile(contentsOf: url).aliases.map(\.alias) == ["first", "second", "third"])

        // 不是 UTF-8 文本
        let binary = directory.appending(path: "binary")
        try Data([0x48, 0x6F, 0x73, 0x74, 0x20, 0xFF, 0xFE]).write(to: binary)

        #expect(throws: CocoaError.self) {
            _ = try SSHConfigFile(contentsOf: binary)
        }
    }
}

// MARK: - Helpers

extension SSHConfigFileTests {
    /// 新建一个临时目录，调用方负责删除。
    private static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "com.rakuyo.spooky.tests.ssh-config." + UUID().uuidString)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return directory.resolvingSymlinksInPath()
    }

    /// 用本机的 OpenSSH 解析配置文件，取出这个主机生效的选项：小写的关键字到它的各个值。
    ///
    /// `ssh -G` 只解析配置、不连接；给了 `-F` 时不读系统与用户的配置。
    private static func effectiveOptions(of host: String, in config: URL) throws -> [String: [String]] {
        let process = Process()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = ["-F", config.path, "-G", host]
        process.standardOutput = output
        process.standardError = Pipe()

        try process.run()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        try #require(process.terminationStatus == 0)

        var options: [String: [String]] = [:]

        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)

            options[String(parts[0]), default: []].append(parts.count > 1 ? String(parts[1]) : "")
        }

        return options
    }
}
