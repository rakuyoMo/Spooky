import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - PullRequestTextDialogTests

/// 请求的文字对话框：检出写出源分支并预填不撞名的分支名，分支名不合法时不能检出；
/// 关闭请求写出服务名与编号，仓库不可写时仍能关闭。
@MainActor
struct PullRequestTextDialogTests {
    /// 检出说明写出源分支，来自 Fork 时写成 `作者:分支`；同一项目的请求预填源分支名，来自 Fork 的预填
    /// `pullrequests/<作者>/<源分支>`，不与本地同名分支撞上；分支名不合法时带原因、不能检出；同名的本地分支指向别的提交时只提醒。
    @Test("检出的说明、预填的分支名与分支名校验")
    func checkout() async throws {
        let fork = Self.request(branch: "main", fork: true)

        #expect(PullRequestTextDialog.checkoutSource(of: Self.request(branch: "main")) == "main")
        #expect(PullRequestTextDialog.checkoutSource(of: fork) == "me:main")
        #expect(PullRequestTextDialog.checkoutBranchName(for: Self.request(branch: "fix/login")) == "fix/login")
        #expect(PullRequestTextDialog.checkoutBranchName(for: fork) == "pullrequests/me/main")

        // 分支名校验
        let fixture = try await HistoryListTests.makeSession(commits: ["first"])
        defer { fixture.close() }

        let head = try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")
        let session = fixture.session

        /// 检出源分支提交为 sha 的请求，本地分支名填 name。
        func problem(_ name: String, sha: String) async -> PullRequestTextDialog.BranchNameProblem? {
            await PullRequestTextDialog.branchNameProblem(
                name,
                for: Self.request(branch: name, sha: sha),
                in: session
            )
        }

        let invalid = AppLocalization.text("reference.name.sequence")

        #expect(await problem("bad..name", sha: head) == .invalid(invalid))

        // 同名的本地分支 main 指向别的提交时提醒；就在源分支提交上、源分支提交未知或没有同名分支时没有问题
        #expect(await problem("main", sha: String(repeating: "0", count: 40)) == .taken)
        #expect(await problem("main", sha: head.uppercased()) == nil)
        #expect(await problem("main", sha: "") == nil)
        #expect(await problem("feature", sha: head) == nil)
        #expect(await problem("", sha: head) == nil)
    }

    /// 关闭请求的标题写出服务名，说明写出编号与服务名；关闭只在托管服务上进行，仓库暂不可写时仍可关闭。
    @Test("关闭请求的确认")
    func closeRequest() async throws {
        // 没有打开仓库的会话不可写：关闭不受影响，发表评论被挡住
        let unwritable = RepositorySession()

        let github = PullRequestTextDialog(
            session: unwritable,
            request: Self.request(instance: .github),
            kind: .close,
            close: { }
        )

        #expect(github.title == AppLocalization.text("pr.close.title", "GitHub"))
        #expect(github.message == AppLocalization.text("pr.close.message", "#4", "GitHub"))
        #expect(github.submitTitle == AppLocalization.text("pr.close.submit"))
        #expect(!github.isBlocked)

        let comment = PullRequestTextDialog(session: unwritable, request: Self.request(), kind: .comment, close: { })

        #expect(comment.isBlocked)

        // 远端对应私有部署 GitLab 的账号时改叫 Merge Request，服务名写 GitLab Self-Managed
        let fixture = try await PullRequestCommentRulesTests.Fixture.make()
        defer { fixture.close() }

        let service = AppLocalization.text("accounts.kind.gitlabSelfManaged")

        let gitlab = PullRequestTextDialog(
            session: fixture.session,
            request: try PullRequestCommentRulesTests.request(author: "bob"),
            kind: .close,
            close: { }
        )

        #expect(gitlab.title == AppLocalization.text("mr.close.title", service))
        #expect(gitlab.message == AppLocalization.text("mr.close.message", "!4", service))
        #expect(gitlab.submitTitle == AppLocalization.text("mr.close.submit"))
        #expect(!gitlab.isBlocked)
    }
}

// MARK: - Helpers

extension PullRequestTextDialogTests {
    /// `me` 在 `group/project` 发起的请求 `4`，默认在 GitLab.com 上；来自 Fork 时源分支在另一个项目里。
    private static func request(
        branch: String = "feature",
        sha: String = "",
        fork: Bool = false,
        instance: HostingInstance = .gitlabCom
    ) -> PullRequest {
        PullRequest(
            id: PullRequestID(instance: instance, project: "group/project", number: 4),
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
}
