import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 补全只在光标处的词以触发前缀开头时出现，替换范围按文本视图使用的 UTF-16 计算。
struct CommitCompletionTests {
    /// `c:` 与 `\` 只在词首生效，fixup / squash 前缀只在标题里生效，`#` 只在打开 Issue 补全时生效；
    /// 中文与表情符号之后的位置按 UTF-16 计算。
    @Test("识别提交、文件、fixup 与 Issue 补全")
    func detectsTriggers() {
        #expect(
            CompletionTrigger.detect(in: "c:ab", caret: 4, subject: false)
                == .commit(query: "ab", range: NSRange(location: 0, length: 4))
        )

        #expect(
            CompletionTrigger.detect(in: "修复 c:", caret: 5, subject: true)
                == .commit(query: "", range: NSRange(location: 3, length: 2))
        )

        #expect(
            CompletionTrigger.detect(in: "见 😀 \\src/文件", caret: 12, subject: false)
                == .file(query: "src/文件", range: NSRange(location: 5, length: 7))
        )

        // 词中间的前缀、Windows 盘符与越界的光标都不触发
        #expect(CompletionTrigger.detect(in: "abc:def", caret: 7, subject: false) == nil)
        #expect(CompletionTrigger.detect(in: "C:\\dir", caret: 6, subject: false) == nil)
        #expect(CompletionTrigger.detect(in: "c:", caret: 3, subject: false) == nil)

        // 选中 fixup 候选后替换前缀之后的整行
        #expect(
            CompletionTrigger.detect(in: "fixup! 登录 bug", caret: 9, subject: true)
                == .fixup(query: "登录", range: NSRange(location: 7, length: 6))
        )

        #expect(
            CompletionTrigger.detect(in: "squash! ", caret: 8, subject: true)
                == .fixup(query: "", range: NSRange(location: 8, length: 0))
        )

        #expect(CompletionTrigger.detect(in: "fixup! x", caret: 8, subject: false) == nil)

        // Editor 设置页的开关关着时 `#` 不触发
        #expect(CompletionTrigger.detect(in: "修复 #1", caret: 5, subject: true) == nil)
        #expect(
            CompletionTrigger.detect(in: "修复 #1", caret: 5, subject: true, issues: true)
                == .issue(query: "1", range: NSRange(location: 3, length: 2))
        )
    }

    /// 提交按哈希前缀、标题或作者筛选，插入短哈希或标题；文件按路径筛选；
    /// Issue 按编号前缀或标题筛选，插入 `#编号`；插入的文字是 NFC。
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
        let paths = ["docs/cafe\u{301}.md", "other.txt"]
        let issues = [HostingIssue(number: 12, title: "崩溃"), HostingIssue(number: 3, title: "文档")]

        let insertions = { (trigger: CompletionTrigger) in
            CommitCompletion.matches(
                for: trigger,
                commits: [commit],
                paths: paths,
                issues: issues
            )
            .map(\.insertion)
        }

        #expect(insertions(.commit(query: "0123", range: range)) == ["01234567"])
        #expect(insertions(.commit(query: "zz", range: range)).isEmpty)
        #expect(insertions(.fixup(query: "CAFÉ", range: range)) == ["修复 café"])
        #expect(insertions(.file(query: "cafe\u{301}", range: range)) == ["docs/café.md"])
        #expect(insertions(.issue(query: "1", range: range)) == ["#12"])
        #expect(insertions(.issue(query: "文档", range: range)) == ["#3"])
    }
}
