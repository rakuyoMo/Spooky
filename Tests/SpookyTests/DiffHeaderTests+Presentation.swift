import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

extension DiffHeaderTests {
    /// 预览不创建块头或边线，非零 ID 不影响调用方传入的首块规则；实际只读入口按每个文件重置首块规则，独立和内嵌模式都不显示写入按钮。
    @Test("预览与只读文件的块头")
    func preview() async throws {
        let hunk = try Self.hunk(id: 9)

        for hidden in [false, true] {
            let root = VStack(spacing: 0) {
                DiffHunkView(
                    hunk: hunk,
                    style: TextStyle(theme: TextTheme.builtin[0], tabWidth: 4, showsInvisibles: false),
                    staged: false,
                    enabled: true,
                    showsHeader: !hidden,
                    presentation: .standalone,
                    hasPrecedingHunk: false
                ) { _, _ in }
            }

            let host = NSHostingView(rootView: root)
            host.frame = NSRect(x: 0, y: 0, width: 600, height: 600)
            await settle(host)

            let backgrounds = descendants(DiffHeaderBackgroundView.self, in: host)
            #expect(backgrounds.count == (hidden ? 0 : 1))
            #expect(backgrounds.allSatisfy { !$0.showsTopBorder })
            #expect(descendants(DiffHunkTextContainer.self, in: host).count == 1)
        }

        // 两个文件共三块，只有第一个文件的第二块有顶线
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        let source = CommitFileDiffSource(
            runner: fixture.runner,
            commit: try await fixture.head(),
            file: CommitFileChange(path: "a b.txt", originalPath: nil, status: "M", additions: 1, deletions: 1)
        )

        for presentation in [DiffPresentation.standalone, .embedded] {
            let host = try readOnlyHost(source: source, presentation: presentation)
            await settle(host)

            let headers = descendants(DiffHeaderBackgroundView.self, in: host)
            #expect(headers.count == 3)
            #expect(headers.filter(\.showsTopBorder).count == 1)
            #expect(headers.allSatisfy { $0.bounds.height == 32 })
            #expect(descendants(NSButton.self, in: host).isEmpty)
            #expect(host.window == nil)
        }
    }

    /// 两个文件的只读补丁，第一个文件有两块。
    private func readOnlyHost(source: CommitFileDiffSource, presentation: DiffPresentation) throws -> NSView {
        let first = "diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1 +1 @@\n-old\n+new\n"
        let second = "@@ -20 +20 @@\n-old\n+new\n"
        let patch = Data((first + second + first).utf8)
        let diff = try RepositoryDiff(patch: patch)

        let root = ScrollView {
            ReadOnlyFileDiffView(
                result: CommitDiff(byteCount: patch.count, diff: diff, onlyWhitespaceChanges: false),
                source: source,
                presentation: presentation
            ) { }
        }

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 600, height: 1200)
        return host
    }
}
