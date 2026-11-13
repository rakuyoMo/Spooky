import Testing

@testable import Spooky

// MARK: - RevisionPreviewTests

/// Checkout Revision、Reset 与 Rebase Onto 在输入停顿后读取的预览：主按钮与提交只认按当前输入读完的结果。
///
/// 等待新结果期间仍显示上一次的结果与错误，但不能拿上一次的结果提交，否则会检出、重置或变基到用户已经改掉的版本上。
struct RevisionPreviewTests {
    /// 输入变化后旧结果留着显示但不算读完，错误不先清空，晚到的旧结果也不会被当成当前输入的结果。
    @Test("输入变化后旧结果留着显示，只有当前输入的结果能提交")
    func staleResults() {
        var preview = RevisionPreview<[String], String>()

        // 还没读完任何输入：主按钮不可用
        #expect(preview.value(for: ["main", "topic"]) == nil)

        // 读完 main → topic：这组输入可以提交
        preview.show("plan for topic", for: ["main", "topic"])

        #expect(preview.value(for: ["main", "topic"]) == "plan for topic")

        // 新基点改成 topi：新结果出来之前仍显示上一次的结果，但它不是这组输入的，主按钮不可用、提交用不到它
        #expect(preview.value == "plan for topic")
        #expect(preview.value(for: ["main", "topi"]) == nil)

        // topi 读取失败：结果与错误一次替换
        preview.show(nil, error: "Not a valid revision.", for: ["main", "topi"])

        #expect(preview.value == nil)

        // 再改成 top：等待新结果期间错误区仍是 topi 的说明，不先清空
        #expect(preview.error == "Not a valid revision.")
        #expect(preview.value(for: ["main", "top"]) == nil)

        // 上一组输入晚到的结果：显示出来也不算 top 的结果
        preview.show("plan for topic", for: ["main", "topic"])

        #expect(preview.value(for: ["main", "top"]) == nil)

        // top 读完：错误清掉，这组输入可以提交
        preview.show("plan for top", for: ["main", "top"])

        #expect(preview.error.isEmpty)
        #expect(preview.value(for: ["main", "top"]) == "plan for top")
    }
}
