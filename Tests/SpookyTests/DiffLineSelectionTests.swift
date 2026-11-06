import AppKit
import Testing

@testable import Spooky
@testable import SpookyKit

/// 行选择以显示位置定位范围，以逻辑行标识写入；鼠标计数只在松开时发布。
@MainActor
struct DiffLineSelectionTests {
    /// 上下文、两个无换行提示和第二组修改，显示映射含重复逻辑标识。
    static let patch = #"""
    @@ -1,5 +1,5 @@
     first
    -old
    \ No newline at end of file
    +new
    \ No newline at end of file
     middle
    -before
    +after
     last

    """#

    /// 初始化实际字体环境，不创建窗口。
    init() { _ = NSApplication.shared }

    /// 建立与生产文本区相同的显示映射。
    static func model() throws -> DiffLineSelection {
        let selection = DiffLineSelection()
        selection.bind(try DiffTextLayoutTests.hunk(patch))
        return selection
    }

    /// 单击和提示共用一个单位，取消清空起点，上下文不改变已有状态。
    @Test("单击、提示与范围起点")
    func clicking() throws {
        let model = try Self.model()
        #expect(model.rows == [nil, 1, 1, 2, 2, nil, 4, 5, nil])
        model.begin(at: 1, extending: false)
        #expect(model.selected == [1] && model.publishedCount == 0 && model.anchor == 1)
        model.end()
        #expect(model.publishedCount == 1)
        model.activate(at: 0)
        #expect(model.selected == [1] && model.anchor == 1)
        model.activate(at: 2)
        #expect(model.selected.isEmpty && model.anchor == nil && model.publishedCount == 0)
        model.activate(at: 4)
        #expect(model.selected == [2] && model.anchor == 4 && model.publishedCount == 1)
    }

    /// 无起点时依次采用已选末行或块首，范围选择只添加并保留原起点。
    @Test("Shift 范围选择与后备起点")
    func extending() throws {
        let model = try Self.model()
        model.activate(at: 6, extending: true)
        #expect(model.selected == [1, 2, 4] && model.anchor == 0)
        model.activate(at: 7, extending: true)
        #expect(model.selected == [1, 2, 4, 5] && model.anchor == 0)
        model.clear()
        model.activate(at: 1)
        model.activate(at: 3)
        model.activate(at: 3)
        #expect(model.selected == [1] && model.anchor == nil)
        model.activate(at: 7, extending: true)
        #expect(model.selected == [1, 2, 4, 5] && model.anchor == 2)
    }

    /// 拖动方向在按下时锁定，回拖不恢复先前累计修改。
    @Test("拖动累计增选和取消", arguments: [false, true])
    func dragging(removing: Bool) throws {
        let model = try Self.model()
        if removing { model.activate(at: 7, extending: true) }
        let published = model.publishedCount
        model.begin(at: 1, extending: false)
        model.drag(to: 7)
        model.drag(to: 2)
        #expect(model.selected == (removing ? [] : [1, 2, 4, 5]))
        #expect(model.publishedCount == published)
        model.end()
        #expect(model.publishedCount == (removing ? 0 : 4))
    }

    /// 从上下文起拖跨越两侧时，始终以最初按下位置取范围。
    @Test("上下文起拖保留初始位置")
    func contextDrag() throws {
        let model = try Self.model()
        model.begin(at: 5, extending: false)
        model.drag(to: 7)
        #expect(model.selected == [4, 5])
        model.drag(to: 1)
        #expect(model.selected == [1, 2, 4, 5])
        model.drag(to: 100)
        #expect(model.selected == [1, 2, 4, 5])
        model.end()
        #expect(model.publishedCount == 4)
    }

    /// Shift 按下先扩选，首次拖过已选行后锁定取消方向，回拖仍以最初位置为准。
    @Test("Shift 起拖与回拖")
    func shiftDrag() throws {
        let model = try Self.model()
        model.begin(at: 3, extending: true)
        #expect(model.selected == [1, 2] && model.publishedCount == 0)
        model.drag(to: 7)
        #expect(model.selected == [1])
        model.drag(to: 1)
        #expect(model.selected.isEmpty)
        model.end()
        #expect(model.publishedCount == 0)
    }

    /// 上下文的无换行提示没有可选身份，块间状态完全独立。
    @Test("上下文提示与独立块")
    func boundaries() throws {
        let first = try Self.model()
        let second = try Self.model()
        first.activate(at: 2)
        #expect(second.selected.isEmpty && second.anchor == nil)
        let context = DiffLineSelection()
        context.bind(try DiffTextLayoutTests.hunk("@@ -1 +1 @@\n same\n\\ No newline at end of file\n"))
        context.activate(at: 1, extending: true)
        #expect(context.rows == [nil, nil] && context.selected.isEmpty)
        first.begin(at: 3, extending: false)
        first.cancelDrag()
        first.drag(to: 7)
        #expect(first.selected == [1, 2])
    }
}
