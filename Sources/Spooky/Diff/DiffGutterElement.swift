import AppKit
import SpookyKit

// MARK: - DiffGutterElement

/// 每个可操作逻辑行的虚拟按钮；折行与无换行提示不增加重复按钮。
final class DiffGutterElement: NSAccessibilityElement {
    /// 动作与坐标的所有者。
    private weak var owner: DiffGutterView?

    /// 原始补丁行标识。
    private let lineID: Int

    /// 创建带现有本地化标签的行号按钮。
    init(owner: DiffGutterView, line: DiffLine) {
        self.owner = owner
        lineID = line.id
        super.init()

        setAccessibilityParent(owner)
        setAccessibilityRole(.button)
        setAccessibilityLabel(AppLocalization.text("working.selectLine", line.oldNumber ?? line.newNumber ?? 0))
    }

    /// 按下走鼠标和键盘同一入口。
    override func accessibilityPerformPress() -> Bool {
        owner?.select(lineID) ?? false
    }

    /// 加载或写入期间按钮仍可读，但不能改变选择。
    override func isAccessibilityEnabled() -> Bool { owner?.enabled ?? false }

    /// 选择状态由行号栏持有。
    override func accessibilityValue() -> Any? {
        (owner?.selected.contains(lineID) ?? false) ? AppLocalization.text("working.selected") : ""
    }

    /// 虚拟按钮的屏幕范围涵盖该逻辑行的全部折行。
    override func accessibilityFrame() -> NSRect {
        guard let owner, let window = owner.window else { return .zero }

        return window.convertToScreen(owner.convert(owner.frame(for: lineID), to: nil))
    }

    /// VoiceOver 聚焦只移动焦点，不改变正文或行号选区。
    override func setAccessibilityFocused(_ focused: Bool) {
        guard focused, let owner, owner.enabled else { return }

        owner.window?.makeFirstResponder(owner)
        owner.focus(lineID)
    }

    /// 键盘焦点与辅助功能焦点使用同一逻辑行。
    override func isAccessibilityFocused() -> Bool {
        owner?.focusedID == lineID && owner?.window?.firstResponder === owner
    }
}
