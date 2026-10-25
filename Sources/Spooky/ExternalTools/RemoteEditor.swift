import Foundation

// MARK: - RemoteEditor

/// 支持经 SSH 远程编辑的编辑器：服务器文件按主机别名与远端路径直接远程打开，不经本机副本。
enum RemoteEditor {
    /// 远程打开服务器文件的地址；这个编辑器不支持远程编辑时为 nil。
    ///
    /// - Parameters:
    ///   - host: `~/.ssh/config` 中的主机别名。
    ///   - path: 文件在服务器上的绝对路径。
    ///   - bundleIdentifier: 编辑器的 Bundle Identifier。
    static func url(host: String, path: String, bundleIdentifier: String?) -> URL? {
        #warning("TODO: 在装有 VS Code 与 Remote - SSH 扩展的 Mac 上核对 vscode-remote 地址能直接打开服务器上的文件；只影响服务器文件交给 VS Code 时的打开方式")

        // VS Code 的 Remote - SSH 经 “<scheme>://vscode-remote/ssh-remote+<主机><路径>” 打开远端文件
        let schemes = [
            "com.microsoft.VSCode": "vscode",
            "com.microsoft.VSCodeInsiders": "vscode-insiders",
        ]

        guard let bundleIdentifier, let scheme = schemes[bundleIdentifier], path.hasPrefix("/") else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = "vscode-remote"
        components.path = "/ssh-remote+" + host + path

        return components.url
    }
}
