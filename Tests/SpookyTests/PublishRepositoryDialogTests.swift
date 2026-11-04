import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - PublishRepositoryDialogTests

/// 发布仓库用 480 宽的对话框骨架：远端名避开已有的远端，账号与组织在同一个下拉里；没有登录的账号时菜单项不可用。
@MainActor
struct PublishRepositoryDialogTests {
    /// 480 宽；Remote Name、Name 与 Description 从对齐线开始，右缘距对话框右边 20，Description 高 64。
    @Test("对话框的宽度与输入框的位置")
    func layout() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-publish-" + UUID().uuidString)
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defer { try? FileManager.default.removeItem(at: directory) }

        let session = RepositorySession()
        session.pullRequests.accounts = HostingAccounts(defaults: defaults, credentials: MemoryCredentials())

        let hosting = NSHostingView(rootView: PublishRepositoryDialog(session: session, close: { }))
        hosting.frame.size = hosting.fittingSize
        hosting.layoutSubtreeIfNeeded()
        #expect(hosting.frame.width == 480)

        // 自上而下依次是 Remote Name、Name 与 Description；描述的文字框外有上下 8、左右 4 的边距，边框画在边距外缘
        let fields = Self.subviews(NSTextField.self, in: hosting)
            .filter(\.isEditable)
            .compactMap { field in field.superview.map { $0.convert($0.bounds, to: hosting) } }
            .sorted { $0.minY < $1.minY }

        try #require(fields.count == 3)

        let description = fields[2].insetBy(dx: -4, dy: -8)

        for frame in [fields[0], fields[1], description] {
            #expect(abs(frame.minX - DialogMetrics.alignment) <= 1)
            #expect(abs(frame.maxX - 460) <= 1)
        }

        #expect(abs(description.height - 64) <= 1)
    }

    /// `origin` 没被占用时用它；被占用时依次试 `origin-2`、`origin-3`。
    @Test("预填的远端名")
    func remoteName() {
        #expect(PublishRepositoryDialog.remoteName(avoiding: []) == "origin")
        #expect(PublishRepositoryDialog.remoteName(avoiding: ["upstream"]) == "origin")
        #expect(PublishRepositoryDialog.remoteName(avoiding: ["origin"]) == "origin-2")
        #expect(PublishRepositoryDialog.remoteName(avoiding: ["origin", "origin-2"]) == "origin-3")
    }

    /// 按账号列表的顺序，每个账号先是本人、再是按路径升序的组织；本人写出实例，组织写路径；还没读到的账号没有项。
    @Test("Account 下拉的项")
    func items() throws {
        let github = HostingAccount(instance: .github, username: "rakuyo", authentication: .oauth)
        let gitlab = HostingAccount(
            instance: try #require(HostingInstance.gitlab(address: "https://git.example.com")),
            username: "me",
            authentication: .personalAccessToken
        )
        let pending = HostingAccount(instance: .gitlabCom, username: "later", authentication: .personalAccessToken)

        let owners = [
            github.id: [
                HostingOwner(id: "rakuyo", path: "rakuyo", isUser: true),
                HostingOwner(id: "zeta", path: "zeta", isUser: false),
                HostingOwner(id: "Acme", path: "Acme", isUser: false),
            ],
            gitlab.id: [
                HostingOwner(id: "9", path: "group/sub", isUser: false),
                HostingOwner(id: "3", path: "me", isUser: true),
                HostingOwner(id: "7", path: "group", isUser: false),
            ],
        ]

        let items = PublishRepositoryDialog.items(of: [github, pending, gitlab], owners: owners)

        #expect(items.map(\.title) == [
            "rakuyo – " + HostingInstance.github.displayName,
            "Acme",
            "zeta",
            "me – " + gitlab.instance.displayName,
            "group",
            "group/sub",
        ])
        #expect(items.map(\.account) == [github, github, github, gitlab, gitlab, gitlab])
        #expect(Set(items.map(\.id)).count == items.count)
    }

    /// 没有登录的账号时 Publish Repository… 不可用，加上账号后可用。
    @Test("菜单项要求有登录的账号")
    func menuRequiresAccount() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let credentials = MemoryCredentials()
        let accounts = HostingAccounts(defaults: fixture.defaults, credentials: credentials)
        let controller = fixture.controller
        controller.session.pullRequests.accounts = accounts

        let item = NSMenuItem(
            title: "",
            action: #selector(RepositoryWindowController.publishRepository),
            keyEquivalent: ""
        )
        #expect(!controller.validateUserInterfaceItem(item))

        _ = try accounts.save(
            HostingUser(username: "me", name: nil),
            on: .github,
            authentication: .personalAccessToken,
            token: "t"
        )
        #expect(controller.validateUserInterfaceItem(item))
    }
}

// MARK: - Helpers

extension PublishRepositoryDialogTests {
    /// 根视图下所有这一类的子视图。
    private static func subviews<Element: NSView>(_: Element.Type, in root: NSView) -> [Element] {
        root.subviews.flatMap { child in
            [child as? Element].compactMap(\.self) + subviews(Element.self, in: child)
        }
    }
}
