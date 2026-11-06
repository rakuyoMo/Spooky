import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

extension DiffSelectionSessionTests {
    /// 保持同一 SwiftUI 宿主，仅替换快照；着色必须跟随新正文而非旧片段。
    @Test("新快照在同一宿主重启语法任务")
    func syntaxReload() async throws {
        _ = NSApplication.shared
        let defaults = UserDefaults.standard
        let saved = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        var arguments = saved
        arguments[TextPreferences.syntaxColoringKey] = true
        arguments[TextPreferences.diffSyntaxColoringKey] = true
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(saved, forName: UserDefaults.argumentDomain) }
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        let url = fixture.directory.appending(path: "code.swift")
        try Data("let base = 0\n".utf8).write(to: url)
        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-qm", "code"])
        try Data("let answer = 1\n".utf8).write(to: url)
        await fixture.refresh()
        let session = fixture.session
        let entry = try #require(session.status?.entries.first { $0.path == "code.swift" })
        session.selectedID = StatusRowID(path: entry.path, kind: entry.kind)
        try await FileViewsTests.wait { !session.isLoadingDiff && session.diffSnapshot?.diff != nil }
        let first = try #require(session.diffSnapshot)
        let gate = fixture.directory.appending(path: ".git")
        let runner = try gatedRunner(fixture, root: gate)
        let display = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        display.display(fixture.location)
        defer { display.close() }
        defer { try? Data().write(to: gate.appending(path: "release")) }
        let host = NSHostingView(rootView: DiffContentView(session: display, snapshot: first, diff: try #require(first.diff)))
        host.frame = NSRect(x: 0, y: 0, width: 700, height: 500)
        try await waitForColor("keyword", in: host)
        let revision = session.diffSelections.revision
        try Data("/* a comment */\n".utf8).write(to: url)
        session.loadDiff()
        try await FileViewsTests.wait { !session.isLoadingDiff && session.diffSnapshot?.fingerprint != first.fingerprint }
        let second = try #require(session.diffSnapshot)
        #expect(session.diffSelections.revision == revision)
        #expect(
            DiffContentView.SyntaxKey(fingerprint: first.fingerprint, enabled: true)
                != DiffContentView.SyntaxKey(fingerprint: second.fingerprint, enabled: true)
        )
        host.rootView = DiffContentView(session: display, snapshot: second, diff: try #require(second.diff))
        try await waitForColor("comment", in: host)

        // 旧全文已读完但尚未返回时换快照，新任务结果不能再被旧着色覆盖。
        try Data("let answer = 1\n".utf8).write(to: url)
        try Data().write(to: gate.appending(path: "arm"))
        host.rootView = DiffContentView(session: display, snapshot: first, diff: try #require(first.diff))
        try await FileViewsTests.wait {
            host.layoutSubtreeIfNeeded()
            return FileManager.default.fileExists(atPath: gate.appending(path: "started").path)
        }
        try Data("/* a comment */\n".utf8).write(to: url)
        host.rootView = DiffContentView(session: display, snapshot: second, diff: try #require(second.diff))
        host.layoutSubtreeIfNeeded()
        try Data().write(to: gate.appending(path: "release"))
        try await waitForColor("comment", in: host)
        await DiffHeaderTests().settle(host)
        try await waitForColor("comment", in: host)
        #expect(host.window == nil)
        await display.shutdown()
    }

    /// 查看真实新增行的首字颜色，等待生产语法任务更新原生文本存储。
    private func waitForColor(_ key: String, in host: NSHostingView<some View>) async throws {
        let helper = DiffHeaderTests()
        try await FileViewsTests.wait {
            host.layoutSubtreeIfNeeded()
            guard
                let view = helper.descendants(DiffHunkTextContainer.self, in: host).first,
                let row = view.content?.rows.first(where: { $0.line.prefix == 43 }),
                let storage = view.document.textStorage,
                let expected = view.style?.theme.colors[key]?.calibratedNSColor
            else { return false }

            let color = storage.attribute(.foregroundColor, at: row.range.location, effectiveRange: nil) as? NSColor
            return color == expected
        }
    }
}
