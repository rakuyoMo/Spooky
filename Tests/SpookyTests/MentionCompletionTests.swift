import AppKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - MentionCompletionTests

/// 评论里的 `@` 只在能成为提及的位置触发补全，候选先列请求的参与者、再列项目成员；选中的候选替换正在输入的提及。
@MainActor
struct MentionCompletionTests {
    /// `@` 在词首或标点之后才触发，邮箱地址里的不触发；替换范围从 `@` 到光标，按 UTF-16 计算。
    @Test("识别光标处的提及")
    func detectsMentions() {
        #expect(
            MentionCompletion.detect(in: "@al", caret: 3)
                == MentionCompletion.Trigger(query: "al", range: NSRange(location: 0, length: 3))
        )

        #expect(
            MentionCompletion.detect(in: "谢谢 😀 @", caret: 7)
                == MentionCompletion.Trigger(query: "", range: NSRange(location: 6, length: 1))
        )

        // 括号之后也是提及，光标在词中间时查询只到光标
        #expect(
            MentionCompletion.detect(in: "(@alex)", caret: 4)
                == MentionCompletion.Trigger(query: "al", range: NSRange(location: 1, length: 3))
        )

        // 邮箱地址、下划线之后、`@` 后隔了空白与越界的光标都不触发
        #expect(MentionCompletion.detect(in: "me@example", caret: 10) == nil)
        #expect(MentionCompletion.detect(in: "a_@b", caret: 4) == nil)
        #expect(MentionCompletion.detect(in: "@alex 你好", caret: 8) == nil)
        #expect(MentionCompletion.detect(in: "@", caret: 2) == nil)
    }

    /// 参与者排在成员前面，同一个用户只列一次，已删除的用户与机器人不列；
    /// 按用户名或显示名筛选，不区分大小写，插入 `@用户名` 与一个空格。
    @Test("排出候选并按查询筛选")
    func listsCandidates() {
        let date = Date(timeIntervalSince1970: 0)
        let author = HostingUser(username: "alex", name: nil)

        let request = PullRequest(
            id: PullRequestID(instance: .github, project: "o/r", number: 4),
            title: "t",
            body: "",
            state: .open,
            isDraft: false,
            author: author,
            createdAt: date,
            updatedAt: date,
            source: PullRequestBranch(project: "o/r", branch: "feature", sha: ""),
            target: PullRequestBranch(project: "o/r", branch: "main", sha: "")
        )

        let comments = ["sam", "", "ci[bot]", "Alex"].enumerated().map {
            PullRequestComment(id: $0, author: HostingUser(username: $1, name: nil), body: "", createdAt: date)
        }

        let members = [
            HostingUser(username: "SAM", name: "Sam 王"),
            HostingUser(username: "lee", name: "Samuel Lee"),
            HostingUser(username: "kim", name: nil),
        ]

        let users = MentionCompletion.candidates(for: request, comments: comments, members: members)

        #expect(users.map(\.username) == ["alex", "sam", "lee", "kim"])

        // 筛选
        #expect(MentionCompletion.matches("", in: users).map(\.insertion) == ["@alex ", "@sam ", "@lee ", "@kim "])
        #expect(MentionCompletion.matches("SAM", in: users).map(\.insertion) == ["@sam ", "@lee "])
        #expect(MentionCompletion.matches("zz", in: users).isEmpty)
    }

    /// 输入 `@` 与查询后弹出候选，回车把正在输入的提及换成选中的用户名并写回绑定。
    @Test("评论框里输入 @ 后选中候选")
    func completesInEditor() async throws {
        final class Draft {
            var text = ""
        }

        let draft = Draft()
        let users = [HostingUser(username: "alex", name: nil), HostingUser(username: "sam", name: nil)]

        let editor = PullRequestCommentEditor(
            text: Binding { draft.text } set: { draft.text = $0 },
            label: "Comment",
            completions: { MentionCompletion.matches($0, in: users) }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false

        let host = NSHostingView(rootView: editor)
        window.contentView = host
        host.layoutSubtreeIfNeeded()

        // 候选弹窗是子窗口，父窗口显示着它才显示
        window.orderFront(nil)
        defer { window.close() }

        let textView = try #require(SettingsWindowTests.subviews(NSTextView.self, in: host).first)
        let coordinator = try #require(textView.delegate as? PullRequestCommentEditor.Coordinator)

        // 弹出候选后回车选中第一个
        textView.insertText("谢谢 @s", replacementRange: NSRange(location: 0, length: 0))
        await until { coordinator.panel.isVisible }

        #expect(coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        #expect(draft.text == "谢谢 @sam ")
        #expect(!coordinator.panel.isVisible)
    }
}
