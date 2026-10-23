import Foundation

// MARK: - Wrapper

extension RemoteConnection {
    /// 包装器的回调入口：与包装器同一文件的硬链接，包装器按调用名的后缀区分模式。
    static let callbackLinks = ["askpass", "git-askpass", "gpg", "ssh-keygen"]

    /// 在 B 上原子安装包装器与全部回调入口，最后输出包装器的绝对路径；脚本内容经标准输入写入。
    ///
    /// - Parameter filename: 按脚本内容摘要生成的版本化文件名。
    static func installScript(filename: String) -> String {
        let links = callbackLinks.map { "\"$spooky_install_file-\($0)\"" }.joined(separator: " ")
        let linking = callbackLinks
            .map { "ln \"$spooky_install_file\" \"$spooky_install_file-\($0)\"" }
            .joined(separator: "\n")
        let moving = callbackLinks
            .map { "mv -f \"$spooky_install_file-\($0)\" \"$HOME/.spooky/bin/\(filename)-\($0)\"" }
            .joined(separator: "\n")

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
            cat > "$spooky_install_file"
            chmod 700 "$spooky_install_file"
            \(linking)
            mv -f "$spooky_install_file" "$HOME/.spooky/bin/\(filename)"
            \(moving)
            printf '%s\\n' "$HOME/.spooky/bin/\(filename)"
            """
    }

    /// 每条远端 Git 命令附加的回调配置：凭据、编辑器、SSH 与提交签名的交互都经本会话中继回到 A。
    ///
    /// 编辑器与 SSH 命令由 Git 交给 shell 执行，需要转义；askpass 与签名程序直接执行，路径原样传入。
    static func callbackOptions(wrapper: String) -> [String] {
        let callback = GitRunner.shellQuoted(wrapper)

        return [
            "-c", "credential.helper=",
            "-c", "core.askPass=\(wrapper)-git-askpass",
            "-c", "core.editor=\(callback) editor",
            "-c", "sequence.editor=\(callback) editor",
            "-c", "core.sshCommand=\(callback) ssh",
            "-c", "gpg.program=\(wrapper)-gpg",
            "-c", "gpg.ssh.program=\(wrapper)-ssh-keygen",
        ]
    }
}
