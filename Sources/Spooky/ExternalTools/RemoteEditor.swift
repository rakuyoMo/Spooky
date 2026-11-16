import Foundation

// MARK: - RemoteEditor

/// 支持经 SSH 远程编辑的编辑器：VS Code、VS Code Insiders 与 Cursor 装了 Remote SSH 扩展时，
/// 按主机别名与远端路径直接打开服务器上的文件，不经本机副本。
///
/// 地址是 `<scheme>://vscode-remote/ssh-remote+<主机><路径>:1`；末尾的 `:1` 是行号，少了它编辑器会把路径当成文件夹打开。
/// 没装扩展的编辑器收到这个地址只会打开一个连不上的空窗口，所以没装时没有远程地址。
struct RemoteEditor {
    /// 各编辑器按 Bundle Identifier 登记。
    private static let editors = [
        "com.microsoft.VSCode": Self(
            scheme: "vscode",
            extensionsDirectory: ".vscode/extensions",
            extensions: ["ms-vscode-remote.remote-ssh"]
        ),
        "com.microsoft.VSCodeInsiders": Self(
            scheme: "vscode-insiders",
            extensionsDirectory: ".vscode-insiders/extensions",
            extensions: ["ms-vscode-remote.remote-ssh"]
        ),
        "com.todesktop.230313mzl4w4u92": Self(
            scheme: "cursor",
            extensionsDirectory: ".cursor/extensions",
            extensions: ["anysphere.remote-ssh", "ms-vscode-remote.remote-ssh", "jeanp413.open-remote-ssh"]
        ),
    ]

    /// 编辑器注册的地址 scheme。
    private let scheme: String

    /// 编辑器存放扩展的目录，相对用户主目录。
    private let extensionsDirectory: String

    /// 能解析 `ssh-remote` 地址的扩展的标识，装了任意一个即可。
    private let extensions: [String]

    /// 远程打开服务器文件的地址；这个编辑器不支持远程编辑或没装 Remote SSH 扩展时为 nil。
    ///
    /// - Parameters:
    ///   - host: `~/.ssh/config` 中的主机别名。
    ///   - path: 文件在服务器上的绝对路径。
    ///   - bundleIdentifier: 编辑器的 Bundle Identifier。
    ///   - home: 用户主目录，编辑器的扩展目录在它下面。
    static func url(
        host: String,
        path: String,
        bundleIdentifier: String?,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL? {
        guard
            let bundleIdentifier,
            let editor = editors[bundleIdentifier],
            path.hasPrefix("/"),
            editor.hasRemoteExtension(in: home)
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = editor.scheme
        components.host = "vscode-remote"
        components.path = "/ssh-remote+" + host + path + ":1"

        return components.url
    }

    /// 扩展目录里有没有 Remote SSH 扩展：每个扩展一个子目录，名字是 `<标识>-<版本>`。
    private func hasRemoteExtension(in home: URL) -> Bool {
        let directory = home.appending(path: extensionsDirectory)
        let installed = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []

        return installed.contains { name in
            extensions.contains { name.lowercased().hasPrefix($0 + "-") }
        }
    }
}
