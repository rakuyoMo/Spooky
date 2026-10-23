import Foundation

/// 系统 SSH 的连接选项；测试可使用临时配置和 known_hosts，不修改用户配置。
struct SSHConfiguration: Sendable {
    /// 可选的独立配置文件，生产环境使用系统默认路径。
    var file: String?

    /// 可选的已知主机文件，测试指纹失败时使用。
    var knownHosts: String?

    /// 测试专用密钥；生产环境由主机别名决定。
    var identity: String?

    /// B 的隔离测试环境，不写入日志和仓库记录。
    var remoteEnvironment: [String: String] = [:]

    /// 取消远端进程组时 TERM 与 KILL 之间的宽限期。
    var cancellationGrace: Double = 2

    /// 按参数边界传递配置路径，认证失败快速返回且绝不静默接受指纹。
    var options: [String] {
        var options = [
            "-T", "-a",
            "-o", "BatchMode=yes",
            "-o", "ForwardAgent=no",
            "-o", "StrictHostKeyChecking=yes",
            "-o", "ConnectTimeout=8",
            "-o", "ConnectionAttempts=1",
            "-o", "ServerAliveInterval=5",
            "-o", "ServerAliveCountMax=2",
            "-o", "Compression=no",
        ]

        if let file {
            options += ["-F", file]
        }

        if let knownHosts {
            options += ["-o", "UserKnownHostsFile=" + knownHosts, "-o", "GlobalKnownHostsFile=/dev/null"]
        }

        if let identity {
            options += ["-o", "IdentitiesOnly=yes", "-o", "IdentityAgent=none", "-i", identity]
        }

        return options
    }

    /// 固定远端 locale 并清洗仓库定位、编辑器和认证的环境覆盖项。
    var environmentPrefix: [String] {
        let removed = [
            "GIT_EDITOR", "GIT_SEQUENCE_EDITOR", "GIT_ASKPASS", "SSH_ASKPASS",
            "SSH_ASKPASS_REQUIRE", "GIT_SSH", "GIT_SSH_COMMAND", "GIT_SSH_VARIANT",
            "GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE",
            "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_NAMESPACE",
            "GIT_PREFIX", "GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT",
        ]

        return ["/usr/bin/env"] + removed.flatMap { ["-u", $0] }
            + remoteEnvironment.sorted { $0.key < $1.key }.map { $0.key + "=" + $0.value }
            + ["LANG=en_US.UTF-8", "LC_ALL=en_US.UTF-8", "GIT_TERMINAL_PROMPT=0"]
    }
}
