import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - PullRequestDialogsTests

/// 合并请求与关联远端用 480 宽的对话框骨架：合并的标题与说明写出服务与编号，GitHub 预选上次用的合并方式；
/// 关联远端的输入从对齐线开始。
@MainActor
struct PullRequestDialogsTests {
    /// 读取选项时内容区是转圈，对话框仍是 480 宽。
    @Test("合并对话框的宽度")
    func mergeWidth() {
        let dialog = MergePullRequestDialog(
            session: RepositorySession(),
            request: Self.request(on: .github),
            close: { }
        )

        let hosting = NSHostingView(rootView: dialog)
        hosting.frame.size = hosting.fittingSize
        hosting.layoutSubtreeIfNeeded()

        #expect(hosting.frame.width == 480)
    }

    /// GitHub 与 GitLab：标题写出服务名，说明写出编号，主按钮按服务叫 Merge Pull Request 或 Merge Merge Request。
    @Test("合并对话框的标题、说明与主按钮")
    func mergeTexts() async throws {
        let github = MergePullRequestDialog.texts(for: Self.request(on: .github), in: RepositorySession())

        #expect(github.title == AppLocalization.text("pr.accept.title", "GitHub"))
        #expect(github.message == AppLocalization.text("pr.accept.message", "#4"))
        #expect(github.submit == AppLocalization.text("pr.accept.submit"))

        // 远端对应私有部署 GitLab 的账号时改叫 Merge Request，服务名写 GitLab Self-Managed
        let fixture = try await PullRequestCommentRulesTests.Fixture.make()
        defer { fixture.close() }

        let service = AppLocalization.text("accounts.kind.gitlabSelfManaged")
        let request = try PullRequestCommentRulesTests.request(author: "bob")
        let gitlab = MergePullRequestDialog.texts(for: request, in: fixture.session)

        #expect(gitlab.title == AppLocalization.text("mr.accept.title", service))
        #expect(gitlab.message == AppLocalization.text("mr.accept.message", "!4"))
        #expect(gitlab.submit == AppLocalization.text("mr.accept.submit"))
    }

    /// 仓库允许上次用的方式时预选它；不允许、没有记录或记录认不出时选仓库允许的第一种。
    @Test("预选上次用的合并方式")
    func preselectedMethod() throws {
        let suite = "spooky-merge-method-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let all: [PullRequestMergeMethod] = [.merge, .rebase, .squash]
        #expect(MergePullRequestDialog.preselectedMethod(in: all, defaults: defaults) == .merge)

        defaults.set("squash", forKey: MergePullRequestDialog.methodKey)
        #expect(MergePullRequestDialog.preselectedMethod(in: all, defaults: defaults) == .squash)
        #expect(MergePullRequestDialog.preselectedMethod(in: [.rebase, .merge], defaults: defaults) == .rebase)

        defaults.set("octopus", forKey: MergePullRequestDialog.methodKey)
        #expect(MergePullRequestDialog.preselectedMethod(in: [.squash], defaults: defaults) == .squash)
    }

    /// 关联远端：480 宽，项目路径的输入框从 120 的对齐线开始、占满输入列。
    @Test("关联远端的对话框")
    func associateLayout() throws {
        let dialog = AssociateRemoteDialog(
            session: RepositorySession(),
            remote: "origin",
            url: "git@example.com:group/project.git",
            close: { }
        )

        let hosting = NSHostingView(rootView: dialog)
        hosting.frame.size = hosting.fittingSize
        hosting.layoutSubtreeIfNeeded()
        #expect(hosting.frame.width == 480)

        let field = try #require(Self.subviews(NSTextField.self, in: hosting).first { $0.isEditable })
        let frame = field.convert(field.bounds, to: hosting)
        #expect(abs(frame.minX - DialogMetrics.alignment) <= 1)
        #expect(abs(frame.maxX - 460) <= 1)
    }
}

// MARK: - Helpers

extension PullRequestDialogsTests {
    /// 实例上 `group/project` 的请求 `4`，从 `feature` 合进 `main`。
    private static func request(on instance: HostingInstance) -> PullRequest {
        PullRequest(
            id: PullRequestID(instance: instance, project: "group/project", number: 4),
            title: "t",
            body: "",
            state: .open,
            isDraft: false,
            author: HostingUser(username: "me", name: nil),
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            source: PullRequestBranch(project: "group/project", branch: "feature", sha: ""),
            target: PullRequestBranch(project: "group/project", branch: "main", sha: "")
        )
    }

    /// 根视图下所有这一类的子视图。
    private static func subviews<Element: NSView>(_: Element.Type, in root: NSView) -> [Element] {
        root.subviews.flatMap { child in
            [child as? Element].compactMap(\.self) + subviews(Element.self, in: child)
        }
    }
}
