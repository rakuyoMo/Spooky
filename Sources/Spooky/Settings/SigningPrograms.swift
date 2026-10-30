import AppKit
import SpookyKit

// MARK: - SigningPrograms

/// Git Config 页与仓库设置签名组里可选的程序与文件：本机的 gpg、SSH 签名程序与 allowed signers 文件。
enum SigningPrograms {
    /// 弹出菜单里 “选择文件” 一项的标记，不是任何路径。
    static let chooseTag = "\u{0}choose"

    /// 1Password 的 Bundle Identifier；装了它时提供它的 SSH 签名程序。
    static let onePasswordIdentifier = "com.1password.1password"

    /// 1Password 的 SSH 签名程序；没装 1Password 时为 nil。
    static var onePasswordSigner: String? {
        let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: onePasswordIdentifier)
        let path = application?.appending(path: "Contents/MacOS/op-ssh-sign").path

        return path.flatMap { FileManager.default.isExecutableFile(atPath: $0) ? $0 : nil }
    }

    /// `~/.ssh/allowed_signers`；不存在时为 nil。
    static var defaultAllowedSigners: String? {
        #warning(
            "TODO: allowed signers 文件菜单列出的候选是推断：只列 ~/.ssh/allowed_signers。核实方式：在 ~/.ssh 下放几个不同名的 allowed signers 文件，对照 Git Config 页的菜单；只影响菜单里多列出哪些文件。"
        )

        let path = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".ssh/allowed_signers").path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    /// allowed signers 文件菜单列出的本机文件：找到的 `~/.ssh/allowed_signers` 在前，配置里的其它文件在后，按展开 `~` 后的路径去重。
    ///
    /// - Parameter configured: 配置里的 allowed signers 文件。
    static func allowedSignersFiles(configured: String?) -> [String] {
        [defaultAllowedSigners, configured].compactMap(\.self).reduce(into: [String]()) { result, path in
            let known = result.contains { HomePath.expanded($0) == HomePath.expanded(path) }

            if !known {
                result.append(path)
            }
        }
    }

    /// 本机找到的 gpg：查找目录里可执行的 gpg 与 gpg2，按解析符号链接后的真实路径去重。
    ///
    /// - Parameter searchPaths: 依次查找的目录。
    static func gpgPrograms(searchPaths: [String] = SigningKeys.searchPaths) -> [String] {
        var resolved: Set<String> = []

        return searchPaths
            .flatMap { directory in
                ["gpg", "gpg2"].map { URL(fileURLWithPath: directory).appending(path: $0).path }
            }
            .filter { path in
                guard FileManager.default.isExecutableFile(atPath: path) else {
                    return false
                }

                return resolved.insert(URL(fileURLWithPath: path).resolvingSymlinksInPath().path).inserted
            }
    }

    /// 在当前窗口上以 sheet 打开文件选择面板，只能选文件。
    ///
    /// - Parameter choose: 选好后以文件路径回调。
    @MainActor
    static func chooseFile(_ choose: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else {
                return
            }

            choose(url.path)
        }

        guard let window = NSApp.keyWindow else {
            finish(panel.runModal())
            return
        }

        panel.beginSheetModal(for: window, completionHandler: finish)
    }
}
