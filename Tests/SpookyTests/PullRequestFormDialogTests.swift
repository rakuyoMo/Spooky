import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - PullRequestFormDialogTests

/// 新建与修改请求用 480 宽的对话框骨架：输入列从对齐线开始、宽 320，标题与说明写出服务名与目标项目；
/// 两侧是同一个分支时不能提交，错误区写出原因。
@MainActor
struct PullRequestFormDialogTests {
    /// Title 与 Description 从对齐线开始，宽 320；Description 高 64。
    ///
    /// Source 与 Target 两行的下拉由 SwiftUI 自己绘制，不在 AppKit 的视图树里，只在 App 里核对。
    @Test("新建与修改对话框的表单宽度")
    func layout() throws {
        for request in [nil, Self.request()] {
            let hosting = Self.host(request)

            #expect(hosting.frame.width == 480)

            let title = try #require(Self.subviews(NSTextField.self, in: hosting).first { $0.isEditable })
            let titleFrame = title.convert(title.bounds, to: hosting)

            #expect(abs(titleFrame.minX - DialogMetrics.alignment) <= 1)
            #expect(abs(titleFrame.width - 320) <= 1)

            let scroll = try #require(Self.subviews(NSTextView.self, in: hosting).first?.enclosingScrollView)
            let descriptionFrame = scroll.convert(scroll.bounds, to: hosting)

            #expect(abs(descriptionFrame.minX - DialogMetrics.alignment) <= 1)
            #expect(abs(descriptionFrame.width - 320) <= 1)
            #expect(abs(descriptionFrame.height - 64) <= 1)
        }
    }

    /// GitHub 与 GitLab 的新建、修改：标题写服务名（修改还有编号），说明写服务名与目标项目，主按钮按用途。
    @Test("标题、说明与主按钮按用途与服务")
    func texts() async throws {
        let github = PullRequestFormDialog.texts(
            editing: nil,
            instance: .github,
            project: "o/r",
            in: RepositorySession()
        )

        #expect(github.title == AppLocalization.text("pr.create.title", "GitHub"))
        #expect(github.message == AppLocalization.text("pr.create.message", "GitHub", "o/r"))
        #expect(github.submit == AppLocalization.text("pr.create.submit"))

        let edited = PullRequestFormDialog.texts(
            editing: Self.request(),
            instance: .github,
            project: "o/r",
            in: RepositorySession()
        )

        #expect(edited.title == AppLocalization.text("pr.edit.title", "GitHub", "!4"))
        #expect(edited.message == AppLocalization.text("pr.edit.message", "!4", "GitHub", "o/r"))
        #expect(edited.submit == AppLocalization.text("pr.edit.submit"))

        // 远端对应私有部署 GitLab 的账号时改叫 Merge Request，服务名写 GitLab Self-Managed
        let fixture = try await PullRequestCommentRulesTests.Fixture.make()
        defer { fixture.close() }

        let request = try PullRequestCommentRulesTests.request(author: "me")
        let service = AppLocalization.text("accounts.kind.gitlabSelfManaged")

        let gitlab = PullRequestFormDialog.texts(
            editing: request,
            instance: request.id.instance,
            project: "group/project",
            in: fixture.session
        )

        #expect(gitlab.title == AppLocalization.text("mr.edit.title", service, "!4"))
        #expect(gitlab.message == AppLocalization.text("mr.edit.message", "!4", service, "group/project"))
        #expect(gitlab.submit == AppLocalization.text("mr.edit.submit"))

        let created = PullRequestFormDialog.texts(
            editing: nil,
            instance: request.id.instance,
            project: "group/project",
            in: fixture.session
        )

        #expect(created.title == AppLocalization.text("mr.create.title", service))
        #expect(created.submit == AppLocalization.text("mr.create.submit"))
    }

    /// 新建时同一远端的同名分支相同；修改时同一项目的请求把目标分支选成源分支也相同，来自 Fork 的不算。
    @Test("两侧分支相同")
    func identicalBranches() {
        #expect(PullRequestFormDialog.isIdentical(source: ("origin", "main"), target: ("origin", "main"), editing: nil))
        #expect(!PullRequestFormDialog.isIdentical(source: ("fork", "main"), target: ("origin", "main"), editing: nil))
        #expect(!PullRequestFormDialog.isIdentical(source: ("origin", "dev"), target: ("origin", "main"), editing: nil))
        #expect(!PullRequestFormDialog.isIdentical(source: ("origin", ""), target: ("origin", ""), editing: nil))

        let request = Self.request()
        let fork = Self.request(fork: true)

        #expect(PullRequestFormDialog.isIdentical(source: ("", ""), target: ("origin", "feature"), editing: request))
        #expect(!PullRequestFormDialog.isIdentical(source: ("", ""), target: ("origin", "main"), editing: request))
        #expect(!PullRequestFormDialog.isIdentical(source: ("", ""), target: ("origin", "feature"), editing: fork))
    }
}

// MARK: - Helpers

extension PullRequestFormDialogTests {
    /// GitLab.com 上 `group/project` 的请求 `!4`，从 `feature` 合进 `main`；来自 Fork 时源分支在 `me/project`。
    private static func request(fork: Bool = false) -> PullRequest {
        PullRequest(
            id: PullRequestID(instance: .gitlabCom, project: "group/project", number: 4),
            title: "t",
            body: "",
            state: .open,
            isDraft: false,
            author: HostingUser(username: "me", name: nil),
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            source: PullRequestBranch(project: fork ? "me/project" : "group/project", branch: "feature", sha: ""),
            target: PullRequestBranch(project: "group/project", branch: "main", sha: "")
        )
    }

    /// 把新建或修改的对话框放进按内容定尺寸的宿主，排好版后返回。
    private static func host(_ request: PullRequest?) -> NSHostingView<PullRequestFormDialog> {
        let dialog = PullRequestFormDialog(session: RepositorySession(), request: request, close: { })

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
