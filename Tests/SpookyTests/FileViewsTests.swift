import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 文件历史、原文与 Blame 的会话状态：入口切换视图、跟随 HEAD、回到提交、恢复与 Unicode 路径。
@MainActor
struct FileViewsTests {
    /// 测试独占的临时目录。
    static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-file-views-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    /// 忽略系统与用户的全局配置，提交身份只写入仓库本地配置。
    static func initializeRepository(at location: RepositoryLocation) async throws -> GitRunner {
        let runner = GitRunner(
            location: location,
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )

        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        _ = try await runner.run(["config", "--local", "commit.gpgSign", "false"])

        return runner
    }

    /// 两个颜色换算到 sRGB 后各分量相差不超过 1 / 255。
    private static func sameColor(_ left: NSColor, _ right: NSColor) -> Bool {
        guard let left = left.usingColorSpace(.sRGB), let right = right.usingColorSpace(.sRGB) else {
            return false
        }

        let pairs = [
            (left.redComponent, right.redComponent),
            (left.greenComponent, right.greenComponent),
            (left.blueComponent, right.blueComponent),
            (left.alphaComponent, right.alphaComponent),
        ]

        return pairs.allSatisfy { abs($0.0 - $0.1) <= 1 / 255 }
    }

    /// 等待异步读取完成，超时视为失败。
    ///
    /// 本机仓库的 Git 命令在测试进程里共用一组主机槽，整套测试并行时读取要排队，等待上限按整套测试的耗时留足。
    static func wait(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while !condition() {
            guard .now < deadline else {
                Issue.record("等待文件视图读取超时")
                return
            }

            try await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Git 的行与文本排版的行必须一一对应，行号和 Blame 注释才不会错位。
    @Test("原文按换行字节切分，行内会被排版成换行的字符被替换")
    func displayLines() {
        let data = Data("a\r\nb\rc\u{2028}d\n\ne\n".utf8)

        #expect(FileRevisionContent.displayLines(data) == ["a", "b\u{FFFD}c\u{FFFD}d", "", "e"])
        #expect(FileRevisionContent.displayLines(Data("last".utf8)) == ["last"])
        #expect(FileRevisionContent.displayLines(Data()).isEmpty)
        #expect(FileRevisionContent.displayLine("tab\tkept\r") == "tab\tkept")
    }

    /// 原文与 Blame 的正文和 Diff 用同一套渲染：制表符按 Tab 宽度展开，语法片段换成主题颜色，没有片段的部分用正文色。
    @Test("原文按 Tab 宽度展开并套用语法颜色")
    func textRendering() throws {
        let theme = TextTheme.builtin[0]
        let style = FileTextStyle(theme: theme)
        let document = FileTextDocumentView.make()

        // 第一行依次是制表符、关键字与其余文字，第二行没有片段
        let spans = [[
            SyntaxSpan(length: 1, style: nil),
            SyntaxSpan(length: 3, style: .keyword),
            SyntaxSpan(length: 6, style: nil),
        ]]

        document.show(
            ["\tlet x = 1", "plain"],
            style: style,
            rendering: TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false),
            spans: spans
        )

        let storage = try #require(document.textStorage)
        #expect(storage.string == "    let x = 1\nplain")

        let keyword = try #require(storage.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor)
        let expected = try #require(theme.colors["keyword"]?.nsColor)
        #expect(Self.sameColor(keyword, expected))

        let plain = try #require(storage.attribute(.foregroundColor, at: 15, effectiveRange: nil) as? NSColor)
        #expect(Self.sameColor(plain, style.text))
    }

    /// 单击注释按行找到所在的段；段外的行没有归属。
    @Test("按行查找 Blame 段")
    func groupLookup() {
        let annotations = FileTextAnnotations(
            groups: [
                BlameGroup(commitID: "aaaa", firstLine: 1, lineCount: 3, originalLine: 1),
                BlameGroup(commitID: "bbbb", firstLine: 4, lineCount: 1, originalLine: 2),
                BlameGroup(commitID: "aaaa", firstLine: 5, lineCount: 2, originalLine: 4),
            ],
            commits: [:],
            highlightedCommit: nil
        )

        #expect([1, 3, 4, 5, 6].map(annotations.groupIndex(containing:)) == [0, 0, 1, 2, 2])
        #expect(annotations.groupIndex(containing: 7) == nil)
        #expect(annotations.groupIndex(containing: 0) == nil)
    }

    /// 行号栏按最大行号的文字宽度留出位置；Blame 的注释栏取保存的宽度，超出可拖动范围的记录按边界处理。
    @Test("行号栏与注释栏的宽度")
    func gutterWidths() throws {
        let key = FileGutterView.annotationWidthKey
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }

        let theme = TextTheme.builtin[0]
        let style = FileTextStyle(theme: theme)
        let rendering = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false)
        let lines = (1 ... 1234).map(String.init)
        let annotations = FileTextAnnotations(
            groups: [BlameGroup(commitID: "aaaa", firstLine: 1, lineCount: lines.count, originalLine: 1)],
            commits: [:],
            highlightedCommit: nil
        )

        // 1234 行时行号栏是 “1234” 的宽度加两侧各 10 pt
        let digits = NSAttributedString(string: "1234", attributes: [.font: style.font]).size().width
        let lineNumbers = digits.rounded(.up) + 20

