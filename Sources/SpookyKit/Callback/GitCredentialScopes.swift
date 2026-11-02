import Synchronization

// MARK: - GitCredentialScopes

/// 交给 Spooky 回答凭据的 HTTPS 地址前缀，如已登录账号的实例与手动关联的远端。
///
/// 这些地址上 Git 的凭据助手只有包装器的 `credential` 入口，由 App 经回调中继用账号的令牌回答，回答不了时 Git 再问 askpass；
/// 用户自己的凭据助手（如 osxkeychain）不参与这些地址，令牌不会被它们存走。
/// App 在启动与账号、关联变化时写入 ``current``，本机与服务器上的每条命令启动时读取。
public enum GitCredentialScopes {
    /// 记录当前的前缀；读写都加锁，任何线程都可以读取。
    private static let stored = Mutex<[String]>([])

    /// 此刻的前缀，如 `https://github.com`、`https://example.com/gitlab`；为空时命令不加任何凭据助手配置。
    public static var current: [String] {
        get { stored.withLock { $0 } }
        set { stored.withLock { $0 = newValue } }
    }

    /// 每个前缀的三项配置，顺序固定：先清空这个前缀上已有的助手，再加上包装器，最后让 Git 把地址的路径交给助手与 askpass。
    ///
    /// - Parameter callback: 按 shell 转义过的包装器路径；以 `!` 开头的助手由 Git 交给 shell 执行。
    static func options(callback: String) -> [String] {
        // `-c` 在第一个 “=” 处分开键与值，含 “=” 的前缀会让 Git 读到无效的键，所有命令都会失败
        let prefixes = current.filter { !$0.contains("=") && !$0.contains(where: \.isNewline) }

        return prefixes.flatMap { prefix in
            [
                "-c", "credential.\(prefix).helper=",
                "-c", "credential.\(prefix).helper=!\(callback) credential",
                "-c", "credential.\(prefix).useHttpPath=true",
            ]
        }
    }
}
