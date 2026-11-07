import Testing

@testable import Spooky

// MARK: - WorkingCopyCommitViewTests

/// 标题剩余字数：信息为空时不占位置，计数按 UTF-16 码元，组合字符与 emoji 不能按字符数代替。
struct WorkingCopyCommitViewTests {
    /// 整条信息为空或关闭计数时不显示；标题为空但正文非空时显示上限。
    @Test("剩余字数的显隐")
    func counterVisibility() {
        #expect(remaining("", "") == nil)
        #expect(remaining("", "正文") == 50)
        #expect(remaining("标题", "", isEnabled: false) == nil)
        #expect(remaining("", "正文", isEnabled: false) == nil)
    }

    /// 去掉首尾空白后按 UTF-16 码元计：emoji 占 2，组合重音单独占 1；超出上限为负数，上限至少为 1。
    @Test("剩余字数按 UTF-16 码元计")
    func counterUnits() {
        #expect(remaining("  标题  ", "") == 48)
        #expect(remaining(" A😀e\u{301} ", "") == 45)
        #expect(remaining(String(repeating: "x", count: 52), "") == -2)
        #expect(remaining("x", "", limit: 0) == 0)
    }
}

// MARK: - Helpers

extension WorkingCopyCommitViewTests {
    /// 以默认的 50 字上限计算剩余字数。
    private func remaining(_ subject: String, _ body: String, limit: Int = 50, isEnabled: Bool = true) -> Int? {
        WorkingCopyCommitView.remainingCharacters(subject: subject, body: body, limit: limit, isEnabled: isEnabled)
    }
}
