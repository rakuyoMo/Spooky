import Foundation
import Subprocess
import Synchronization

// MARK: - LocalExecutionSettings

/// 在本机启动 Git 与 SSH 时使用的程序与环境：所选的 Git 程序、登录 shell 的变量、自定义变量与所选 SSH agent 的 socket。
///
/// 只作用于本机：服务器仓库的 Git 在对方机器上执行，用那台机器自己的程序与环境。
/// App 在启动和设置变化时写入 ``current``；变量的值可能含有令牌，不进日志、错误对象与 Activity。
public struct LocalExecutionSettings: Sendable, Equatable {
    /// 没有选择其它程序时使用的系统 Git。
    public static let defaultGitExecutable = "/usr/bin/git"

    /// 记录当前设置；读写都加锁，任何线程都可以读取。
    private static let stored = Mutex(Self())

    /// 本机命令此刻使用的设置；每条命令启动时读取一次，设置变化后的下一条命令即生效。
    public static var current: Self {
        get { stored.withLock { $0 } }
        set { stored.withLock { $0 = newValue } }
    }

    /// 本机 Git 程序的绝对路径。
    public var gitExecutable: String

    /// 从登录 shell 读到的变量；没有开启读取时为空。
    public var loginShellVariables: [String: String]

    /// 用户保存的自定义变量，覆盖登录 shell 里的同名变量。
    public var customVariables: [String: String]

    /// 所选 SSH agent 的 socket；nil 时沿用 Spooky 进程继承的 `SSH_AUTH_SOCK`。
    public var sshAuthSocket: String?

    /// 本机 ssh、sftp 与 ssh-add 的覆盖项：只有所选 SSH agent 的 socket，登录 shell 与自定义变量只交给 Git。
    var sshOverrides: [Environment.Key: String?] {
        Self.keyed(sshAuthSocket.map { ["SSH_AUTH_SOCK": $0] } ?? [:])
    }

    /// 创建一份设置，各项默认与 Spooky 没有任何设置时相同。
    ///
    /// - Parameters:
    ///   - gitExecutable: 本机 Git 程序的绝对路径。
    ///   - loginShellVariables: 从登录 shell 读到的变量。
    ///   - customVariables: 用户保存的自定义变量。
    ///   - sshAuthSocket: 所选 SSH agent 的 socket。
    public init(
        gitExecutable: String = defaultGitExecutable,
        loginShellVariables: [String: String] = [:],
        customVariables: [String: String] = [:],
        sshAuthSocket: String? = nil
    ) {
        self.gitExecutable = gitExecutable
        self.loginShellVariables = loginShellVariables
        self.customVariables = customVariables
        self.sshAuthSocket = sshAuthSocket
    }

    /// 环境变量名可以交给子进程：非空，且不含 `=` 与 NUL。
    public static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("=") && !name.contains("\0")
    }

    /// 把变量名转成子进程环境的键。
    private static func keyed(_ values: [String: String]) -> [Environment.Key: String?] {
        Dictionary(
            uniqueKeysWithValues: values.compactMap { name, value in
                Environment.Key(rawValue: name).map { ($0, Optional(value)) }
            }
        )
    }

    /// 本机 git 子进程在继承的环境之上的覆盖项，后写的覆盖先写的。
    ///
    /// 依次是登录 shell 的变量、自定义变量、所选 SSH agent 的 socket；
    /// 所选程序所在的目录不在 `PATH` 里时补在最前，同目录下随它安装的 git-lfs 等程序才能被找到。
    /// 语言、终端提示与仓库定位相关的变量由 ``GitRunner`` 在这之后统一固定。
    ///
    /// - Parameter inheritedPath: 子进程继承到的 `PATH`，用于判断 Git 所在目录是否已在其中。
    func gitOverrides(inheritedPath: String?) -> [Environment.Key: String?] {
        var values = loginShellVariables.filter { Self.isValidName($0.key) }

        values.merge(customVariables.filter { Self.isValidName($0.key) }) { $1 }

        if let sshAuthSocket {
            values["SSH_AUTH_SOCK"] = sshAuthSocket
        }

        // 只在缺少这个目录时改写 PATH；系统 Git 所在的 /usr/bin 总在 PATH 里，默认设置下 PATH 保持原样。
        let directory = URL(fileURLWithPath: gitExecutable).deletingLastPathComponent().path
        let path = values["PATH"] ?? inheritedPath ?? ""

        if !path.split(separator: ":").contains(Substring(directory)) {
            values["PATH"] = path.isEmpty ? directory : directory + ":" + path
        }

        return Self.keyed(values)
    }
}
