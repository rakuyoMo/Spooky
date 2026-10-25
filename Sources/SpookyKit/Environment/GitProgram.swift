import Foundation

// MARK: - GitProgram

/// 本机的一个 Git 程序及它报告的版本，供 Settings 选择本机仓库使用的 Git。
public struct GitProgram: Sendable, Equatable, Identifiable {
    /// 常见的安装位置：系统 Git、Command Line Tools、Homebrew（Apple 芯片与 Intel）与 MacPorts。
    public static let standardPaths = [
        LocalExecutionSettings.defaultGitExecutable,
        "/Library/Developer/CommandLineTools/usr/bin/git",
        "/opt/homebrew/bin/git",
        "/usr/local/bin/git",
        "/opt/local/bin/git",
    ]

    /// 程序的绝对路径，也是它的身份。
    public let path: String

    /// `git --version` 去掉 `git version ` 前缀的原文，如 `2.50.1 (Apple Git-155)`；程序无法运行或输出不认识时为 nil。
    public let versionText: String?

    /// 解析出的版本号；程序无法运行或输出不认识时为 nil。
    public let version: GitVersion?

    /// 列表以路径作为稳定身份。
    public var id: String { path }

    /// 系统自带的 `/usr/bin/git`。
    public var isSystem: Bool { path == LocalExecutionSettings.defaultGitExecutable }

    /// 版本不低于 Spooky 要求的最低版本。
    public var isSupported: Bool { version.map { $0 >= .minimum } ?? false }

    /// 运行 `git --version` 读出版本；文件不存在或不可执行时不启动它。
    ///
    /// - Parameter path: 程序的绝对路径。
    public static func probe(_ path: String) async -> Self {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            return Self(path: path, versionText: nil, version: nil)
        }

        let result = try? await CommandExecutor.execute(
            executable: path,
            processArguments: ["--version"],
            arguments: ["--version"],
            environment: .inherit.updating(["LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"])
        )

        guard let output = result?.standardOutput, let version = GitVersion(output: output) else {
            return Self(path: path, versionText: nil, version: nil)
        }

        let text = String(decoding: output, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing("git version ", with: "", maxReplacements: 1)

        return Self(path: path, versionText: text, version: version)
    }

    /// 列出可选的 Git：常见位置与附加位置里版本满足要求的程序，按给出的顺序、去掉重复的路径。
    ///
    /// - Parameter additionalPaths: 其它候选，如 Xcode 自带的 Git。
    public static func installed(additionalPaths: [String] = []) async -> [Self] {
        var seen = Set<String>()
        let paths = (standardPaths + additionalPaths).filter { seen.insert($0).inserted }

        return await withTaskGroup(of: (Int, Self).self) { group in
            for (index, path) in paths.enumerated() {
                group.addTask { (index, await probe(path)) }
            }

            var programs: [(Int, Self)] = []

            for await program in group where program.1.isSupported {
                programs.append(program)
            }

            return programs.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}

// MARK: - GitVersion + CustomStringConvertible

extension GitVersion: CustomStringConvertible {
    /// 点分的三段版本号，如 `2.41.0`。
    public var description: String { "\(major).\(minor).\(patch)" }
}
