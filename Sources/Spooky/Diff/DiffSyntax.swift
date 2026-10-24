import Foundation
import SpookyKit

// MARK: - DiffSyntax

/// 一个文件 Diff 两侧全文的语法片段，按行号取用：删除行取旧版，上下文与新增行取新版。
///
/// 块注释、多行字符串跨越 Diff 的块边界，所以着色基于两侧全文，而不是只看显示出的几行。
struct DiffSyntax: Sendable {
    /// 旧版每行的片段，下标为行号减一。
    let old: [[SyntaxSpan]]

    /// 新版每行的片段。
    let new: [[SyntaxSpan]]

    /// 显示的 Diff 能否着色：按路径识别出语言，或新版首行是 `#!`（需要全文再判断）。
    static func mayColor(_ diff: RepositoryDiff, oldPath: String, newPath: String) async -> Bool {
        guard let file = diff.files.first, !file.isBinary else {
            return false
        }

        if await SyntaxHighlighter.language(forPath: newPath, content: nil) != nil {
            return true
        }

        if await SyntaxHighlighter.language(forPath: oldPath, content: nil) != nil {
            return true
        }

        let firstLine = file.hunks.first?.lines.first { $0.newNumber == 1 && $0.prefix != 45 }
        return firstLine?.content.starts(with: "#!".utf8) ?? false
    }

    /// 显示的 Diff 已经包含两侧全文：显示整个文件，或整份文件新增、删除。
    static func isEntireFile(_ diff: RepositoryDiff, options: DiffOptions) -> Bool {
        guard let file = diff.files.first, diff.files.count == 1 else {
            return false
        }

        return (options.showsEntireFile && !options.ignoresWhitespace)
            || file.addedMode != nil
            || file.deletedMode != nil
    }

    /// 从整文件上下文的 Diff 重建两侧全文再着色，两侧按各自的路径识别语言。
    ///
    /// 全文重建在后台执行，着色在语法着色的串行队列上排队。
    ///
    /// - Returns: 两侧都识别不了语言时为空，调用方按纯文本显示。
    @concurrent
    static func make(from full: RepositoryDiff, oldPath: String, newPath: String) async -> Self? {
        guard let file = full.files.first, !file.isBinary else {
            return nil
        }

        var oldLines: [Int: String] = [:]
        var newLines: [Int: String] = [:]

        // 删除行只属于旧版，新增行只属于新版，上下文两侧都有
        for line in file.hunks.flatMap(\.lines) {
            let text = String(decoding: line.content, as: UTF8.self)

            if line.prefix != 43, let number = line.oldNumber {
                oldLines[number] = text
            }

            if line.prefix != 45, let number = line.newNumber {
                newLines[number] = text
            }
        }

        let oldText = joined(oldLines)
        let newText = joined(newLines)
        let oldLanguage = await SyntaxHighlighter.language(forPath: oldPath, content: oldText)
        let newLanguage = await SyntaxHighlighter.language(forPath: newPath, content: newText)

        guard oldLanguage != nil || newLanguage != nil else {
            return nil
        }

        var old: [[SyntaxSpan]] = []
        var new: [[SyntaxSpan]] = []

        if let oldLanguage {
            old = await SyntaxHighlighter.highlight(oldText, as: oldLanguage)
        }

        if let newLanguage {
            new = await SyntaxHighlighter.highlight(newText, as: newLanguage)
        }

        return Self(old: old, new: new)
    }

    /// 按行号拼回全文，缺失的行留空，行号与原文保持一致。
    private static func joined(_ lines: [Int: String]) -> String {
        guard let last = lines.keys.max(), last > 0 else {
            return ""
        }

        return (1 ... last)
            .map { lines[$0] ?? "" }
            .joined(separator: "\n")
    }

    /// 一行 Diff 的片段；行号超出全文时没有片段。
    func spans(for line: DiffLine) -> [SyntaxSpan]? {
        let (lines, number) = line.prefix == 45 ? (old, line.oldNumber) : (new, line.newNumber)

        guard let number, lines.indices.contains(number - 1) else {
            return nil
        }

        return lines[number - 1]
    }
}
