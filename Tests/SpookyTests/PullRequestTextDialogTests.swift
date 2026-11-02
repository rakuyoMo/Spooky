import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - PullRequestTextDialogTests

/// 请求的文字对话框用 480 宽的对话框骨架：评论与描述的文字区占满宽度、没有标签列，检出的分支名从对齐线开始，删除评论没有内容区。
@MainActor
struct PullRequestTextDialogTests {
    /// 发表、修改、回复评论与修改描述：文字区距左右各 20，宽 440、高 300。
    @Test("评论与描述的文字区占满对话框的宽度")
    func editors() throws {
        let kinds: [PullRequestTextDialog.Kind] = [
            .comment,
            .editComment(Self.comment),
            .reply(Self.comment),
            .editDescription,
        ]

        for kind in kinds {
            let hosting = Self.host(kind)
            #expect(hosting.frame.width == 480)

            let scroll = try #require(Self.subviews(NSTextView.self, in: hosting).first?.enclosingScrollView)
            let frame = scroll.convert(scroll.bounds, to: hosting)

            #expect(abs(frame.minX - 20) <= 1, "\(kind)")
            #expect(abs(frame.width - 440) <= 1, "\(kind)")
            #expect(abs(frame.height - 300) <= 1, "\(kind)")
        }
    }

    /// 检出的分支名框从 120 的对齐线开始；删除评论没有任何输入。
    @Test("检出与删除评论的内容区")
    func checkoutAndDelete() throws {
        let checkout = Self.host(.checkout)
        #expect(checkout.frame.width == 480)

        let field = try #require(Self.subviews(NSTextField.self, in: checkout).first { $0.isEditable })
        let frame = field.convert(field.bounds, to: checkout)
        #expect(abs(frame.minX - DialogMetrics.alignment) <= 1)

        let delete = Self.host(.deleteComment(Self.comment))
        #expect(delete.frame.width == 480)
        #expect(Self.subviews(NSTextView.self, in: delete).isEmpty)
        #expect(Self.subviews(NSTextField.self, in: delete).allSatisfy { !$0.isEditable })
    }
}

// MARK: - Helpers

extension PullRequestTextDialogTests {
    /// 修改、回复与删除用的评论。
    private static let comment = PullRequestComment(
        id: 1,
        author: HostingUser(username: "me", name: nil),
        body: "看过了",
        createdAt: Date(timeIntervalSince1970: 0)
    )

    /// 把对话框放进按内容定尺寸的宿主，排好版后返回。
    private static func host(_ kind: PullRequestTextDialog.Kind) -> NSHostingView<PullRequestTextDialog> {
        let request = PullRequest(
            id: PullRequestID(instance: .gitlabCom, project: "group/project", number: 4),
            title: "t",
            body: "描述",
            state: .open,
            isDraft: false,
            author: HostingUser(username: "me", name: nil),
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            source: PullRequestBranch(project: "group/project", branch: "feature", sha: ""),
            target: PullRequestBranch(project: "group/project", branch: "main", sha: "")
        )

        let dialog = PullRequestTextDialog(
            session: RepositorySession(),
            request: request,
            kind: kind,
            close: { }
        )

        let hosting = NSHostingView(rootView: dialog)
        hosting.frame.size = hosting.fittingSize
        hosting.layoutSubtreeIfNeeded()
        return hosting
    }

    /// 根视图下所有这一类的子视图。
    private static func subviews<Element: NSView>(_: Element.Type, in root: NSView) -> [Element] {
        root.subviews.flatMap { child in
            [child as? Element].compactMap(\.self) + subviews(Element.self, in: child)
        }
    }
}
