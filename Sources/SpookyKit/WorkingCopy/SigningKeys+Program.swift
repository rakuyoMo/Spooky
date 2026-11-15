import Foundation

// MARK: - Program

extension SigningKeys {
    /// 本机程序作为 GnuPG 的版本：能执行，且 `--version` 输出的第一行是 GnuPG 的版本行。
    ///
    /// - Parameter program: 程序的绝对路径。
    /// - Returns: 程序的版本；不能执行或不是 GnuPG 时为 nil。
    public static func gnuPGVersion(_ program: String) async -> GnuPGVersion? {
        guard FileManager.default.isExecutableFile(atPath: program) else {
            return nil
        }

        let result = try? await CommandExecutor.execute(
            executable: program,
            processArguments: ["--version"],
            arguments: ["gpg", "--version"]
        )

        return result.flatMap { GnuPGVersion(output: $0.standardOutput) }
    }
}

// MARK: - GnuPGVersion

/// GnuPG 的版本号，用来判断签名程序是否满足最低版本。
public struct GnuPGVersion: Sendable, Equatable, Comparable, CustomStringConvertible {
    /// 签名所需的最低 GnuPG 版本。
    public static let minimum = Self(major: 2, minor: 1, patch: 0)

    /// 主版本号。
    public let major: Int

    /// 次版本号。
    public let minor: Int

    /// 修订号；版本行里没有时为 0。
    public let patch: Int

    /// 写成 “主.次.修订”。
    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    /// 从 `gpg --version` 的第一行解析版本，如 “gpg (GnuPG) 2.4.5” “gpg (GnuPG/MacGPG2) 2.2.41”。
    ///
    /// - Parameter output: 命令的标准输出。
    public init?(output: Data) {
        let firstLine = String(decoding: output, as: UTF8.self)
            .split(separator: "\n")
            .first
            .map(String.init) ?? ""

        // 括号里以 GnuPG 开头，括号后是版本号；修订号可以没有
        let pattern = /\(GnuPG[^)]*\) ([0-9]+)\.([0-9]+)(?:\.([0-9]+))?/

        guard
            let match = firstLine.firstMatch(of: pattern),
            let major = Int(match.1),
            let minor = Int(match.2)
        else {
            return nil
        }

        self.init(major: major, minor: minor, patch: match.3.flatMap { Int($0) } ?? 0)
    }

    /// 用已验证的数值创建版本。
    private init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// 按数值比较版本，避免把 2.10 当作低于 2.9。
    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
