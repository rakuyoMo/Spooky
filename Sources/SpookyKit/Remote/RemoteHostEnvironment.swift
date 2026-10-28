import Foundation

// MARK: - RemoteHostEnvironment

/// 体检读到的 B 端非交互 shell 环境：主目录、PATH、找到的 Git、可用的废纸篓程序与 GIT_ 变量名。
///
/// 只在内存里交给界面显示修复方向，不写进日志、错误对象或仓库记录；GIT_ 变量只记名字，不记值。
public struct RemoteHostEnvironment: Sendable, Equatable {
    /// 在 B 上读取环境的脚本：依次输出主目录、PATH、`command -v git` 的结果、废纸篓程序与 GIT_ 变量名，各项以 NUL 结尾。
    ///
    /// 废纸篓程序写成 “<种类>:<路径>”：macOS 只用系统自带的 `/usr/bin/trash`，其它系统依次找 `gio` 与 `trash-put`。
    static let script = """
        printf '%s\\0%s\\0' "$HOME" "$PATH"
        command -v git || :
        printf '\\0'
        case $(uname -s) in
            Darwin) if test -x /usr/bin/trash; then printf 'trash:/usr/bin/trash'; fi ;;
            *)
                if trash=$(command -v gio); then printf 'gio:%s' "$trash"
                elif trash=$(command -v trash-put); then printf 'trash-put:%s' "$trash"
                fi
                ;;
        esac
        printf '\\0'
        exec /usr/bin/perl -e 'print map { "$_\\0" } sort grep { /\\AGIT_/ } keys %ENV'
        """

    /// SSH 登录用户在 B 上的主目录。
    public let homeDirectory: String

    /// 非交互 shell 的 PATH，按目录拆开，保持原有顺序。
    public let searchPath: [String]

    /// `command -v git` 找到的 Git；PATH 里没有 Git 时为 nil。
    public let gitPath: String?

    /// `git --version` 的输出；体检没有走到这一步时为 nil。
    public internal(set) var gitVersion: String?

    /// 把文件移进废纸篓的程序；B 上没有可用的程序时为 nil。
    public let trash: RemoteTrash?

    /// 非交互环境里设置了、Spooky 又没有清除的 GIT_ 变量名，它们会改变 Git 查找仓库或读取配置的方式。
    public let gitVariables: [String]

    /// 用已知的环境创建，供测试与界面预览使用。
    public init(
        homeDirectory: String,
        searchPath: [String],
        gitPath: String?,
        gitVersion: String? = nil,
        trash: RemoteTrash? = nil,
        gitVariables: [String] = []
    ) {
        self.homeDirectory = homeDirectory
        self.searchPath = searchPath
        self.gitPath = gitPath
        self.gitVersion = gitVersion
        self.trash = trash
        self.gitVariables = gitVariables
    }

    /// 解析 ``script`` 的输出；主目录不是绝对路径或字段不全时返回 nil。
    ///
    /// - Parameters:
    ///   - output: 脚本的标准输出。
    ///   - excluding: Spooky 自己在远端命令里设置的变量名，不算作 B 的环境问题。
    init?(output: Data, excluding: Set<String>) {
        let fields = output
            .split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }

        // 末尾的 NUL 会切出一个空字段：主目录、PATH、Git、废纸篓四项之后才是变量名
        guard fields.count >= 5, fields[0].hasPrefix("/") else { return nil }

        let git = fields[2].trimmingCharacters(in: .newlines)

        self.init(
            homeDirectory: fields[0],
            searchPath: fields[1].split(separator: ":").map(String.init),
            gitPath: git.isEmpty ? nil : git,
            trash: RemoteTrash(probe: fields[3]),
            gitVariables: fields[4...].filter { !$0.isEmpty && !excluding.contains($0) }
        )
    }
}

// MARK: - RemoteTrash

/// B 上把文件移进废纸篓的程序，由连接体检找到。
public enum RemoteTrash: Sendable, Equatable {
    /// macOS 15 起系统自带的 `/usr/bin/trash`：`-v` 写出每一项在废纸篓里的位置，撤销时据此移回。
    case macOS

    /// GLib 的 `gio trash`，按 freedesktop 规范放进 `~/.local/share/Trash`，不报告位置；关联值是程序的绝对路径。
    case gio(String)

    /// trash-cli 的 `trash-put`，同样按 freedesktop 规范放进废纸篓，不报告位置；关联值是程序的绝对路径。
    case trashPut(String)

    /// 解析环境脚本写出的 “<种类>:<路径>”；没有找到程序或写法认不出时为 nil。
    init?(probe: String) {
        guard let colon = probe.firstIndex(of: ":") else { return nil }

        let path = String(probe[probe.index(after: colon)...])

        guard path.hasPrefix("/") else { return nil }

        switch probe[..<colon] {
        case "trash" where path == "/usr/bin/trash": self = .macOS
        case "gio": self = .gio(path)
        case "trash-put": self = .trashPut(path)
        default: return nil
        }
    }
}
