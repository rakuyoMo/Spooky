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

    /// 检出说明写出源分支，来自 Fork 时写成 `作者:分支`；分支名不合法时带原因、不能检出；同名的本地分支指向别的提交时只提醒。
    @Test("检出时校验分支名")
    func checkoutValidation() async throws {
        #expect(PullRequestTextDialog.checkoutSource(of: Self.request(branch: "main")) == "main")
        #expect(PullRequestTextDialog.checkoutSource(of: Self.request(branch: "main", fork: true)) == "me:main")

        let fixture = try await HistoryListTests.makeSession(commits: ["first"])
        defer { fixture.close() }

        let head = try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")
        let session = fixture.session

        // 检出源分支提交为 sha 的请求，本地分支名填 name
        func problem(_ name: String, sha: String) async -> PullRequestTextDialog.BranchNameProblem? {
            await PullRequestTextDialog.branchNameProblem(name, for: Self.request(branch: name, sha: sha), in: session)
        }

        let invalid = AppLocalization.text("reference.invalidName", "bad..name")
        #expect(await problem("bad..name", sha: head) == .invalid(invalid))

        // 同名的本地分支 main 指向别的提交时提醒；就在源分支提交上、源分支提交未知或没有同名分支时没有问题
        #expect(await problem("main", sha: String(repeating: "0", count: 40)) == .taken)
        #expect(await problem("main", sha: head.uppercased()) == nil)
        #expect(await problem("main", sha: "") == nil)
        #expect(await problem("feature", sha: head) == nil)
        #expect(await problem("", sha: head) == nil)
    }

    /// 同一项目的请求预填源分支名；来自 Fork 的预填 `pullrequests/<作者>/<源分支>`，不与本地同名分支撞上。
    @Test("检出预填的分支名")
    func checkoutBranchName() {
        #expect(PullRequestTextDialog.checkoutBranchName(for: Self.request(branch: "fix/login")) == "fix/login")
        #expect(
            PullRequestTextDialog.checkoutBranchName(for: Self.request(branch: "main", fork: true))
                == "pullrequests/me/main"
        )
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

    /// `me` 发起的请求；来自 Fork 时源分支在另一个项目里。
    private static func request(branch: String = "feature", sha: String = "", fork: Bool = false) -> PullRequest {
        PullRequest(
            id: PullRequestID(instance: .gitlabCom, project: "group/project", number: 4),
            title: "t",
            body: "描述",
            state: .open,
            isDraft: false,
            author: HostingUser(username: "me", name: nil),
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            source: PullRequestBranch(project: fork ? "me/project" : "group/project", branch: branch, sha: sha),
            target: PullRequestBranch(project: "group/project", branch: "main", sha: "")
        )
    }

    /// 把对话框放进按内容定尺寸的宿主，排好版后返回。
    private static func host(_ kind: PullRequestTextDialog.Kind) -> NSHostingView<PullRequestTextDialog> {
        let dialog = PullRequestTextDialog(session: RepositorySession(), request: request(), kind: kind, close: { })

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
