import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - SidebarTreeTests

/// 侧边栏按 “/” 折叠、过滤、数量限制与排序都只依赖引用名与时间，与界面无关。
struct SidebarTreeTests {
    /// 多级前缀逐级成为文件夹，只有一个子项的前缀也是文件夹；文件夹出现在第一个子项的位置。
    @Test("按斜杠折叠成文件夹")
    func grouping() {
        let entries = ["a", "feature/x", "feature/sub/y", "main", "solo/only"].map(entry)
        let nodes = SidebarRefTree.nodes(for: entries, grouped: true, foldersFirst: false, scope: "branches")

        #expect(nodes.map(\.name) == ["a", "feature", "main", "solo"])
        #expect(nodes.map(\.isFolder) == [false, true, false, true])

        let feature = nodes[1]
        #expect(feature.id.value == "branches|folder|feature")
        #expect(feature.children.map(\.name) == ["x", "sub"])
        #expect(feature.children[1].id.value == "branches|folder|feature/sub")
        #expect(feature.children[1].children.first?.reference?.id == "refs/heads/feature/sub/y")
        #expect(nodes[3].children.map(\.name) == ["only"])

        // 文件夹置前时每一级都把文件夹排在引用前面
        let foldersFirst = SidebarRefTree.nodes(for: entries, grouped: true, foldersFirst: true, scope: "branches")
        #expect(foldersFirst.map(\.name) == ["feature", "solo", "a", "main"])
        #expect(foldersFirst[0].children.map(\.name) == ["sub", "x"])

        // 不折叠时每条引用显示完整名，没有文件夹
        let flat = SidebarRefTree.nodes(for: entries, grouped: false, foldersFirst: true, scope: "branches")
        #expect(flat.map(\.name) == ["a", "feature/x", "feature/sub/y", "main", "solo/only"])
        #expect(SidebarRefTree.folderIDs(in: flat).isEmpty)

        #expect(
            SidebarRefTree.folderIDs(in: nodes).map(\.value).sorted()
                == ["branches|folder|feature", "branches|folder|feature/sub", "branches|folder|solo"]
        )
    }

    /// 远端名带斜杠时，分支按最长前缀归属，显示名去掉远端名后再折叠；不同分组里的同名文件夹各有身份。
    @Test("远端名含斜杠的远端分支")
    func remoteBranches() {
        let snapshot = ReferenceSnapshot(
            references: [
                reference("refs/remotes/team/HEAD", symbolicTarget: "refs/remotes/team/main"),
                reference("refs/remotes/team/main"),
                reference("refs/remotes/team/origin/feature/x"),
                reference("refs/remotes/team/origin/main"),
            ],
            remotes: [RepositoryRemote(name: "team"), RepositoryRemote(name: "team/origin")]
        )

        let team = SidebarRefTree.remoteEntries(
            of: RepositoryRemote(name: "team"),
            in: snapshot,
            filter: "",
            limit: 0,
            including: []
        )
        #expect(team.map(\.name) == ["main"])

        let nested = SidebarRefTree.remoteEntries(
            of: RepositoryRemote(name: "team/origin"),
            in: snapshot,
            filter: "",
            limit: 0,
            including: []
        )
        #expect(nested.map(\.name) == ["feature/x", "main"])

        let nodes = SidebarRefTree.nodes(for: nested, grouped: true, foldersFirst: true, scope: "remote|team/origin")
        #expect(nodes.first?.id.value == "remote|team/origin|folder|feature")
        #expect(nodes.first?.children.first?.reference?.id == "refs/remotes/team/origin/feature/x")
    }

    /// 过滤按字符顺序匹配，不区分大小写与变音符号；空文字匹配一切。
    @Test("模糊过滤")
    func filtering() {
        #expect(SidebarRefTree.matches("feature/login", filter: "ftlg"))
        #expect(SidebarRefTree.matches("feature/login", filter: "LOGIN"))
        #expect(SidebarRefTree.matches("release/café", filter: "cafe"))
        #expect(SidebarRefTree.matches("功能/登录", filter: "登录"))
        #expect(SidebarRefTree.matches("main", filter: ""))
        #expect(!SidebarRefTree.matches("feature/login", filter: "gol"))
        #expect(!SidebarRefTree.matches("main", filter: "mainline"))

        let branches = ["refs/heads/feature/login", "refs/heads/main"].map { reference($0) }
        #expect(SidebarRefTree.branchEntries(branches, filter: "flog").map(\.name) == ["feature/login"])
        #expect(SidebarRefTree.branchEntries(branches, filter: "").count == 2)
    }

    /// 数量限制按时间取最新的若干个，选中的引用总会留下，结果保持原有顺序；时间相同时按引用名决定。
    @Test("只显示最新的若干个")
    func newest() {
        let references = [
            reference("refs/remotes/origin/a", date: Date(timeIntervalSince1970: 100)),
            reference("refs/remotes/origin/b", date: Date(timeIntervalSince1970: 400)),
            reference("refs/remotes/origin/c", date: nil),
            reference("refs/remotes/origin/d", date: Date(timeIntervalSince1970: 400)),
        ]

        let ids = { (refs: [RepositoryReference]) in refs.map(\.id) }
        #expect(ids(SidebarRefTree.newest(references, limit: 2, including: [])) == [
            "refs/remotes/origin/b",
            "refs/remotes/origin/d",
        ])
        #expect(ids(SidebarRefTree.newest(references, limit: 1, including: [])) == ["refs/remotes/origin/b"])
        #expect(ids(SidebarRefTree.newest(references, limit: 0, including: [])) == ids(references))
        #expect(ids(SidebarRefTree.newest(references, limit: 10, including: [])) == ids(references))

        // 选中的旧引用补进结果
        #expect(
            ids(SidebarRefTree.newest(references, limit: 1, including: ["refs/remotes/origin/c"]))
                == ["refs/remotes/origin/b", "refs/remotes/origin/c"]
        )

        // 过滤时不受数量限制
        let snapshot = ReferenceSnapshot(references: references, remotes: [RepositoryRemote(name: "origin")])
        let filtered = SidebarRefTree.remoteEntries(
            of: RepositoryRemote(name: "origin"),
            in: snapshot,
            filter: "a",
            limit: 1,
            including: []
        )
        #expect(filtered.map(\.name) == ["a"])
    }

    /// 标签按名称排序时数字按数值比较；数量限制先取最新的，再排序。
    @Test("标签的排序与数量")
    func tagOrder() {
        let snapshot = ReferenceSnapshot(
            references: [
                reference("refs/heads/main"),
                reference("refs/tags/v1.10", date: Date(timeIntervalSince1970: 300)),
                reference("refs/tags/v1.9", date: Date(timeIntervalSince1970: 200)),
                reference("refs/tags/v1.2", date: Date(timeIntervalSince1970: 100)),
                reference("refs/tags/release/v2", date: Date(timeIntervalSince1970: 400)),
            ],
            remotes: []
        )

        let ascending = SidebarRefTree.tagEntries(
            in: snapshot,
            filter: "",
            limit: 0,
            including: [],
            order: .nameAscending
        )
        #expect(ascending.map(\.name) == ["release/v2", "v1.2", "v1.9", "v1.10"])

        let newest = SidebarRefTree.tagEntries(
            in: snapshot,
            filter: "",
            limit: 2,
            including: [],
            order: .nameDescending
        )
        #expect(newest.map(\.name) == ["v1.10", "release/v2"])

        let filtered = SidebarRefTree.tagEntries(
            in: snapshot,
            filter: "v19",
            limit: 1,
            including: [],
            order: .nameAscending
        )
        #expect(filtered.map(\.name) == ["v1.9"])
    }
}

// MARK: - Helpers

extension SidebarTreeTests {
    /// 显示名即分支名的本地分支条目。
    private func entry(_ name: String) -> SidebarRefTree.Entry {
        SidebarRefTree.Entry(reference: reference("refs/heads/" + name), name: name)
    }

    /// 指向同一个提交的引用。
    private func reference(_ id: String, symbolicTarget: String? = nil, date: Date? = nil) -> RepositoryReference {
        RepositoryReference(
            id: id,
            objectID: String(repeating: "b", count: 64),
            objectType: "commit",
            upstream: nil,
            upstreamRemote: nil,
            upstreamBranch: nil,
            symbolicTarget: symbolicTarget,
            date: date
        )
    }
}
