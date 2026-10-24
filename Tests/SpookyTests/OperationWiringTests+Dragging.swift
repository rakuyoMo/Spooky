import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Dragging

extension OperationWiringTests {
    /// 提交拖到工作区或 HEAD 分支是摘取、⌥ 是反转，可以多选；其它来源与落点只接受单项。
    @Test("提交拖到工作区：摘取、反转与多选")
    func dropCommits() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let (d, b) = (fixture.ids["D"] ?? "", fixture.ids["B"] ?? "")

        #expect(fixture.drop([.commit(d)], on: .head) == "cherryPick:\(d)")
        #expect(fixture.drop([.commit(d)], on: .head, alternate: true) == "revert:\(d)")
        #expect(fixture.drop([.commit(d), .commit(b)], on: .head) == "cherryPick:\(d),\(b)")

        // 多选只用于摘取与反转
        #expect(fixture.drop([.commit(d), .commit(b)], on: .tags) == nil)
        #expect(fixture.drop([.commit(d), .local("refs/heads/side")], on: .head) == nil)

        // 别的仓库拖来的提交不接受
        let other = RepositoryDragPayload(repository: .local(path: "/tmp/elsewhere"), kind: .commit, reference: d)
        #expect(fixture.drop([.payload(other)], on: .head) == nil)
    }

    /// 按住 ⌥ 把别的本地分支拖到 HEAD 是变基；当前分支自己不能变基到自己上面。
    @Test("分支拖到 HEAD：⌥ 变基")
    func dropBranchRebase() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        #expect(fixture.drop([.local("refs/heads/side")], on: .head, alternate: true) == "rebase:refs/heads/side")
        #expect(fixture.drop([.local("refs/heads/side")], on: .head) == nil)
        #expect(fixture.drop([.local("refs/heads/main")], on: .head, alternate: true) == nil)
    }

    /// 提交与本地分支拖到 Tags 标题或标签文件夹是新建标签；标签拖到远端是发布到这个远端。
    @Test("新建标签与发布标签的拖放")
    func dropTags() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let d = fixture.ids["D"] ?? ""

        #expect(fixture.drop([.commit(d)], on: .tags) == "createTag:\(d)")
        #expect(fixture.drop([.commit(d)], on: .tags, alternate: true) == nil)
        #expect(fixture.drop([.local("refs/heads/side")], on: .tagFolder("release")) == "createTag:refs/heads/side")
        #expect(fixture.drop([.tag("refs/tags/v1")], on: .remote("origin")) == "publishTag:v1@origin")

        // 发布打开预选了标签与远端的对话框
        var requests: [ReferenceRequest] = []
        fixture.session.onReferenceRequest = { requests.append($0) }
        fixture.action([.tag("refs/tags/v1")], on: .remote("origin"))?.perform(in: fixture.session)

        guard case .publishTag("v1", remote: "origin") = try #require(requests.first) else {
            Issue.record("应打开预选了标签与远端的发布对话框")
            return
        }
    }

    /// 本地分支拖进分支文件夹、远端分支拖进同一远端的文件夹是改名为 “文件夹/原名末段”；名字不变或拖到别的远端时不接受。
    @Test("拖进文件夹改名")
    func dropMoveHere() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let local = Fixture.Source.local("refs/heads/side")
        let remote = Fixture.Source.remote("refs/remotes/origin/main")

        #expect(fixture.drop([local], on: .branchFolder("功能")) == "move:refs/heads/side→功能/side")
        #expect(fixture.drop([remote], on: .remoteBranchFolder("origin", "旧")) == "move:refs/remotes/origin/main→旧/main")
        #expect(fixture.drop([remote], on: .remoteBranchFolder("upstream", "旧")) == nil)

        // 提交拖进分支文件夹是新建分支，由已有的参数表单处理
        #expect(fixture.drop([.commit(fixture.ids["D"] ?? "")], on: .branchFolder("功能")) == nil)

        // 改名直接执行，移进文件夹后原名字不在了
        fixture.action([.local("refs/heads/side")], on: .branchFolder("功能"))?.perform(in: fixture.session)
        await fixture.session.writeTask?.value

        let names = try await fixture.runner.run(["for-each-ref", "--format=%(refname)", "refs/heads/"])
        let branches = String(decoding: names, as: UTF8.self).split(separator: "\n").map(String.init)
        #expect(branches.contains("refs/heads/功能/side"))
        #expect(!branches.contains("refs/heads/side"))

        // 已在这个文件夹里时名字不变，不接受
        fixture.session.refresh(full: true)
        await fixture.session.refreshTask?.value
        try await FileViewsTests.wait { fixture.session.history.branches.contains { $0.name == "功能/side" } }
        #expect(fixture.drop([.local("refs/heads/功能/side")], on: .branchFolder("功能")) == nil)
    }

    /// 变更集里的单个文件拖到工作区：只把这个文件的改动套到工作区，暂存区不动；文件只能来自当前显示的提交详情。
    @Test("变更集文件拖到工作区：只摘取这个文件")
    func dropCommitFile() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let unpulled = try await fixture.select("refs/heads/main", subjects: ["C"])
        try await FileViewsTests.wait { fixture.session.history.changes.contains { $0.path == "C.txt" } }

        let file = RepositoryDragPayload(
            repository: try #require(fixture.session.repository),
            kind: .commitFile,
            reference: unpulled.id,
            path: "C.txt"
        )

        #expect(fixture.drop([.payload(file)], on: .head) == "pickFile:C.txt")
        #expect(fixture.drop([.payload(file)], on: .head, alternate: true) == nil)

        fixture.action([.payload(file)], on: .head)?.perform(in: fixture.session)
        await fixture.session.writeTask?.value

        let content = try Data(contentsOf: fixture.directory.appending(path: "C.txt"))
        #expect(String(decoding: content, as: UTF8.self) == "C\n")

        let status = try await fixture.runner.status()
        #expect(!status.entries.contains { $0.hasStagedChanges })

        // 换选别的提交后，原来详情里的文件不再接受
        _ = try await fixture.select("refs/heads/main", subjects: ["D"])
        #expect(fixture.drop([.payload(file)], on: .head) == nil)
    }
}

