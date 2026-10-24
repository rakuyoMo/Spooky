import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Subtitle

extension FileViewsTests {
    /// 副标题写出正在看的文件与版本，多个窗口之间才分得清各自在看什么。
    @Test("文件历史与文件原文的窗口副标题")
    func subtitles() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await Self.initializeRepository(at: location)
        try FileManager.default.createDirectory(at: directory.appending(path: "dir"), withIntermediateDirectories: false)
        try Data("one\n".utf8).write(to: directory.appending(path: "dir/a.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "first"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let session = RepositorySession(makeRunner: { _ in runner })
        let controller = RepositoryWindowController(
            coordinator: SpookyApplicationController(recent: RecentRepositories(defaults: defaults)),
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

        // 文件历史与原文只写文件名
        session.showFileHistory("dir/a.txt")
        #expect(controller.repositorySubtitle == AppLocalization.text("fileHistory.subtitle", "a.txt"))

        session.showFile("dir/a.txt", at: nil, mode: .blame)
        #expect(controller.repositorySubtitle == AppLocalization.text("showFile.subtitle", "a.txt", "HEAD"))

        session.fileContent.select(revision: head)
        let short = String(head.prefix(8))
        #expect(controller.repositorySubtitle == AppLocalization.text("showFile.subtitle", "a.txt", short))
    }
}
