import Foundation
import SpookyKit

// MARK: - FileUnavailableReason

/// 文件不能以文本显示或追溯的原因，界面按视图给出对应的说明。
enum FileUnavailableReason: Equatable {
    /// 版本中没有这个文件：新增、未跟踪，或仓库还没有提交。
    case missing

    /// 内容含有 NUL 字节，按二进制文件处理。
    case binary

    /// 条目是子模块，没有文件内容。
    case submodule
}

// MARK: - FileRevisionContent

/// 某个版本中一个文件的原文，内容取自仓库所在机器上的 Git 输出。
struct FileRevisionContent: Equatable {
    /// 与 Git 判断二进制文件相同，只检查开头这些字节里有没有 NUL。
    private static let binaryProbeLength = 8000

    /// 文本排版会当成换行、而 Git 不算作换行的字符。
    private static let lineBreaks: Set<Unicode.Scalar> = ["\r", "\u{85}", "\u{2028}", "\u{2029}"]

    /// 树中存储的路径；版本中没有这个文件时是请求的路径。
    let path: String

    /// 文件的原始字节；版本中没有这个文件或是子模块时为 nil。
    let data: Data?

    /// 不能以文本显示的原因，nil 表示可以显示。
    let unavailable: FileUnavailableReason?

    /// 用于显示的各行，按换行符切分。
    let lines: [String]

    /// 按 Unicode 等价找到版本中的条目后读取内容，并判断能否以文本显示。
    static func load(_ path: String, at revision: String, views: RepositoryFileViews) async throws -> Self {
        guard let entry = try await views.storedEntry(for: path, in: revision) else {
            return Self(path: path, data: nil, unavailable: .missing, lines: [])
        }

        guard !entry.isSubmodule else {
            return Self(path: entry.path, data: nil, unavailable: .submodule, lines: [])
        }

        let data = try await views.contents(of: entry)

        // 二进制文件仍保留内容，可以导出或交给默认程序
        guard !data.prefix(binaryProbeLength).contains(0) else {
            return Self(path: entry.path, data: data, unavailable: .binary, lines: [])
        }

        return Self(path: entry.path, data: data, unavailable: nil, lines: displayLines(data))
    }

    /// 按换行字节切分内容；最后的换行不产生空行。
    static func displayLines(_ data: Data) -> [String] {
        guard !data.isEmpty else {
            return []
        }

        var records = data.split(separator: 10, omittingEmptySubsequences: false)

        if data.last == 10 {
            records.removeLast()
        }

        return records.map { displayLine(String(decoding: $0, as: UTF8.self)) }
    }

    /// 一行的显示形式：去掉行尾的回车，行内其它会被文本排版当成换行的字符换成替代符，行号才能与 Git 的行一一对应。
    static func displayLine(_ line: String) -> String {
        // 绝大多数行没有这些字符，原样返回
        guard line.unicodeScalars.contains(where: lineBreaks.contains) else {
            return line
        }

        var scalars = Array(line.unicodeScalars)

        if scalars.last == "\r" {
            scalars.removeLast()
        }

        return String(String.UnicodeScalarView(scalars.map { lineBreaks.contains($0) ? "\u{FFFD}" : $0 }))
    }
}
