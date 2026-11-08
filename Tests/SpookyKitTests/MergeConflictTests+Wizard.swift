import Testing

@testable import SpookyKit

/// 冲突向导卡片的数据：两侧相对共同祖先的改动。
extension MergeConflictTests {
    /// 七种冲突的两侧徽标都按这一侧与共同祖先的 stage 是否存在得出。
    @Test("两侧的改动类型")
    func conflictChanges() {
        let hash = String(repeating: "a", count: 40)

        /// 只给出存在的 stage。
        func stages(base: Bool, ours: Bool, theirs: Bool) -> ConflictStages {
            ConflictStages(
                base: base ? hash : nil,
                ours: ours ? hash : nil,
                theirs: theirs ? hash : nil,
                existsInWorktree: true,
                baseMode: base ? "100644" : nil,
                oursMode: ours ? "100644" : nil,
                theirsMode: theirs ? "100644" : nil
            )
        }

        /// 我方与对方的改动。
        func changes(_ stages: ConflictStages) -> [ConflictChange] {
            [stages.change(theirs: false), stages.change(theirs: true)]
        }

        // UU、AA、DU、UD
        #expect(changes(stages(base: true, ours: true, theirs: true)) == [.modified, .modified])
        #expect(changes(stages(base: false, ours: true, theirs: true)) == [.added, .added])
        #expect(changes(stages(base: true, ours: false, theirs: true)) == [.deleted, .modified])
        #expect(changes(stages(base: true, ours: true, theirs: false)) == [.modified, .deleted])

        // AU、UA、DD
        #expect(changes(stages(base: false, ours: true, theirs: false)) == [.added, .deleted])
        #expect(changes(stages(base: false, ours: false, theirs: true)) == [.deleted, .added])
        #expect(changes(stages(base: true, ours: false, theirs: false)) == [.deleted, .deleted])
    }
}