// MARK: - Helpers

extension OperationWiringTests.Fixture {
    /// 拖动来源的简写。
    enum Source {
        /// 提交。
        case commit(String)

        /// 本地分支的完整引用名。
        case local(String)

        /// 远端分支的完整引用名。
        case remote(String)

        /// 标签的完整引用名。
        case tag(String)

        /// 现成的载荷，如别的仓库或提交里的文件。
        case payload(RepositoryDragPayload)
    }

    /// 这些来源拖到落点时的动作。
    @MainActor
    func action(
        _ sources: [Source],
        on destination: RepositoryDropDestination,
        alternate: Bool = false
    ) -> RepositoryOperationDrop? {
        RepositoryOperationDrop(
            payloads: sources.compactMap(payload),
            destination: destination,
            alternate: alternate,
            session: session
        )
    }

    /// 这些来源拖到落点时的动作，写成便于比较的文字；没有动作时为 nil。
    @MainActor
    func drop(_ sources: [Source], on destination: RepositoryDropDestination, alternate: Bool = false) -> String? {
        guard let action = action(sources, on: destination, alternate: alternate) else {
            return nil
        }

        switch action {
        case .cherryPick(let commits): return "cherryPick:" + commits.joined(separator: ",")
        case .revert(let commits): return "revert:" + commits.joined(separator: ",")
        case .cherryPickFile(let change, _): return "pickFile:" + change.path
        case .rebase(let branch): return "rebase:" + branch.id
        case .createTag(let revision): return "createTag:" + revision
        case .moveBranch(let branch, let name): return "move:" + branch.id + "→" + name
        case .publishTag(let tag, let remote): return "publishTag:" + tag + "@" + remote
        }
    }

    /// 简写换成本仓库的载荷；现成的载荷原样使用。
    @MainActor
    private func payload(_ source: Source) -> RepositoryDragPayload? {
        guard let repository = session.repository else {
            return nil
        }

        switch source {
        case .commit(let id): return RepositoryDragPayload(repository: repository, kind: .commit, reference: id)
        case .local(let id): return RepositoryDragPayload(repository: repository, kind: .local, reference: id)
        case .remote(let id): return RepositoryDragPayload(repository: repository, kind: .remote, reference: id)
        case .tag(let id): return RepositoryDragPayload(repository: repository, kind: .tag, reference: id)
        case .payload(let payload): return payload
        }
    }
}
