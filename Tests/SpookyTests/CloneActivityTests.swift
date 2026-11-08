import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - CloneActivityTests

/// 克隆：对话框的目标与校验、每台主机记住的目录，以及后台克隆与书签的生命周期。
@MainActor
struct CloneActivityTests {
    /// 每个用例独立的偏好域与它所在的临时目录；用例结束时删掉目录。
    private static func defaults() throws -> (UserDefaults, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-clone-" + UUID().uuidString)

        return (try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path)), directory)
    }

    /// 目标是所选目录下以仓库名命名的新目录；服务器目标沿用主机，地址不合法、主机别名或目录不完整时没有目标。
    /// 地址不合法时提示；本机目标已是有内容的目录或文件时提示，空目录可以；地址没填时不提示。
    @Test("克隆目标与它的校验")
    func destinations() throws {
        let url = "git@github.com:rakuyoMo/Spooky.git"

        #expect(
            CloneTarget.destination(url: url, parent: .local(path: "/tmp/克隆 目录"))
                == .local(path: "/tmp/克隆 目录/Spooky")
        )
        #expect(CloneTarget.destination(url: url, parent: .local(path: "/")) == .local(path: "/Spooky"))
        #expect(
            CloneTarget.destination(url: url, parent: .remote(host: "spooky-test", path: "/srv/"))
                == .remote(host: "spooky-test", path: "/srv/Spooky")
        )
        #expect(CloneTarget.destination(url: url, parent: .remote(host: "", path: "/srv")) == nil)
        #expect(CloneTarget.destination(url: url, parent: .remote(host: "b", path: "srv")) == nil)
        #expect(CloneTarget.destination(url: "https://", parent: .local(path: "/tmp")) == nil)
        #expect(CloneTarget.destination(url: "-invalid", parent: .local(path: "/tmp")) == nil)

        // 本机目标：空目录可以，有内容的目录与文件不行
        let root = FileManager.default.temporaryDirectory.appending(path: "spooky-clone-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appending(path: "empty"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appending(path: "full"), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: root.appending(path: "full/file.txt"))
        try Data("x".utf8).write(to: root.appending(path: "file"))
        defer { try? FileManager.default.removeItem(at: root) }

        let parent = RepositoryLocation.local(path: root.path)

        #expect(CloneTarget.problem(url: "", parent: parent) == nil)
        #expect(CloneTarget.problem(url: "--upload-pack=x", parent: parent) != nil)
        #expect(CloneTarget.problem(url: "https://example.invalid/team/new.git", parent: parent) == nil)
        #expect(CloneTarget.problem(url: "https://example.invalid/team/empty.git", parent: parent) == nil)
        #expect(CloneTarget.problem(url: "https://example.invalid/team/full.git", parent: parent) != nil)
        #expect(CloneTarget.problem(url: "https://example.invalid/team/file", parent: parent) != nil)

        // 服务器目标由 B 上的 Git 检查，这里只要求绝对路径
        let server = { (path: String) in
            CloneTarget.problem(
                url: "https://example.invalid/a.git",
                parent: .remote(host: "b", path: path)
            )
        }

        #expect(server("srv") != nil)
        #expect(server("/srv") == nil)
    }

    /// 每台主机记住上次克隆用的目录；选择机器时列出书签里的主机与克隆过的主机。
    @Test("每台主机的克隆目录")
    func serverDirectories() throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        bookmarks.add(.remote(host: "nas", path: "/volume1/app"))
        bookmarks.add(.local(path: "/tmp/local"))

        #expect(ServerCloneDirectories.directory(for: "spooky-test", in: defaults) == nil)

        ServerCloneDirectories.remember("/Users/wgy/spooky-test", for: "spooky-test", in: defaults)
        #expect(ServerCloneDirectories.directory(for: "spooky-test", in: defaults) == "/Users/wgy/spooky-test")
        #expect(ServerCloneDirectories.hosts(in: bookmarks, defaults: defaults) == ["nas", "spooky-test"])
    }

    /// 克隆一开始书签就出现；失败后留着书签供重试，重试再加回书签，移除没有完成的克隆时连书签一起移除。
    @Test("克隆与书签的生命周期")
    func lifecycle() async throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let clones = CloneActivities(bookmarks: bookmarks)

        // 目标不是绝对路径，克隆在执行 Git 之前就失败
        let destination = RepositoryLocation.local(path: "relative/app")
        let activity = clones.start(RepositoryClone(url: "https://example.invalid/app.git", destination: destination))

        #expect(bookmarks.bookmark(for: destination) != nil)
        #expect(clones.unfinished(at: destination) === activity)

        await until { !activity.isRunning }
        guard case .failed = activity.state else {
            Issue.record("目标不是绝对路径时克隆应失败")
            return
        }

        bookmarks.delete(bookmarks.repositories.map(\.id))
        clones.restart(activity)
        #expect(bookmarks.bookmark(for: destination) != nil)
        await until { !activity.isRunning }

        clones.clear()
        #expect(clones.isEmpty)
        #expect(bookmarks.bookmark(for: destination) == nil)
    }
}
