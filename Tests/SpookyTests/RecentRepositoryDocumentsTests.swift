import AppKit
import Foundation
import SpookyKit
import Testing
import TestSupport

@testable import Spooky

// MARK: - RecentRepositoryDocumentsTests

/// 打开的仓库登记进系统的最近文稿：本机仓库登记仓库文件夹，服务器仓库登记 Application Support 下的位置文件夹；
/// 测试换成记录器，不碰系统里真实的最近文稿。
@MainActor
struct RecentRepositoryDocumentsTests {
    /// 服务器仓库的位置文件夹：名字是远端路径的最后一段、扩展名隐藏，同一个仓库再次登记沿用同一份，
    /// 同名的另一个仓库互不覆盖；位置文件夹与里面的位置文件都读回这个仓库，内容不对时读不出。
    @Test("登记本机与服务器仓库，读回位置")
    func recordsLocations() throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let recorder = RecentDocumentsRecorder(directory: directory)
        let documents = recorder.documents

        // 本机仓库登记仓库文件夹本身
        documents.record(.local(path: "/tmp/本机 仓库"))
        #expect(recorder.noted == [URL(fileURLWithPath: "/tmp/本机 仓库", isDirectory: true)])

        // 服务器仓库登记隐藏了扩展名的位置文件夹
        let remote = RepositoryLocation.remote(host: "build-box", path: "/srv/git/proj")
        documents.record(remote)

        let folder = try #require(recorder.noted.last)
        let values = try folder.resourceValues(forKeys: [.hasHiddenExtensionKey, .isDirectoryKey])

        #expect(folder.lastPathComponent == "proj.spookyrepo")
        #expect(folder.path.hasPrefix(directory.path))
        #expect(values.isDirectory ?? false)
        #expect(values.hasHiddenExtension ?? false)

        // 位置文件夹与里面的位置文件都读回这个仓库
        let file = folder.appending(path: "proj.spookylocation")

        #expect(RecentRepositoryDocuments.location(at: folder) == remote)
        #expect(RecentRepositoryDocuments.location(at: file) == remote)

        // 再次登记沿用同一份；另一台服务器上的同名仓库放在另一个子目录里
        documents.record(remote)
        #expect(recorder.noted.last == folder)

        let other = RepositoryLocation.remote(host: "other-box", path: "/srv/git/proj")
        documents.record(other)

        let otherFolder = try #require(recorder.noted.last)

        #expect(otherFolder != folder)
        #expect(otherFolder.lastPathComponent == "proj.spookyrepo")
        #expect(RecentRepositoryDocuments.location(at: otherFolder) == other)
        #expect(RecentRepositoryDocuments.location(at: folder) == remote)

        // 不是这两种类型、内容不对的都读不出位置
        try Data("{}".utf8).write(to: file)

        #expect(RecentRepositoryDocuments.location(at: folder) == nil)
        #expect(RecentRepositoryDocuments.location(at: directory) == nil)
    }

    /// 经文件夹打开的本机仓库登记进最近文稿，File › Open Recent 的 Clear Menu 一并清空系统里的最近文稿。
    @Test("打开仓库时登记，Clear Menu 一并清空")
    func recordsOpenedRepositories() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        let recorder = RecentDocumentsRecorder(directory: directory)
        let fixture = try await NavigationTests.makeCoordinator(recentDocuments: recorder.documents)

        defer {
            fixture.close()
            try? FileManager.default.removeItem(at: directory)
        }

        let coordinator = fixture.coordinator
        await coordinator.openFolders([fixture.directory]).value

        let opened = try #require(coordinator.windows.first?.session.repository)
        #expect(recorder.noted == [URL(fileURLWithPath: opened.path, isDirectory: true)])

        coordinator.clearRecentRepositories()

        #expect(recorder.clears == 1)
        #expect(coordinator.bookmarks.recentlyOpened.isEmpty)
    }
}

// MARK: - RecentRepositoryDocuments

extension RecentRepositoryDocuments {
    /// 不碰系统最近文稿的登记，给不核对登记的测试用；位置文件夹写进临时目录。
    static let ignoring = RecentRepositoryDocuments(
        directory: FileManager.default.temporaryDirectory.appending(path: "spooky-tests-locations"),
        note: { _ in },
        clear: { }
    )
}

// MARK: - RecentDocumentsRecorder

/// 替代系统最近文稿的记录器：记下登记的 URL 与清空的次数。
@MainActor
final class RecentDocumentsRecorder {
    /// 依次登记的 URL。
    private(set) var noted: [URL] = []

    /// 清空的次数。
    private(set) var clears = 0

    /// 位置文件夹写进的目录。
    let directory: URL

    /// 交给协调者的登记，登记与清空都记在这个记录器上。
    var documents: RecentRepositoryDocuments {
        RecentRepositoryDocuments(
            directory: directory,
            note: { [weak self] in self?.noted.append($0) },
            clear: { [weak self] in self?.clears += 1 }
        )
    }

    /// 建立记录器。
    ///
    /// - Parameter directory: 位置文件夹写进的目录。
    init(directory: URL) {
        self.directory = directory
    }
}
