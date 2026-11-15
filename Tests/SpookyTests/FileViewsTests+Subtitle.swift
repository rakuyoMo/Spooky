import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Subtitle

extension FileViewsTests {
    /// 副标题写出正在看的文件与版本，多个窗口之间才分得清各自在看什么；工作区在分离 HEAD 时写出所在的提交。
    @Test("工作区、文件历史与文件原文的窗口副标题")
    func subtitles() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await Self.initializeRepository(at: location)
        try FileManager.default.createDirectory(
            at: directory.appending(path: "dir"),
            withIntermediateDirectories: false
        )

        try Data("one\n".utf8).write(to: directory.appending(path: "dir/a.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "first"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let session = RepositorySession(makeRunner: { _ in runner })
        let controller = RepositoryWindowController(
            coordinator: SpookyApplicationController(
                bookmarks: RepositoryBookmarks(defaults: defaults),
                recentDocuments: .ignoring
            ),
            session: session
        )
        defer {
            session.close()
            controller.window?.close()
        }

        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()
        #expect(controller.repositorySubtitle == AppLocalization.text("working.subtitle.branch", "main", 0))

        // 分离 HEAD 时分支一段写前 8 位哈希与分离状态
        let short = String(head.prefix(8))
        _ = try await runner.run(["switch", "-q", "--detach"])

        session.refresh(full: true)
        await session.waitForRefresh()

        #expect(
            controller.repositorySubtitle
                == AppLocalization.text("working.subtitle.branch", AppLocalization.text("branch.detached", short), 0)
        )

        // 文件历史与原文只写文件名
        session.showFileHistory("dir/a.txt")
        #expect(controller.repositorySubtitle == AppLocalization.text("fileHistory.subtitle", "a.txt"))

        session.showFile("dir/a.txt", at: nil, mode: .blame)
        #expect(controller.repositorySubtitle == AppLocalization.text("showFile.subtitle", "a.txt", "HEAD"))

        session.fileContent.select(revision: head)
        #expect(controller.repositorySubtitle == AppLocalization.text("showFile.subtitle", "a.txt", short))
    }
}
