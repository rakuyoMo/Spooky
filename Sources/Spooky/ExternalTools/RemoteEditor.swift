import Foundation

// MARK: - RemoteEditor

/// 支持经 SSH 远程编辑的编辑器：VS Code、VS Code Insiders 与 Cursor 经各自的 Remote SSH 扩展，
/// 按主机别名与远端路径直接打开服务器上的文件，不经本机副本。
///
/// 地址是 `<scheme>://vscode-remote/ssh-remote+<主机><路径>:1`；末尾的 `:1` 是行号，少了它编辑器会把路径当成文件夹打开。
enum RemoteEditor {
    /// 远程打开服务器文件的地址；这个编辑器不支持远程编辑时为 nil。
    ///
    /// - Parameters:
    ///   - host: `~/.ssh/config` 中的主机别名。
    ///   - path: 文件在服务器上的绝对路径。
    ///   - bundleIdentifier: 编辑器的 Bundle Identifier。
    static func url(host: String, path: String, bundleIdentifier: String?) -> URL? {
        // 各编辑器的 Bundle Identifier 与它注册的地址 scheme
        let schemes = [
            "com.microsoft.VSCode": "vscode",
            "com.microsoft.VSCodeInsiders": "vscode-insiders",
            "com.todesktop.230313mzl4w4u92": "cursor",
        ]

        guard let bundleIdentifier, let scheme = schemes[bundleIdentifier], path.hasPrefix("/") else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = "vscode-remote"
        components.path = "/ssh-remote+" + host + path + ":1"

        return components.url
    }
}
