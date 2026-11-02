import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - PullRequestCommentRulesTests

/// 讨论里的评论与描述：只能修改与删除当前账号自己的、内容不为空的评论，只能修改自己的请求的描述；
/// 托管服务支持时任何评论都能回复；账号需要重新认证或没有令牌时都不可用。右键菜单按同一组规则启用。
@MainActor
struct PullRequestCommentRulesTests {
    /// 作者按用户名不分大小写认出当前账号；空评论不能修改；重新认证与令牌缺失时全部不可用。
    @Test("评论与描述的可用条件")
    func availability() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.close() }

        let session = fixture.session
        let own = Self.comment(id: 1, author: "ME", body: "看过了")
        let others = Self.comment(id: 2, author: "bob", body: "需要改")
        let deleted = Self.comment(id: 3, author: "me", body: "")
        let mine = try Self.request(author: "Me")
        let theirs = try Self.request(author: "bob")

        #expect(session.canModify(own))
        #expect(!session.canModify(others))
        #expect(!session.canModify(deleted))
        #expect(session.canReplyToComments)
        #expect(session.canEditDescription(of: mine))
        #expect(!session.canEditDescription(of: theirs))

        // 账号被标记为需要重新认证
        fixture.accounts.markNeedsReauthentication(fixture.account)
        #expect(!session.canModify(own))
        #expect(!session.canReplyToComments)
        #expect(!session.canEditDescription(of: mine))

        // 重新认证后恢复，令牌不在钥匙串里时又不可用
        _ = try fixture.accounts.save(
            HostingUser(username: "me", name: nil),
            on: fixture.account.instance,
            authentication: .personalAccessToken,
            token: "renewed"
        )
        #expect(session.canModify(own))

        fixture.credentials.removeToken(for: fixture.account)
        #expect(!session.canModify(own))
        #expect(!session.canReplyToComments)
        #expect(!session.canEditDescription(of: mine))
    }

    /// 一条评论：修改、回复、分隔线与删除，按规则启用；两条评论没有菜单；描述只有修改描述。
    @Test("讨论里评论与描述的右键菜单")
    func menus() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.close() }

        let request = try Self.request(author: "bob")

        let comments = [
            Self.comment(id: 1, author: "me", body: "看过了"),
            Self.comment(id: 2, author: "bob", body: "需要改"),
        ]

        let view = PullRequestConversationView(
            session: fixture.session,
            request: request,
            comments: comments,
            commits: nil,
            canComment: true
        )

        let coordinator = view.makeCoordinator()
        let outline = Self.outline(for: coordinator)
        coordinator.update(view)

        // 行依次是头部、描述、两条评论与发表评论
        #expect(Self.menu(of: coordinator, selecting: [2], in: outline) == [
            "pullRequests.editComment.menu:on",
            "pullRequests.replyComment.menu:on",
            "-",
            "pullRequests.deleteComment.menu:on",
        ])

        #expect(Self.menu(of: coordinator, selecting: [3], in: outline) == [
            "pullRequests.editComment.menu:off",
            "pullRequests.replyComment.menu:on",
            "-",
            "pullRequests.deleteComment.menu:off",
        ])

        #expect(Self.menu(of: coordinator, selecting: [2, 3], in: outline).isEmpty)
        #expect(Self.menu(of: coordinator, selecting: [1], in: outline) == ["pullRequests.editDescription.menu:off"])
    }
}

// MARK: PullRequestCommentRulesTests.Fixture

extension PullRequestCommentRulesTests {
    /// 远端在私有部署 GitLab 上的临时仓库与已登录的账号 `me`；实例的端口不可达，读列表失败后远端仍对应这个账号。
    @MainActor
    struct Fixture {
        /// 临时仓库所在的目录。
        let directory: URL

        /// 偏好域名。
        let suite: String

        /// 只在内存里的令牌。
        let credentials: MemoryCredentials

        /// 测试用的账号列表。
        let accounts: HostingAccounts

        /// 已登录的账号。
        let account: HostingAccount

        /// 仓库的会话，远端已对应到账号。
        let session: RepositorySession

