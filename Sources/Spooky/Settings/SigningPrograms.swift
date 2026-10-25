import AppKit
import SpookyKit

// MARK: - SigningPrograms

/// Git Config 页签名组里可选的程序与文件：本机的 gpg、SSH 签名程序与 allowed signers 文件。
enum SigningPrograms {
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
}
