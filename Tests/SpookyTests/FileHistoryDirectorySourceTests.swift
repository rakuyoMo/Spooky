import AppKit
import Testing

@testable import Spooky
@testable import SpookyKit

/// 目录详情中的语法与图片必须读取对应文件的实际对象。
@MainActor
struct FileHistoryDirectorySourceTests {
    /// 不同语言和二进制图片在同次提交里各自保留前后内容。
    @Test("目录逐文件来源读取实际语法和图片对象")
    func sources() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        let folder = directory.appending(path: "dir")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let oldImage = try image(red: 255)
        let newImage = try image(red: 0)
        try #require(oldImage != newImage)
        try Data("let value = 1\n".utf8).write(to: folder.appending(path: "code.swift"))
        try Data("# Heading\n".utf8).write(to: folder.appending(path: "notes.md"))
        try Data("plain text\n".utf8).write(to: folder.appending(path: "plain.txt"))
        try oldImage.write(to: folder.appending(path: "image.png"))
        _ = try await commit(runner)
        try Data("let value = 2\n".utf8).write(to: folder.appending(path: "code.swift"))
        try Data("## Other\n".utf8).write(to: folder.appending(path: "notes.md"))
        try Data("other text\n".utf8).write(to: folder.appending(path: "plain.txt"))
        try newImage.write(to: folder.appending(path: "image.png"))
        let head = try await commit(runner)
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }
        session.display(runner.location)
        session.refresh(full: true)
        await session.waitForRefresh()
        session.showFileHistory("dir")
        try await FileViewsTests.wait { session.fileHistory.totalCount != nil }
        session.fileHistory.selectedID = head.id
        let state = session.fileHistory.directory
        try await FileViewsTests.wait { state.commit != nil || session.fileHistory.detailFailure != nil }
        try #require(session.fileHistory.detailFailure == nil)
        try #require(state.files.count == 4)

        for file in state.files { state.setVisible(file.path, visible: true, identity: state.identity) }
        try await FileViewsTests.wait { state.diffs.count == 4 }

        let defaults = UserDefaults.standard
        let keys = [TextPreferences.syntaxColoringKey, TextPreferences.diffSyntaxColoringKey]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        for key in keys { defaults.set(true, forKey: key) }

        for file in state.files {
            let source = try #require(state.source(for: file))
            let diff = try #require(state.diffs[file.path]?.diff)

            if file.path.hasSuffix(".png") {
                let contents = try await source.imageContents(of: #require(diff.files.first))
                #expect(contents.old == oldImage)
                #expect(contents.new == newImage)
                #expect(await source.syntax(for: diff) == nil)
            } else if file.path.hasSuffix(".txt") {
                #expect(await source.syntax(for: diff) == nil)
            } else {
                let syntax = try #require(await source.syntax(for: diff))
                let style: SyntaxStyle = file.path.hasSuffix(".swift") ? .keyword : .heading
                #expect(syntax.old.flatMap { $0 }.contains { $0.style == style })
                #expect(syntax.new.flatMap { $0 }.contains { $0.style == style })
            }
        }
    }

    /// 移入、移出与目录内改名使用完整清单，保留两侧路径。
    @Test("目录历史覆盖三个移动方向", arguments: [
        ("outside.txt", "dir/inside.txt"),
        ("dir/inside.txt", "outside.txt"),
        ("dir/inside.txt", "dir/renamed.txt"),
    ])
    func moves(paths: (String, String)) async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        try FileManager.default.createDirectory(at: directory.appending(path: "dir"), withIntermediateDirectories: false)
        try Data("unchanged content\n".utf8).write(to: directory.appending(path: paths.0))
        _ = try await commit(runner)
        _ = try await runner.run(["mv", paths.0, paths.1])
        let head = try await commit(runner)
        let files = try await FileHistoryTarget.changes(path: "dir", commit: head, runner: runner)
        #expect(files.count == 1)
        #expect(files.first?.path == paths.1)
        #expect(files.first?.originalPath == paths.0)
        let file = try #require(files.first)
        let diff = try await RepositoryHistory(runner: runner).diff(in: head.id, file: file)
        #expect(diff.diff?.files.count == 1)

        // 两侧缓存经实际子进程读取，重命名的左侧不能取新路径。
        let cache = RepositoryFileCache(runner: runner)
        defer { cache.removeAll() }
        let service = ExternalToolFiles(cache: cache)
        let left = try await service.file(paths.0, at: .commit(#require(head.parents.first)))
        let right = try await service.file(paths.1, at: .commit(head.id))
        let output = directory.appending(path: "compared")
        try await ExternalToolLauncher.run(ExternalToolInvocation(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "cat \"$1\" \"$2\" > \"$3\"", "compare", left.path, right.path, output.path]
        ))
        #expect(try Data(contentsOf: output) == Data("unchanged content\nunchanged content\n".utf8))
    }

    /// PNG 数据由本机位图生成，不依赖外部素材。
    private func image(red: Int) throws -> Data {
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 4, bitsPerPixel: 32
        ))
        var pixel = [red, 0, 255, 255]
        bitmap.setPixel(&pixel, atX: 0, y: 0)
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    /// 通过真实 Git 创建并解析提交。
    private func commit(_ runner: GitRunner) async throws -> HistoryCommit {
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-qm", "content"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        return try #require(try await RepositoryHistory(runner: runner).page(roots: [head]).commits.first)
    }
}
