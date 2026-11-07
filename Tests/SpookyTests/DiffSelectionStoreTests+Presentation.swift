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
        let store = DiffSelectionStore()
        store.setScope(Self.row, side: .unstaged)
        store.reconcile(diff)
        let selection = try #require(store.selection(file: 0, hunk: 0))
        let target = store.target(file: 0, hunk: 0)
        let hunk = diff.files[0].hunks[0]
        let style = TextStyle(theme: TextTheme.builtin[0], tabWidth: 4, showsInvisibles: false)
        selection.activate(at: 0)
        selection.activate(at: 1)

        for _ in 0 ..< 2 {
            let block = DiffHunkView(hunk: hunk, style: style, staged: false, enabled: true, selection: selection) { _, _ in }
            let host = NSHostingView(rootView: ScrollView {
                LazyVStack(spacing: 0) { block }
            })
            host.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
            let helper = DiffHeaderTests()
            await helper.settle(host)
            let view = try #require(helper.descendants(DiffHunkTextContainer.self, in: host).first)
            #expect(view.gutter.selection === selection)
            #expect(view.gutter.selected == [0, 1])
            #expect(view.paintedSelection == [0, 1])
            #expect(view.content?.rows.first?.line.numbers.count == 2)
            #expect(selection.publishedCount == 2)
            let stage = AppLocalization.text("working.stageLines")
            #expect(block.actionTitle("stage") == stage)
            #expect(host.window == nil)

            store.clear(target)
            await helper.settle(host)
            #expect(view.gutter.selected.isEmpty)
            #expect(view.paintedSelection.isEmpty)
            #expect(block.actionTitle("stage") == AppLocalization.text("working.stageChunk"))
            selection.activate(at: 0)
            selection.activate(at: 1)
        }
    }

    /// 组合 Diff 的原文只服务只读解析，不建立可写模型。
    @Test("组合块没有可写选择")
    func combined() throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "SpookyKitTests/Fixtures/diff-raw-hunks.json")
        let fixtures = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]]
        let item = try #require(fixtures?.first { ($0["name"] as? String) == "combined-2-parents" })
        let encoded = try #require(item["patch"] as? String)
        let diff = try RepositoryDiff(patch: #require(Data(base64Encoded: encoded)))
        let store = DiffSelectionStore()
        store.setScope(Self.row, side: .unstaged)
        store.reconcile(diff)
        #expect(store.selection(file: 0, hunk: 0) == nil)
        #expect(store.target(file: 0, hunk: 0) == nil)
    }
}
