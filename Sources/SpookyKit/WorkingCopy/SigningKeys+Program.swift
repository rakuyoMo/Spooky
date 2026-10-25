import Foundation

// MARK: - Program

extension SigningKeys {
    /// 判断本机的程序是不是 GnuPG：能执行，且 `--version` 输出的第一行带 “GnuPG”。
    ///
    /// - Parameter program: 程序的绝对路径。
    public static func isGnuPG(_ program: String) async -> Bool {
        guard FileManager.default.isExecutableFile(atPath: program) else {
            return false
        }

        let result = try? await CommandExecutor.execute(
            executable: program,
            processArguments: ["--version"],
            arguments: ["gpg", "--version"]
        )

        let firstLine = result
            .map { String(decoding: $0.standardOutput, as: UTF8.self) }?
            .split(separator: "\n")
            .first

        return firstLine?.contains("GnuPG") ?? false
    }
}
