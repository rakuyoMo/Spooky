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

    /// 单击和提示共用一个单位，取消清空起点，上下文不改变已有状态；Shift 无起点时依次采用已选末行或块首，只添加并保留原起点；块间状态完全独立。
    @Test("单击、Shift 范围选择与独立块")
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

        // 没有起点时以块首为起点扩选
        let extending = try Self.model()
        extending.activate(at: 6, extending: true)
        #expect(extending.selected == [1, 2, 4] && extending.anchor == 0)
        extending.activate(at: 7, extending: true)
        #expect(extending.selected == [1, 2, 4, 5] && extending.anchor == 0)

        // 取消起点后以已选末行为起点
        extending.clear()
        extending.activate(at: 1)
        extending.activate(at: 3)
        extending.activate(at: 3)
        #expect(extending.selected == [1] && extending.anchor == nil)
        extending.activate(at: 7, extending: true)
        #expect(extending.selected == [1, 2, 4, 5] && extending.anchor == 2)

        // 另一块不受影响；上下文的无换行提示没有可选身份
        #expect(try Self.model().selected.isEmpty)

        let context = DiffLineSelection()
        context.bind(try DiffTextLayoutTests.hunk("@@ -1 +1 @@\n same\n\\ No newline at end of file\n"))
        context.activate(at: 1, extending: true)
        #expect(context.rows == [nil, nil] && context.selected.isEmpty)
    }

    /// 拖动方向在按下时锁定，回拖不恢复先前累计修改；上下文或 Shift 起拖时始终以最初按下位置取范围。
    @Test("拖动累计增选、取消与起拖位置")
    func dragging() throws {
        for removing in [false, true] {
            let model = try Self.model()

            if removing {
                model.activate(at: 7, extending: true)
            }

            let published = model.publishedCount
            model.begin(at: 1, extending: false)
            model.drag(to: 7)
            model.drag(to: 2)
            #expect(model.selected == (removing ? [] : [1, 2, 4, 5]))
            #expect(model.publishedCount == published)
            model.end()
            #expect(model.publishedCount == (removing ? 0 : 4))
        }

        // 从上下文起拖跨越两侧
        let context = try Self.model()
        context.begin(at: 5, extending: false)
        context.drag(to: 7)
        #expect(context.selected == [4, 5])
        context.drag(to: 1)
        #expect(context.selected == [1, 2, 4, 5])
        context.drag(to: 100)
        #expect(context.selected == [1, 2, 4, 5])
        context.end()
        #expect(context.publishedCount == 4)

        // Shift 按下先扩选，首次拖过已选行后锁定取消方向
        let shift = try Self.model()
        shift.begin(at: 3, extending: true)
        #expect(shift.selected == [1, 2] && shift.publishedCount == 0)
        shift.drag(to: 7)
        #expect(shift.selected == [1])
        shift.drag(to: 1)
        #expect(shift.selected.isEmpty)
        shift.end()
        #expect(shift.publishedCount == 0)

        // 取消的拖动不再改变选区
        let cancelled = try Self.model()
        cancelled.activate(at: 2)
        cancelled.begin(at: 3, extending: false)
        cancelled.cancelDrag()
        cancelled.drag(to: 7)
        #expect(cancelled.selected == [1, 2])
    }
}
