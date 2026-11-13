import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Export

extension HistoryListTests {
    /// 条目导出进已有的目录：目录里已有同名条目时先询问，确认前不动目标；确认后替换已有的文件；
    /// 有条目写不进目标时显示错误，详情里写出没写进去的条目。
    @Test("导出条目遇到已存在的条目先确认覆盖，部分失败写出条目")
    func exportItemsConfirmation() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        let output = try FileViewsTests.temporaryDirectory()
        let locked = output.appending(path: "locked")

        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: output)
        }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        try await Self.importCommits(["first", "second"], with: runner)

        let head = try await Self.commit(at: 0, with: runner)

        let activities = RepositoryActivities()
        let session = RepositorySession(
            makeRunner: { _ in runner },
            loadStatus: { _ in try await runner.status() },
            activities: activities
        )
        defer { session.close() }

        var requests: [ConfirmationRequest] = []
        var failures: [AppFailure] = []
        session.onConfirm = { requests.append($0) }
        session.onFailure = { failures.append($0) }
        session.display(location)

        // 目标里已有同名文件：先询问，确认前不执行导出、不动已有的文件
        let target = output.appending(path: "file.txt")
        try Data("old\n".utf8).write(to: target)

        session.confirmExport(head.id, paths: ["file.txt"], into: output)

        let request = try #require(requests.first)

        #expect(request.title == AppLocalization.text("export.exists.title"))
        #expect(request.submitTitle == AppLocalization.text("export.overwrite"))
        #expect(activities.items.isEmpty)
        #expect(try String(contentsOf: target, encoding: .utf8) == "old\n")

        // 确认后替换已有的文件
        request.action()
        await until { activities.items.first?.state == "activity.finished" }

        #expect(try String(contentsOf: target, encoding: .utf8) == "1\n")

        // 目标里没有同名条目时直接导出；只读目录里写不进去的条目写进错误详情
        try FileManager.default.removeItem(at: target)
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)

        session.confirmExport(head.id, paths: ["file.txt"], into: locked)
        await until { !failures.isEmpty }

        #expect(requests.count == 1)
        #expect(failures.first?.title == AppLocalization.text("export.error.partial"))
        #expect(failures.first?.details.hasPrefix("file.txt: ") ?? false)
    }
}
