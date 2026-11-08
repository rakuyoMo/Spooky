import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

extension DiffSelectionStoreTests {
    /// 使用实际块视图重建宿主，两列行号、正文与按钮计数一起恢复；外部清空会重画。
    @Test("块视图重绑恢复选择并响应外部清空")
    func presentation() async throws {
        _ = NSApplication.shared
        let diff = try RepositoryDiff(patch: Data(Self.patch.utf8))
        let store = try Self.store(diff)
        let selection = try #require(store.selection(file: 0, hunk: 0))
        let target = store.target(file: 0, hunk: 0)
        let hunk = diff.files[0].hunks[0]
        let style = TextStyle(theme: TextTheme.builtin[0], tabWidth: 4, showsInvisibles: false)
        let helper = DiffHeaderTests()
        selection.activate(at: 0)
        selection.activate(at: 1)

        // 同一选择两次挂进新建的宿主
        for _ in 0 ..< 2 {
            let block = DiffHunkView(
                hunk: hunk,
                style: style,
                staged: false,
                enabled: true,
                selection: selection
            ) { _, _ in }

            let host = NSHostingView(rootView: ScrollView {
                LazyVStack(spacing: 0) { block }
            })

            host.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
            await helper.settle(host)

            let view = try #require(helper.descendants(DiffHunkTextContainer.self, in: host).first)
            #expect(view.gutter.selection === selection)
            #expect(view.gutter.selected == [0, 1])
            #expect(view.paintedSelection == [0, 1])
            #expect(view.content?.rows.first?.line.numbers.count == 2)
            #expect(selection.publishedCount == 2)
            #expect(block.actionTitle("stage") == AppLocalization.text("working.stageLines"))
            #expect(host.window == nil)

            // 外部清空后重画
            store.clear(target)
            await helper.settle(host)
            #expect(view.gutter.selected.isEmpty)
            #expect(view.paintedSelection.isEmpty)
            #expect(block.actionTitle("stage") == AppLocalization.text("working.stageChunk"))

            selection.activate(at: 0)
            selection.activate(at: 1)
        }
    }
}
