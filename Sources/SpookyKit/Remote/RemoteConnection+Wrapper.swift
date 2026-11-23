import CryptoKit
import Foundation

// MARK: - Wrapper

extension RemoteConnection {
    /// 包装器的回调入口：与包装器同一文件的硬链接，包装器按调用名的后缀区分模式。
    static let callbackLinks = ["askpass", "git-askpass", "gpg", "ssh-keygen"]

    /// 部署新版本时，删掉超过这么多天没有新建过会话的旧版本。
    static let wrapperRetentionDays = 30

    /// 随 App 分发的包装器：源码与按内容摘要生成的版本化文件名；资源缺失时为 nil。
    static let bundledWrapper: (source: Data, filename: String)? = {
        guard
            let resource = Bundle.module.url(forResource: "spooky-remote", withExtension: "pl"),
            let source = try? Data(contentsOf: resource)
        else { return nil }

        let version = SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
        return (source, wrapperPrefix + String(version.prefix(16)))
    }()

    /// 包装器文件名的前缀，后接内容摘要。
    private static let wrapperPrefix = "spooky-remote-v1-"

    /// 在 B 上原子安装包装器与全部回调入口并输出包装器的绝对路径，再由包装器新建会话、写入令牌并输出会话目录。
    ///
    /// 标准输入先是包装器源码，紧接着是一行会话令牌：安装只读走源码的字节数，余下的令牌留给开始会话的那一步，
    /// 它写入令牌后分出会话看守。
    /// 位置参数依次是会话看守的心跳容忍期与操作保留期。
    /// 安装之后删掉 ``wrapperRetentionDays`` 天里没有新建过会话的旧版本。
    ///
    /// - Parameters:
    ///   - filename: 按脚本内容摘要生成的版本化文件名。
    ///   - length: 包装器源码的字节数。
    static func deploymentScript(filename: String, length: Int) -> String {
        let links = callbackLinks.map { "\"$spooky_install_file-\($0)\"" }.joined(separator: " ")

        let linking = callbackLinks
            .map { "ln \"$spooky_install_file\" \"$spooky_install_file-\($0)\"" }
            .joined(separator: "\n")

        let moving = callbackLinks
            .map { "mv -f \"$spooky_install_file-\($0)\" \"$HOME/.spooky/bin/\(filename)-\($0)\"" }
            .joined(separator: "\n")

        // 按字节数逐块读取，不多读一个字节；源码不足时失败
        let copying = """
            binmode STDIN;
            binmode STDOUT;
            my $left = $ARGV[0];

            while ($left > 0) {
                my $count = sysread(STDIN, my $chunk, $left < 65536 ? $left : 65536) or exit 1;
                print $chunk;
                $left -= $count;
            }
            """

        // 别的客户端可能还在用旧版本：每次新建会话都会更新包装器的访问时间，按它只删掉长期没人用的版本；
        // 回调入口是同一文件的硬链接，访问时间相同，随之一起删掉。清理失败不影响部署
        let cleaning = "find \"$HOME/.spooky/bin\" -maxdepth 1 -type f -name '\(wrapperPrefix)*'"
            + " -atime +\(wrapperRetentionDays) -exec rm -f {} + || :"

        return """
            set -eu
            umask 077
            /usr/bin/perl -MIO::Socket::UNIX -MJSON::PP -MPOSIX -MFcntl -e 'exit 0'
            test ! -L "$HOME/.spooky"
            test ! -L "$HOME/.spooky/bin"
            mkdir -p "$HOME/.spooky/bin"
            chmod 700 "$HOME/.spooky" "$HOME/.spooky/bin"
            spooky_install_file=$(mktemp "$HOME/.spooky/bin/.install-XXXXXXXX")
            trap 'rm -f "$spooky_install_file" \(links)' EXIT HUP INT TERM
            /usr/bin/perl -e \(GitRunner.shellQuoted(copying)) \(length) > "$spooky_install_file"
            chmod 700 "$spooky_install_file"
            \(linking)
            mv -f "$spooky_install_file" "$HOME/.spooky/bin/\(filename)"
            \(moving)
            \(cleaning)
            printf '%s\\n' "$HOME/.spooky/bin/\(filename)"
            spooky_session=$("$HOME/.spooky/bin/\(filename)" create-session)
            "$HOME/.spooky/bin/\(filename)" start-session "$spooky_session" "$1" "$2"
            printf '%s\\n' "$spooky_session"
            """
    }

    /// 在 B 上执行一条 Git 命令用的程序。
    ///
    /// 只读命令直接执行体检找到的 Git，省掉 macOS 上 `/usr/bin/git` 转发壳每次查找开发者工具的开销；
    /// 其余命令照旧按 PATH 执行 `git`。
    ///
    /// - Parameters:
    ///   - arguments: Git 的参数，不含程序本身。
    ///   - executable: 体检找到的 Git 的绝对路径；没有时为 nil。
    static func gitCommand(for arguments: [String], executable: String?) -> String {
        guard let executable, RepositoryOperationQueue.isReadOnly(arguments) else { return "git" }

        return executable
    }

    /// 每条远端 Git 命令附加的回调配置：凭据、编辑器、SSH 与提交签名的交互都经本会话中继回到 A。
    ///
    /// 编辑器、SSH 命令与凭据助手由 Git 交给 shell 执行，需要转义；askpass 与签名程序直接执行，路径原样传入。
    /// B 上的凭据助手先全部清空，``GitCredentialScopes`` 里的地址再交给包装器，由 A 用账号令牌回答。
    static func callbackOptions(wrapper: String) -> [String] {
        let callback = GitRunner.shellQuoted(wrapper)

        return ["-c", "credential.helper="] + GitCredentialScopes.options(callback: callback) + [
            "-c", "core.askPass=\(wrapper)-git-askpass",
            "-c", "core.editor=\(callback) editor",
            "-c", "sequence.editor=\(callback) editor",
            "-c", "core.sshCommand=\(callback) ssh",
            "-c", "gpg.program=\(wrapper)-gpg",
            "-c", "gpg.ssh.program=\(wrapper)-ssh-keygen",
        ]
    }

    /// 写入会话的令牌：本机中继的令牌一行，只经标准输入交给 B。
    func sessionRequest() throws -> Data {
        guard let relay else { throw RemoteConnectionError(.deployment) }
        return Data((relay.token + "\n").utf8)
    }

    /// 在 B 上安装包装器并新建会话：包装器源码与会话令牌先后经标准输入交给部署脚本。
    func deployWrapper() async throws {
        guard let bundled = Self.bundledWrapper else { throw RemoteConnectionError(.deployment) }

        let deployed = try await probe(
            [
                "/bin/sh", "-c", Self.deploymentScript(filename: bundled.filename, length: bundled.source.count),
                "spooky-deploy",
                String(configuration.heartbeatTolerance),
                String(configuration.operationRetention),
            ],
            input: bundled.source + sessionRequest(),
            kind: .deployment
        )

        try recordSession(deployed)
    }
}
