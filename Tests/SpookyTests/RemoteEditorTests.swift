import Foundation
import Testing

@testable import Spooky

// MARK: - RemoteEditorTests

/// 服务器文件的远程打开：只有装了 Remote SSH 扩展的 VS Code、VS Code Insiders 与 Cursor 直接打开服务器上的文件，
/// 其它情形仍走本机副本。
struct RemoteEditorTests {
    /// 三个编辑器各用自己的 scheme；地址末尾都带 `:1`，编辑器才按文件而不是文件夹打开；
    /// 路径里的空格与中文按 UTF-8 百分号编码，解码后仍是服务器上的原路径；
    /// 其它编辑器、未知的程序与相对路径都没有远程地址，交给本机副本的流程；
    /// 没装 Remote SSH 扩展的编辑器同样没有远程地址，否则它只会打开一个连不上的空窗口。
    @Test("远程打开地址")
    func addresses() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "remote-editor-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }

        let install = { (directory: String, name: String) in
            try FileManager.default.createDirectory(
                at: home.appending(path: directory).appending(path: name),
                withIntermediateDirectories: true
            )
        }

        let address = { (path: String, bundleIdentifier: String?) in
            RemoteEditor.url(host: "spooky-test", path: path, bundleIdentifier: bundleIdentifier, home: home)
        }

        let cursor = "com.todesktop.230313mzl4w4u92"

        // 没装扩展：扩展目录不存在，或里面只有别的扩展
        try install(".cursor/extensions", "anysphere.cursorpyright-1.0.8")

        #expect(address("/srv/repo/main.swift", "com.microsoft.VSCode") == nil)
        #expect(address("/srv/repo/main.swift", cursor) == nil)

        // 三个编辑器各用自己的 scheme，地址的其余部分相同。
        try install(".vscode/extensions", "ms-vscode-remote.remote-ssh-0.120.0")
        try install(".vscode-insiders/extensions", "ms-vscode-remote.remote-ssh-0.120.0")
        try install(".cursor/extensions", "anysphere.remote-ssh-1.0.30")

        let target = "vscode-remote/ssh-remote+spooky-test/srv/repo/main.swift:1"
        let expected = [
            "com.microsoft.VSCode": "vscode://" + target,
            "com.microsoft.VSCodeInsiders": "vscode-insiders://" + target,
            cursor: "cursor://" + target,
        ]

        for (bundleIdentifier, url) in expected {
            #expect(address("/srv/repo/main.swift", bundleIdentifier)?.absoluteString == url)
        }

        // 路径含空格与中文
        let url = try #require(address("/srv/我的 仓库/说明 文档.md", cursor))

        #expect(
            url.absoluteString
                == "cursor://vscode-remote/ssh-remote+spooky-test/srv/%E6%88%91%E7%9A%84%20%E4%BB%93%E5%BA%93/"
                + "%E8%AF%B4%E6%98%8E%20%E6%96%87%E6%A1%A3.md:1"
        )

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "/ssh-remote+spooky-test/srv/我的 仓库/说明 文档.md:1")

        // 其它编辑器、未知的程序与相对路径
        #expect(address("/srv/a.txt", "com.apple.TextEdit") == nil)
        #expect(address("/srv/a.txt", nil) == nil)
        #expect(address("a.txt", "com.microsoft.VSCode") == nil)
    }
}
