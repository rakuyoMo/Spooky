import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 补全只在光标处的词以触发前缀开头时出现，替换范围按文本视图使用的 UTF-16 计算。
struct CommitCompletionTests {
    /// `c:` 与 `\` 只在词首生效，中文与表情符号之后的位置按 UTF-16 计算。
    @Test("识别提交与文件补全")
    func detectsTokens() {
        #expect(CompletionTrigger.detect(in: "c:ab", caret: 4, subject: false) == .commit(
            query: "ab",
            range: NSRange(location: 0, length: 4)
        ))
        #expect(CompletionTrigger.detect(in: "修复 c:", caret: 5, subject: true) == .commit(
            query: "",
            range: NSRange(location: 3, length: 2)
        ))
        #expect(CompletionTrigger.detect(in: "见 😀 \\src/文件", caret: 12, subject: false) == .file(
            query: "src/文件",
            range: NSRange(location: 5, length: 7)
        ))

        // 词中间的前缀、Windows 盘符与越界的光标都不触发
        #expect(CompletionTrigger.detect(in: "abc:def", caret: 7, subject: false) == nil)
        #expect(CompletionTrigger.detect(in: "C:\\dir", caret: 6, subject: false) == nil)
        #expect(CompletionTrigger.detect(in: "c:", caret: 3, subject: false) == nil)
    }

    /// fixup / squash 前缀只在标题里生效，选中后替换前缀之后的整行。
    @Test("识别 fixup 与 squash 前缀")
    func detectsFixup() {
        #expect(CompletionTrigger.detect(in: "fixup! 登录 bug", caret: 9, subject: true) == .fixup(
            query: "登录",
            range: NSRange(location: 7, length: 6)
        ))
        #expect(CompletionTrigger.detect(in: "squash! ", caret: 8, subject: true) == .fixup(
            query: "",
            range: NSRange(location: 8, length: 0)
        ))
        #expect(CompletionTrigger.detect(in: "fixup! x", caret: 8, subject: false) == nil)
    }

    /// 提交按哈希前缀、标题或作者筛选，插入短哈希或标题；文件按路径筛选；插入的文字是 NFC。
    @Test("筛选候选并生成插入文字")
    func matchesCandidates() {
        let commit = HistoryCommit(
            id: "0123456789abcdef0123456789abcdef01234567",
            tree: "",
            parents: [],
            author: "Spooky Test",
            authorEmail: "spooky@example.invalid",
            authorDate: Date(timeIntervalSince1970: 0),
            committer: "Spooky Test",
            committerEmail: "spooky@example.invalid",
            commitDate: Date(timeIntervalSince1970: 0),
            message: "修复 cafe\u{301}\n\n正文"
        )
        let range = NSRange(location: 0, length: 0)

        let byHash = CommitCompletion.matches(for: .commit(query: "0123", range: range), commits: [commit], paths: [])
        #expect(byHash.map(\.insertion) == ["01234567"])
        #expect(CommitCompletion.matches(for: .commit(query: "zz", range: range), commits: [commit], paths: []).isEmpty)

        let fixup = CommitCompletion.matches(for: .fixup(query: "CAFÉ", range: range), commits: [commit], paths: [])
        #expect(fixup.map(\.insertion) == ["修复 café"])

        let files = CommitCompletion.matches(
            for: .file(query: "cafe\u{301}", range: range),
            commits: [],
            paths: ["docs/cafe\u{301}.md", "other.txt"]
        )
        #expect(files.map(\.insertion) == ["docs/café.md"])
    }
}