        // 每种保存的宽度都建一个新的标尺，按偏好取初始宽度
        let thickness: (Any?, FileTextAnnotations?) -> CGFloat = { value, annotations in
            UserDefaults.standard.set(value, forKey: key)

            let document = FileTextDocumentView.make()
            let scroll = NSScrollView()
            scroll.documentView = document
            document.show(lines, style: style, rendering: rendering, spans: nil)

            let gutter = FileGutterView(scrollView: scroll, document: document)
            gutter.update(lineCount: lines.count, annotations: annotations)

            return gutter.ruleThickness
        }

        #expect(thickness(nil, nil) == lineNumbers)
        #expect(thickness(nil, annotations) == FileGutterView.defaultAnnotationWidth + lineNumbers)
        #expect(thickness(300.0, annotations) == 300 + lineNumbers)
        #expect(thickness(1000.0, annotations) == 600 + lineNumbers)
        #expect(thickness(100.0, annotations) == 175 + lineNumbers)
    }

    /// 回到的提交不在已加载的分页里时，整页详情仍然显示它，重读分页也不会丢掉选择。
    @Test("回到不在已加载分页里的提交")
    func revealUnloadedCommit() {
        let history = RepositoryHistoryState()
        let commit = HistoryCommit(
            id: String(repeating: "a", count: 40),
            tree: String(repeating: "b", count: 40),
            parents: [],
            author: "Alice",
            authorEmail: "alice@example.invalid",
            authorDate: Date(timeIntervalSince1970: 0),
            committer: "Alice",
            committerEmail: "alice@example.invalid",
            commitDate: Date(timeIntervalSince1970: 0),
            message: "标题\n\n正文"
        )

        history.reveal(commit)

        #expect(history.commits.isEmpty)
        #expect(history.showsCommitPage)
        #expect(history.selectedCommit == commit)

        // 多选或换选其它提交后不再沿用回到的记录
        history.selectedIDs = []
        #expect(history.selectedCommit == nil)
    }

    /// 入口切换到文件视图，文件历史按 NFC 请求时找到树中的 NFD 文件；离开仓库再回来时显示历史。
    @Test("文件历史、回到提交、NFD 路径与视图状态")
    func historyFlow() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await Self.initializeRepository(at: location)
        let decomposed = "caf\u{65}\u{301}.txt"

        // 树中以 NFD 存储，工作区的状态里是 NFC 形式的未跟踪文件
        let blob = try await runner.run(["hash-object", "-w", "--stdin"], input: Data("one\n".utf8))
        let id = String(decoding: blob, as: UTF8.self).trimmingCharacters(in: .newlines)
        _ = try await runner.run(
            ["update-index", "--add", "-z", "--index-info"],
            input: Data("100644 blob \(id)\t\(decomposed)\0".utf8)
        )
        _ = try await runner.run(["commit", "-q", "-m", "添加"])

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        var switches = 0
        session.onActiveViewChange = { switches += 1 }
        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()

        session.showFileHistory(decomposed.precomposedStringWithCanonicalMapping)
        #expect(session.activeView == .fileHistory)
        #expect(switches == 1)

        try await Self.wait { session.fileHistory.totalCount != nil }
        #expect(session.fileHistory.commits.map(\.subject) == ["添加"])
        #expect(Array((session.fileHistory.path ?? "").utf8) == Array(decomposed.utf8))

        // 双击回到提交：核对它在历史里的位置后切到历史并打开整页详情
        let commit = try #require(session.fileHistory.commits.first)
        session.showCommit(commit)
        try await Self.wait { session.activeView == .history }
        #expect(session.history.showsCommitPage)
        #expect(session.history.selectedCommit?.id == commit.id)

        // 文件视图的目标不随仓库保存，切回仓库时显示历史
        session.showFileHistory(decomposed)
        let other = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: other) }

        session.display(.local(path: other.path))
        session.display(location)
        #expect(session.activeView == .history)
        #expect(session.fileHistory.path == nil)
    }

    /// 跟随 HEAD 的 Blame 在提交后重读；选定的版本不随 HEAD 变化。
    @Test("Blame 跟随 HEAD，恢复到某个版本需要确认")
    func blameFollowsHead() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await Self.initializeRepository(at: location)
        let file = directory.appending(path: "a [*].txt")
        try Data("one\n".utf8).write(to: file)
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "first"])
        let first = try await RepositoryReferences(runner: runner).resolve("HEAD")

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()

        session.showFile("a [*].txt", at: nil, mode: .blame)
        #expect(session.activeView == .fileContent)
        try await Self.wait { session.fileContent.blame != nil }
        #expect(session.fileContent.blameLines == ["one"])
        #expect(session.fileContent.contributors?.map(\.name) == ["Spooky Test"])

        // 提交新的一行后完整刷新，Blame 读取新的 HEAD
        try Data("one\ntwo\n".utf8).write(to: file)
        _ = try await runner.run(["commit", "-q", "-a", "-m", "second"])
        session.refresh(full: true)
        await session.waitForRefresh()
        try await Self.wait { session.fileContent.blame?.lines == ["one", "two"] }
        #expect(Set(session.fileContent.blame?.groups.map(\.commitID) ?? []).count == 2)

        // 恢复到第一个版本：确认说明写出文件与仓库位置，确认后才写入
        var confirmation: (message: String, action: () -> Void)? = nil
        session.onConfirm = { _, message, action, _ in confirmation = (message, action) }
        session.restoreFile("a [*].txt", at: first)

        let confirm = try #require(confirmation)
        #expect(confirm.message.contains("a [*].txt"))
        #expect(confirm.message.contains(directory.path))
        #expect(try Data(contentsOf: file) == Data("one\ntwo\n".utf8))

        confirm.action()
        await session.writeTask?.value
        #expect(try Data(contentsOf: file) == Data("one\n".utf8))
    }
}
