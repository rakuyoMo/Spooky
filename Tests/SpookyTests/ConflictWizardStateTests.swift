import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ConflictWizardStateTests

/// 冲突向导的选择与结果框：选择只在视图里，结果按选择与当前文件得出；菜单的比较项按缺少的版本禁用。
struct ConflictWizardStateTests {
    /// 单击选中、再单击取消；⌘ 单击加入另一张，不按 ⌘ 时换成只选这一张。
    /// 结果框里选择优先；没有选择时当前文件等于某侧就显示该侧，与两侧都不同且没有冲突标记是手动合并的结果，否则提示选择。
    @Test("卡片的选择与结果框的五种状态")
    func selection() {
        #expect(ConflictSide.ours.toggled(in: [], adding: false) == [.ours])
        #expect(ConflictSide.theirs.toggled(in: [.ours], adding: false) == [.theirs])
        #expect(ConflictSide.theirs.toggled(in: [.ours], adding: true) == [.ours, .theirs])

        // 再单击已选的卡片取消它，按不按 ⌘ 都一样
        #expect(ConflictSide.ours.toggled(in: [.ours], adding: false).isEmpty)
        #expect(ConflictSide.ours.toggled(in: [.ours, .theirs], adding: true) == [.theirs])

        // 结果框
        let ours = Data("ours\n".utf8)
        let theirs = Data("theirs\n".utf8)
        let marked = Data("<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> side\n".utf8)

        /// 当前文件为给定内容时的三方内容。
        func contents(_ worktree: Data?) -> ConflictContents {
            ConflictContents(base: nil, ours: ours, theirs: theirs, worktree: worktree)
        }

        #expect(ConflictResult.of(selection: [], contents: contents(marked)) == .unselected)
        #expect(ConflictResult.of(selection: [.theirs], contents: contents(marked)) == .side(.theirs))
        #expect(ConflictResult.of(selection: [.ours, .theirs], contents: contents(marked)) == .both)

        // 当前文件等于一侧时显示这一侧，选择仍然优先
        #expect(ConflictResult.of(selection: [], contents: contents(ours)) == .side(.ours))
        #expect(ConflictResult.of(selection: [], contents: contents(theirs)) == .side(.theirs))
        #expect(ConflictResult.of(selection: [.ours], contents: contents(theirs)) == .side(.ours))

        // 手动合并过且没有冲突标记；文件已不在工作区时只提示选择
        #expect(ConflictResult.of(selection: [], contents: contents(Data("merged\n".utf8))) == .current)
        #expect(ConflictResult.of(selection: [], contents: contents(nil)) == .unselected)
    }

    /// 比较用冲突的 stage 对象：删除的一侧不能与另一侧比较，双方新增没有共同祖先，不能与祖先比较。
    @Test("版本菜单的比较项")
    func comparisons() {
        let hash = String(repeating: "b", count: 40)

        /// 只给出存在的 stage 的冲突文件。
        func entry(base: Bool, ours: Bool, theirs: Bool) -> StatusEntry {
            var entry = StatusEntry(kind: .conflicted, path: "文件 [x].txt")

            entry.conflict = ConflictStages(
                base: base ? hash : nil,
                ours: ours ? hash : nil,
                theirs: theirs ? hash : nil,
                existsInWorktree: true,
                baseMode: base ? "100644" : nil,
                oursMode: ours ? "100644" : nil,
                theirsMode: theirs ? "100644" : nil
            )

            return entry
        }

        let bothAdded = entry(base: false, ours: true, theirs: true)
        let deletedByUs = entry(base: true, ours: false, theirs: true)

        #expect(WorkingCopyComparison.oursToTheirs.versions(of: bothAdded) != nil)
        #expect(WorkingCopyComparison.oursToBase.versions(of: bothAdded) == nil)
        #expect(WorkingCopyComparison.theirsToBase.versions(of: bothAdded) == nil)

        #expect(WorkingCopyComparison.oursToTheirs.versions(of: deletedByUs) == nil)
        #expect(WorkingCopyComparison.oursToBase.versions(of: deletedByUs) == nil)
        #expect(WorkingCopyComparison.theirsToBase.versions(of: deletedByUs) != nil)
    }
}
