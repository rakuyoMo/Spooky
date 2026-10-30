import Foundation
import Testing

@testable import Spooky

// MARK: - RemoteEditorTests

/// 服务器文件的远程打开：只有 VS Code、VS Code Insiders 与 Cursor 直接打开服务器上的文件，其它编辑器仍走本机副本。
struct RemoteEditorTests {
    /// 三个编辑器各用自己的 scheme；地址末尾都带 `:1`，编辑器才按文件而不是文件夹打开。
    @Test("VS Code、VS Code Insiders 与 Cursor 的远程打开地址")
    func supportedEditors() {
        let expected = [
            "com.microsoft.VSCode": "vscode://vscode-remote/ssh-remote+spooky-test/srv/repo/main.swift:1",
            "com.microsoft.VSCodeInsiders": "vscode-insiders://vscode-remote/ssh-remote+spooky-test/srv/repo/main.swift:1",
            "com.todesktop.230313mzl4w4u92": "cursor://vscode-remote/ssh-remote+spooky-test/srv/repo/main.swift:1",
        ]

        for (bundleIdentifier, address) in expected {
            let url = RemoteEditor.url(
                host: "spooky-test",
                path: "/srv/repo/main.swift",
                bundleIdentifier: bundleIdentifier
            )

            #expect(url?.absoluteString == address)
        }
    }

    /// 其它编辑器、未知的程序与相对路径都没有远程地址，交给本机副本的流程。
    @Test("其它编辑器与相对路径没有远程地址")
    func unsupported() {
        #expect(RemoteEditor.url(host: "spooky-test", path: "/srv/a.txt", bundleIdentifier: "com.apple.TextEdit") == nil)
        #expect(RemoteEditor.url(host: "spooky-test", path: "/srv/a.txt", bundleIdentifier: nil) == nil)
        #expect(RemoteEditor.url(host: "spooky-test", path: "a.txt", bundleIdentifier: "com.microsoft.VSCode") == nil)
    }

    /// 路径里的空格与中文按 UTF-8 百分号编码，解码后仍是服务器上的原路径。
    @Test("路径含空格与中文")
    func specialCharacters() throws {
        let url = try #require(
            RemoteEditor.url(
                host: "spooky-test",
                path: "/srv/我的 仓库/说明 文档.md",
                bundleIdentifier: "com.todesktop.230313mzl4w4u92"
            )
        )

        #expect(
            url.absoluteString
                == "cursor://vscode-remote/ssh-remote+spooky-test/srv/%E6%88%91%E7%9A%84%20%E4%BB%93%E5%BA%93/"
                + "%E8%AF%B4%E6%98%8E%20%E6%96%87%E6%A1%A3.md:1"
        )

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "/ssh-remote+spooky-test/srv/我的 仓库/说明 文档.md:1")
    }
}
