import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Checkout

extension StashSessionTests {
    /// 已跟踪文件有修改时，修改不妨碍检出也先询问，询问提供完成后恢复；
    /// Do Not Stash 照常检出、修改随之带过去，Stash Changes 先储藏再检出；没有修改时直接检出，不询问。
    @Test("有本地修改时检出先询问 Auto Stash")
    func autoStashBeforeCheckout() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-stash-" + UUID().uuidString)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await makeRepository(at: location)
        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        defer { session.close() }

        var requests: [StashRequest] = []
        var failures: [AppFailure] = []
        session.onStashRequest = { requests.append($0) }
        session.onFailure = { failures.append($0) }

        session.display(location)
        session.refresh()
        await session.waitForRefresh()

        let tracked = directory.appending(path: "tracked.txt")
        let feature = directory.appending(path: "feature.txt")

        // feature 没有改动 tracked.txt，修改不妨碍检出，仍先询问；询问之前没有开始写
        try Data("local\n".utf8).write(to: tracked)
        session.refresh()
        await session.waitForRefresh()

        #expect(session.checkout(revision: "feature"))
        #expect(!session.isWriting)

        let declined = try #require(await autoStashRequest(at: 0, in: { requests }))

        #expect(declined.error == nil && !declined.keepsStash)

        // Do Not Stash：照常检出，修改随之带到 feature
        session.declineAutoStash(declined)
        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(failures.isEmpty)
        #expect(FileManager.default.fileExists(atPath: feature.path))
        #expect(try Data(contentsOf: tracked) == Data("local\n".utf8))

        // Stash Changes：先储藏再检出，不恢复时修改留在储藏里
        #expect(session.checkout(revision: "main"))

        let accepted = try #require(await autoStashRequest(at: 1, in: { requests }))

        session.performAutoStash(accepted, message: "auto", reapply: false)
        await session.writeTask?.value
        await session.waitForRefresh()
        await untilFinished { session.stashes.activeTasks }

        #expect(failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: feature.path))
        #expect(try Data(contentsOf: tracked) == Data("base\n".utf8))
        #expect(session.stashes.entries.count == 1)

        // 工作区没有修改：直接检出，不再询问
        #expect(session.checkout(revision: "feature"))
        #expect(session.isWriting)

        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(requests.count == 2)
        #expect(FileManager.default.fileExists(atPath: feature.path))
    }
}

// MARK: - Helpers

extension StashSessionTests {
    /// 等序号为 `index` 的储藏请求出现，取出其中的自动储藏询问；不是自动储藏时为 nil。
    ///
    /// - Parameters:
    ///   - index: 请求的序号；开始前的询问在下一轮主线程才发出。
    ///   - requests: 读取已收到的请求。
    private func autoStashRequest(
        at index: Int,
        in requests: @escaping @MainActor () -> [StashRequest]
    ) async -> AutoStashRequest? {
        await until { requests().count > index }

        guard case .autoStash(let pending) = requests()[index] else {
            return nil
        }

        return pending
    }
}
