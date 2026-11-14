import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ConflictWizardStateTests

/// 冲突向导的选择与结果框：选择只在视图里，结果按选择与当前文件得出；菜单的比较项按缺少的版本禁用。
struct ConflictWizardStateTests {
    /// 单击切换这一张的选中，不看 ⌘：选了一张再单击另一张是两张都选，再单击已选的一张取消它。
    /// 结果框：单击过卡片时按选择；还没有单击时，双方修改与双方新增的当前文件等于某侧就显示该侧并画成选中，
    /// 修改 / 删除冲突打开时保持未选；与两侧都不同且没有冲突标记是手动合并的结果，否则提示选择。
    @Test("卡片的选择与结果框的状态")
    func selection() {
        #expect(ConflictSide.ours.toggled(in: []) == [.ours])
        #expect(ConflictSide.theirs.toggled(in: [.ours]) == [.ours, .theirs])
        #expect(ConflictSide.ours.toggled(in: [.ours, .theirs]) == [.theirs])
        #expect(ConflictSide.ours.toggled(in: [.ours]).isEmpty)

        let ours = Data("ours\n".utf8)
        let theirs = Data("theirs\n".utf8)
        let marked = Data("<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> side\n".utf8)

        /// 当前文件为给定内容、冲突类型为给定类型时的结果。
        func result(
            _ selection: Set<ConflictSide>?,
            worktree: Data?,
            kind: ConflictKind = .bothModified
        ) -> ConflictResult {
            ConflictResult.of(
                selection: selection,
                contents: ConflictContents(base: nil, ours: ours, theirs: theirs, worktree: worktree),
                kind: kind
            )
        }

        #expect(result(nil, worktree: marked) == .unselected)
        #expect(result([.theirs], worktree: marked) == .side(.theirs))
        #expect(result([.ours, .theirs], worktree: marked).highlighted == [.ours, .theirs])

        // 当前文件等于一侧时显示这一侧并画成选中；单击过卡片后按选择，全部取消后不再回到这一侧
        #expect(result(nil, worktree: ours) == .side(.ours))
        #expect(result(nil, worktree: theirs, kind: .bothAdded).highlighted == [.theirs])
        #expect(result([.ours], worktree: theirs) == .side(.ours))
        #expect(result([], worktree: ours) == .unselected)

        // 修改 / 删除冲突打开时保持未选
        #expect(result(nil, worktree: theirs, kind: .deletedByUs) == .unselected)
        #expect(result(nil, worktree: ours, kind: .deletedByThem).highlighted.isEmpty)

        // 手动合并过且没有冲突标记；文件已不在工作区时只提示选择
        #expect(result(nil, worktree: Data("merged\n".utf8)) == .current)
        #expect(result(nil, worktree: nil) == .unselected)
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
