import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ActivityArchiveTests

/// Activity 的 Remote 记录存在本机：结束时写入，重新启动后读回，过期与清除的记录连文件一起删掉。
///
/// 每个测试使用自己的临时目录与 `RepositoryActivities` 实例，不碰 Application Support 与共享的活动列表。
@MainActor
struct ActivityArchiveTests {
    /// 结束的 Remote 记录写成文件，换一个实例读回后标题、状态与日志都相同，并带读回标记；进行中的、Repository 与 Service 的记录不写。
    @Test("Remote 记录结束时保存，重新启动后读回")
    func saveAndRestore() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.remote(host: "spooky-test", path: "/Users/wgy/spooky-test/仓库 [1]")
        let activities = RepositoryActivities()
        await activities.restore(from: directory)

        // 一条结束的 Remote 记录，带回车刷新的进度
        let fetch = RepositoryActivity(kind: .remote, repository: location, title: "Fetch")
        activities.insert(fetch)
        fetch.append(.standardOutput(Data("From spooky-test\n".utf8)))
        fetch.append(.standardError(Data("接收对象：50%\r接收对象：100%\n".utf8)))
        fetch.state = "activity.failed"
        activities.finish(fetch)

        // 进行中的 Remote 记录，与结束的 Repository、Service 记录
        let running = RepositoryActivity(kind: .remote, repository: location, title: "Push")
        activities.insert(running)

        for kind in [ActivityKind.repository, .service] {
            let other = RepositoryActivity(kind: kind, repository: location, title: "Other")
            activities.insert(other)
            other.state = "activity.finished"
            activities.finish(other)
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files == [fetch.id.uuidString + ".json"])
        #expect(!fetch.isRestored)

        // 新的实例读回同一条记录
        let restored = RepositoryActivities()
        await restored.restore(from: directory)

        let item = try #require(restored.items.first)
        #expect(restored.items.count == 1)
        #expect(item.id == fetch.id)
        #expect(item.kind == .remote)
        #expect(item.repository == location)
        #expect(item.title == "Fetch")
        #expect(item.started == fetch.started)
        #expect(item.state == "activity.failed")
        #expect(item.log == "From spooky-test\n\n接收对象：100%\n")
        #expect(item.log == fetch.log)

        // 读回的记录不是本次运行里发生的，侧边栏底部据此不列它
        #expect(item.isRestored)
    }

    /// 开始于 7 天前的记录读回时连文件删掉，读不了的文件跳过；运行期间按传入的当前时间删过期记录。
    @Test("过期的 Remote 记录连文件删掉")
    func removeExpired() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let archive = ActivityArchive(directory: directory)
        let now = Date()
        let old = record(started: now.addingTimeInterval(-8 * 24 * 60 * 60))
        let recent = record(started: now.addingTimeInterval(-60))
        archive.save(old)
        archive.save(recent)
        try Data("{".utf8).write(to: directory.appending(path: "broken.json"))

        let activities = RepositoryActivities()
        await activities.restore(from: directory, now: now)

        #expect(activities.items.map(\.id) == [recent.id])
        #expect(!exists(archive.url(of: old.id)))
        #expect(exists(archive.url(of: recent.id)))

        // 还没满 7 天的保留，满了的连文件删掉
        activities.removeExpired(now: now.addingTimeInterval(6 * 24 * 60 * 60))
        #expect(activities.items.map(\.id) == [recent.id])

        activities.removeExpired(now: now.addingTimeInterval(8 * 24 * 60 * 60))
        #expect(activities.items.isEmpty)
        #expect(!exists(archive.url(of: recent.id)))
    }

    /// 清除 Remote 页的已结束记录时文件一起删；进行中的记录与别的页不动。
    @Test("清除 Remote 的已结束记录时删掉文件")
    func clearEnded() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: "/temporary/activity-" + UUID().uuidString)
        let activities = RepositoryActivities()
        await activities.restore(from: directory)

        let fetch = RepositoryActivity(kind: .remote, repository: location, title: "Fetch")
        activities.insert(fetch)
        fetch.state = "activity.finished"
        activities.finish(fetch)

        let running = RepositoryActivity(kind: .remote, repository: location, title: "Push")
        activities.insert(running)

        let commit = RepositoryActivity(kind: .repository, repository: location, title: "Branch")
        activities.insert(commit)
        commit.state = "activity.finished"
        activities.finish(commit)

        let file = ActivityArchive(directory: directory).url(of: fetch.id)
        #expect(exists(file))

        activities.clearEnded(.remote)

        #expect(activities.items.map(\.id) == [commit.id, running.id])
        #expect(!exists(file))
    }

    /// 一条已完成的 Remote 记录。
    private func record(started: Date) -> ActivityRecord {
        ActivityRecord(
            id: UUID(),
            kind: .remote,
            repository: .local(path: "/temporary/activity"),
            title: "Fetch",
            started: started,
            state: "activity.finished",
            stdout: Data(),
            stderr: Data()
        )
    }

    /// 文件是否存在。
    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}
