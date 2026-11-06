import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

/// 目录历史的真实文件来源、对象能力与异步读取身份。
@MainActor
struct FileHistoryDirectoryTests {
    /// 目录中多个文件各自读取，目录外与相似前缀不混入。
    @Test("目录历史按真实文件读取并禁用目录内容动作")
    func directoryDetails() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        let paths = ["dir/a.swift", "dir/b.txt", "dir-sibling/out.txt", "outside.txt"]

        for path in paths {
            let url = directory.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("let value = 1\n".utf8).write(to: url)
        }

        let root = try await commit(runner, message: "root")
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }
        session.display(runner.location)
        session.refresh(full: true)
        await session.waitForRefresh()
        session.showFileHistory("dir")
        try await FileViewsTests.wait { session.fileHistory.totalCount != nil }
        let state = session.fileHistory
        #expect(session.fileHistoryHeaderActions(root).map(\.enabled) == [false, true, true])
        state.selectedID = root.id
        try await FileViewsTests.wait { state.directory.commit != nil }
        #expect(state.directory.files.map(\.path) == ["dir/a.swift", "dir/b.txt"])
        #expect(session.fileHistoryMenuActions(root).map(\.enabled) == [false, false, true, true, true, false])

        for file in state.directory.files {
            state.directory.setVisible(file.path, visible: true, identity: state.directory.identity)
        }

        try await FileViewsTests.wait { state.directory.diffs.count == 2 }
        #expect(state.directory.diffs.values.allSatisfy { $0.diff?.files.count == 1 })
        #expect(state.directory.targets.values.allSatisfy { $0.allowsContent })
        #expect(state.directory.files.allSatisfy { state.directory.source(for: $0)?.file == $0 })
        let requests = state.directory.requests
        state.directory.setVisible("dir/a.swift", visible: true, identity: state.directory.identity)
        #expect(state.directory.requests == requests)

        // 程序请求 Raw 同样退回 Diff，不能读取 tree 对象。
        state.detailMode = .raw
        try await FileViewsTests.wait { state.detailMode == .diff && !state.isLoadingDetail }
        #expect(state.content == nil)
        #expect(state.detailFailure == nil)

        let oldIdentity = state.directory.identity
        state.loadDetail()
        try await FileViewsTests.wait { state.directory.identity != oldIdentity && state.directory.commit != nil }
        state.directory.setVisible("dir/a.swift", visible: true, identity: state.directory.identity)
        state.directory.setVisible("dir/a.swift", visible: false, identity: oldIdentity)
        state.reloadDiffs()
        try await FileViewsTests.wait { state.directory.diffs["dir/a.swift"] != nil }
        #expect(state.directory.diffs["dir/b.txt"] == nil)

        let control = NSSegmentedControl(labels: ["Diff", "Raw"], trackingMode: .selectOne, target: nil, action: nil)
        FileHistoryDetailPicker(mode: .constant(.raw), allowsRaw: false).configure(control)
        #expect(control.segmentStyle == .texturedSquare)
        #expect(control.controlSize == .regular)
        #expect(control.trackingMode == .selectOne)
        #expect(control.selectedSegment == 0)
        #expect(!control.isEnabled(forSegment: 1))
    }

    /// 当前与父版本的类型分别确定内容能力和 Diff 范围，不能只看 HEAD。
    @Test("目录与文件互换以及删除目录的能力")
    func objectTransitions() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        let node = directory.appending(path: "node")
        try Data("old\n".utf8).write(to: node)
        let fileCommit = try await commit(runner, message: "file")
        try FileManager.default.removeItem(at: node)
        try FileManager.default.createDirectory(at: node, withIntermediateDirectories: false)
        try Data("new\n".utf8).write(to: node.appending(path: "a.txt"))
        try Data("other\n".utf8).write(to: node.appending(path: "b.txt"))
        let directoryCommit = try await commit(runner, message: "directory")
        try FileManager.default.removeItem(at: node)
        try Data("again\n".utf8).write(to: node)
        let newFileCommit = try await commit(runner, message: "new file")
        try FileManager.default.removeItem(at: node)
        try FileManager.default.createDirectory(at: node, withIntermediateDirectories: false)
        try Data("restored\n".utf8).write(to: node.appending(path: "a.txt"))
        _ = try await commit(runner, message: "directory again")
        try FileManager.default.removeItem(at: node)
        let deletedCommit = try await commit(runner, message: "deleted")

        var targets: [FileHistoryTarget] = []

        for commit in [fileCommit, directoryCommit, deletedCommit, newFileCommit] {
            targets.append(try await FileHistoryTarget.load(path: "node", commit: commit, runner: runner))
        }
        #expect(targets.map(\.allowsContent) == [true, false, false, true])
        #expect(targets.map(\.needsDirectoryDiff) == [false, true, true, true])

        let changes = try await FileHistoryTarget.changes(path: "node", commit: directoryCommit, runner: runner)
        #expect(changes.map(\.path) == ["node", "node/a.txt", "node/b.txt"])
        let oldFile = try #require(changes.first)
        let oldTarget = try await FileHistoryTarget.load(
            path: oldFile.path, commit: directoryCommit, runner: runner
        )
        #expect(!oldTarget.allowsContent)
    }

    /// 大 Diff 放行按文件隔离，后台刷新衍生的可见读取不新增 Activity。
    @Test("目录逐文件放行和后台 Activity 继承")
    func largeFiles() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        let large = String(repeating: "content\n", count: 100)

        for path in ["a.txt", "b.txt"] {
            try Data(large.utf8).write(to: directory.appending(path: path))
        }

        let commit = try await commit(runner, message: "large")
        let files = try await RepositoryHistory(runner: runner).changes(in: commit.id)
        let activities = RepositoryActivities()
        let state = FileHistoryDirectoryState(warningKilobytes: { 0 })
        defer { state.close() }
        state.open(commit: commit, files: files, runner: runner, activities: activities, records: false)

        for file in files { state.setVisible(file.path, visible: true, identity: state.identity) }
        try await FileViewsTests.wait { state.diffs.count == 2 }
        #expect(state.diffs.values.allSatisfy { $0.diff == nil })
        #expect(activities.items.isEmpty)
        let secondRequest = state.requests["b.txt"]
        state.load("a.txt", showLarge: true)
        try await FileViewsTests.wait { state.diffs["a.txt"]?.diff != nil }
        #expect(state.diffs["b.txt"]?.diff == nil)
        #expect(state.requests["b.txt"] == secondRequest)
        #expect(activities.items.count == 1)
    }

    /// 目录比较使用菜单所指提交，跨目录重命名保留配对，恢复在确认前不写入。
    @Test("目录比较和恢复使用指定提交的完整文件列表")
    func comparisonAndRestore() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        try FileManager.default.createDirectory(at: directory.appending(path: "dir"), withIntermediateDirectories: false)
        try Data("first\n".utf8).write(to: directory.appending(path: "dir/a.txt"))
        try Data("second\n".utf8).write(to: directory.appending(path: "dir/b.txt"))
        let root = try await commit(runner, message: "root")
        _ = try await runner.run(["mv", "dir/a.txt", "outside.txt"])
        let moved = try await commit(runner, message: "move")
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }
        session.display(runner.location)
        session.refresh(full: true)
        await session.waitForRefresh()
        session.showFileHistory("dir")
        try await FileViewsTests.wait { session.fileHistory.totalCount != nil }
        session.fileHistory.selectedID = root.id
        try await FileViewsTests.wait { session.fileHistory.directory.commit != nil }

        let files = try await session.fileHistoryComparisonFiles(moved, path: "dir")
        #expect(files.map(\.path) == ["outside.txt"])
        #expect(files.first?.originalPath == "dir/a.txt")
        #expect(session.fileHistory.selectedID == root.id)

        var confirmation: (() -> Void)? = nil
        session.onConfirm = { confirmation = $0.action }
        session.restoreFile("dir", at: root.id)
        let confirm = try #require(confirmation)
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "dir/a.txt").path))
        confirm()
        await session.writeTask?.value
        #expect(try Data(contentsOf: directory.appending(path: "dir/a.txt")) == Data("first\n".utf8))
        #expect(try Data(contentsOf: directory.appending(path: "dir/b.txt")) == Data("second\n".utf8))
    }

    /// HEAD 删除 NFD 目录后再有无关提交，NFC 请求仍定位真实历史路径。
    @Test("已删除目录的 Unicode 历史路径回退")
    func deletedUnicodeDirectory() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        let output = try await runner.run(["hash-object", "-w", "--stdin"], input: Data("text\n".utf8))
        let blob = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
        let path = "cafe\u{301}"
        _ = try await runner.run(
            ["update-index", "--add", "-z", "--index-info"],
            input: Data("100644 blob \(blob)\t\(path)/a.txt\0".utf8)
        )
        _ = try await runner.run(["commit", "-qm", "directory"])
        _ = try await runner.run(["read-tree", "--empty"])
        _ = try await runner.run(["commit", "-qm", "delete"])
        _ = try await runner.run(["commit", "--allow-empty", "-qm", "unrelated"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let state = FileHistoryState()
        defer { state.close() }
        state.open("café", head: head, runner: runner)
        try await FileViewsTests.wait { state.totalCount != nil }
        #expect(Array((state.path ?? "").utf8) == Array(path.utf8))
        #expect(state.commits.map(\.subject) == ["delete", "directory"])
        state.selectedID = state.commits.first?.id
        try await FileViewsTests.wait { state.directory.commit != nil }
        #expect(state.directory.files.map(\.path) == [path + "/a.txt"])
    }

    /// 创建提交并通过生产解析入口读取元信息。
    private func commit(_ runner: GitRunner, message: String) async throws -> HistoryCommit {
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-qm", message])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let page = try await RepositoryHistory(runner: runner).page(roots: [head])
        return try #require(page.commits.first)
    }
}
