import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - ChangesetFileMenuTests

/// 变更集右键菜单的作用文件、标题与复制的内容。
@MainActor
struct ChangesetFileMenuTests {
    /// 右键选区里的行作用于整个选区、选区外的行只作用于它；单个文件的标题写仓库内的完整路径，多个文件写数量；
    /// 复制的完整路径是仓库位置加相对路径，相对路径原样。
    @Test("变更集菜单的作用文件、标题与复制内容")
    func menuTargetsAndTitles() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        session.display(runner.location)

        let deep = "fixtures/深い/dir/[x] f26.txt"
        let files = [deep, "b.txt", "c.txt"].map {
            CommitFileChange(path: $0, originalPath: nil, status: "M", additions: 1, deletions: 0)
        }
        let order = files.map(\.path)
        let commit = Self.commit()

        // 选中前两行：右键其中一行作用于两行，右键第三行只作用于第三行，选区不变
        var selection = ChangesetFileSelection()
        selection.click(deep, extending: false, toggling: false, order: order)
        selection.click("b.txt", extending: true, toggling: false, order: order)

        #expect(selection.affected(clicked: "b.txt", order: order) == [deep, "b.txt"])
        #expect(selection.affected(clicked: "c.txt", order: order) == ["c.txt"])
        #expect(selection.paths == [deep, "b.txt"])

        // 单个文件：复制两项在前，其后的标题都写完整路径
        let single = ChangesetFileMenu.groups(session: session, files: [files[0]], commit: commit, contentEnabled: true)
        let shortID = commit.shortID

        #expect(single.map { $0.map(\.title) } == [
            ["Copy File Path", "Copy Relative File Path"],
            [
                "Show “\(deep)” at Revision “\(shortID)”",
                "Show Blame for “\(deep)” at Revision “\(shortID)”",
                "Show File History of “\(deep)”",
            ],
            ["Open Diff Tool for “\(deep)” at Revision “\(shortID)”"],
            [
                "Restore “\(deep)” at Revision “\(shortID)” in Working Copy…",
                "Export “\(deep)” at Revision “\(shortID)”…",
            ],
        ])

        // 多个文件：标题写数量，没有查看一组
        let multiple = ChangesetFileMenu.groups(
            session: session,
            files: Array(files.prefix(2)),
            commit: commit,
            contentEnabled: true
        )

        #expect(multiple.map { $0.map(\.title) } == [
            ["Copy File Path", "Copy Relative File Path"],
            ["Open Diff Tool for 2 Items at Revision “\(shortID)”"],
            [
                "Restore 2 Items at Revision “\(shortID)” in Working Copy…",
                "Export 2 Items at Revision “\(shortID)”…",
            ],
        ])

        // 复制的内容：每行一个，完整路径是仓库位置加相对路径
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.rakuyo.spooky.tests." + UUID().uuidString))
        defer { pasteboard.releaseGlobally() }

        let paths = [deep, "b.txt"]
        let root = try #require(session.repository).displayPath

        session.copyPaths(paths, relative: false, to: pasteboard)
        #expect(pasteboard.string(forType: .string) == root + "/" + deep + "\n" + root + "/b.txt")

        session.copyPaths(paths, relative: true, to: pasteboard)
        #expect(pasteboard.string(forType: .string) == deep + "\nb.txt")
    }
}

// MARK: - Helpers

extension ChangesetFileMenuTests {
    /// 菜单所在的提交，只用到哈希。
    private static func commit() -> HistoryCommit {
        let date = Date(timeIntervalSince1970: 0)

        return HistoryCommit(
            id: String(repeating: "2", count: 40),
            tree: String(repeating: "b", count: 40),
            parents: [],
            author: "Test User",
            authorEmail: "test@example.invalid",
            authorDate: date,
            committer: "Test User",
            committerEmail: "test@example.invalid",
            commitDate: date,
            message: "Add fixtures"
        )
    }
}