        /// 建好仓库与账号，读一次远端与列表。
        static func make() async throws -> Self {
            let directory = try FileViewsTests.temporaryDirectory()
            let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
            _ = try await runner.run(["remote", "add", "origin", "http://127.0.0.1:9/group/project.git"])

            let suite = "spooky-comment-rules-" + UUID().uuidString
            let defaults = try #require(UserDefaults(suiteName: suite))
            let credentials = MemoryCredentials()
            let accounts = HostingAccounts(defaults: defaults, credentials: credentials)
            let instance = try #require(HostingInstance.gitlab(address: "http://127.0.0.1:9"))

            let account = try accounts.save(
                HostingUser(username: "me", name: nil),
                on: instance,
                authentication: .personalAccessToken,
                token: "t"
            )

            let session = RepositorySession(makeRunner: { _ in runner })
            session.pullRequests.accounts = accounts
            session.pullRequests.load(runner: runner)

            // 端口不可达，列表很快失败；远端与账号的对应在读列表前就已定下
            for _ in 0 ..< 1000 where !session.pullRequests.isLoaded {
                try await Task.sleep(for: .milliseconds(10))
            }

            #expect(session.pullRequests.account == account)

            return Self(
                directory: directory,
                suite: suite,
                credentials: credentials,
                accounts: accounts,
                account: account,
                session: session
            )
        }

        /// 删除仓库与偏好域。
        func close() {
            session.close()
            UserDefaults.standard.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

// MARK: - Helpers

extension PullRequestCommentRulesTests {
    /// 评论与描述的菜单项的资源键。
    static let menuKeys = [
        "pullRequests.editComment.menu",
        "pullRequests.replyComment.menu",
        "pullRequests.deleteComment.menu",
        "pullRequests.editDescription.menu",
    ]

    /// 内容不为空或为空的评论。
    static func comment(id: Int, author: String, body: String) -> PullRequestComment {
        PullRequestComment(
            id: id,
            author: HostingUser(username: author, name: nil),
            body: body,
            createdAt: Date(timeIntervalSince1970: TimeInterval(id))
        )
    }

    /// 实例上 `group/project` 里的请求。
    static func request(author: String) throws -> PullRequest {
        let instance = try #require(HostingInstance.gitlab(address: "http://127.0.0.1:9"))

        return PullRequest(
            id: PullRequestID(instance: instance, project: "group/project", number: 4),
            title: "t",
            body: "描述",
            state: .open,
            isDraft: false,
            author: HostingUser(username: author, name: nil),
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            source: PullRequestBranch(project: "group/project", branch: "feature", sha: ""),
            target: PullRequestBranch(project: "group/project", branch: "main", sha: "")
        )
    }

    /// 与讨论相同设置的大纲列表，交给桥接器。
    static func outline(for coordinator: PullRequestConversationView.Coordinator) -> NSOutlineView {
        let frame = NSRect(x: 0, y: 0, width: 600, height: 800)
        let outline = PullRequestConversationView.ConversationOutlineView(frame: frame)
        outline.allowsMultipleSelection = true

        let column = NSTableColumn(identifier: .init("conversation"))
        column.width = frame.width
        outline.addTableColumn(column)
        outline.outlineTableColumn = column

        outline.delegate = coordinator
        outline.dataSource = coordinator
        coordinator.outline = outline
        return outline
    }

    /// 选中几行后的右键菜单：每项写成资源键加 “:on” 或 “:off”，分隔线写成 “-”。
    static func menu(
        of coordinator: PullRequestConversationView.Coordinator,
        selecting rows: IndexSet,
        in outline: NSOutlineView
    ) -> [String] {
        outline.selectRowIndexes(rows, byExtendingSelection: false)

        let menu = NSMenu()
        menu.autoenablesItems = false
        coordinator.menuNeedsUpdate(menu)

        return menu.items.map { item in
            guard !item.isSeparatorItem else {
                return "-"
            }

            // 标题换回资源键，测试不随界面语言变化
            let key = menuKeys.first { AppLocalization.text($0) == item.title } ?? item.title
            return key + (item.isEnabled ? ":on" : ":off")
        }
    }
}
