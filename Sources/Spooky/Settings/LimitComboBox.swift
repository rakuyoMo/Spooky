import AppKit
import SwiftUI

// MARK: - LimitComboBox

/// 整数上限的组合框：可以从候选值里选，也可以直接输入整数；超出范围时取最近的边界，输入不是数字时恢复原值。
///
/// 用于 Editor 页的字数上限与 General 页的大 Diff 警告阈值。
struct LimitComboBox: NSViewRepresentable {
    /// 选中候选或结束输入时写回偏好。
    @MainActor
    final class Coordinator: NSObject, NSComboBoxDelegate {
        /// 要写回的上限。
        var value: Binding<Int>

        /// 允许的范围。
        var range: ClosedRange<Int>

        /// 创建协调器。
        init(value: Binding<Int>, range: ClosedRange<Int>) {
            self.value = value
            self.range = range
        }

        /// 选中候选值后立即生效；此时组合框的文字还没更新，取选中的候选本身。
        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard
                let box = notification.object as? NSComboBox,
                let text = box.objectValueOfSelectedItem as? String
            else { return }

            commit(text, in: box)
        }

        /// 输入结束（回车或离开输入框）时生效。
        func controlTextDidEndEditing(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox else { return }

            commit(box.stringValue, in: box)
        }

        /// 整数限制在范围内后写回；不是整数时恢复原值。
        private func commit(_ text: String, in box: NSComboBox) {
            if let number = Int(text.trimmingCharacters(in: .whitespaces)) {
                value.wrappedValue = min(max(number, range.lowerBound), range.upperBound)
            }

            box.stringValue = String(value.wrappedValue)
        }
    }

    /// 上限。
    @Binding
    var value: Int

    /// 下拉列表里的候选值。
    let choices: [Int]

    /// 允许输入的范围。
    let range: ClosedRange<Int>

    /// 辅助功能读出的名称。
    let label: String

    /// 创建可编辑、显示 5 个候选的组合框。
    func makeNSView(context: Context) -> NSComboBox {
        let box = NSComboBox()
        box.isEditable = true
        box.usesDataSource = false
        box.numberOfVisibleItems = 5

        box.addItems(withObjectValues: choices.map(String.init))
        box.stringValue = String(value)

        box.delegate = context.coordinator
        box.setAccessibilityLabel(label)

        return box
    }

    /// 不在编辑时跟随偏好的变化。
    func updateNSView(_ box: NSComboBox, context: Context) {
        context.coordinator.value = $value
        context.coordinator.range = range

        if box.currentEditor() == nil {
            box.stringValue = String(value)
        }
    }

    /// 创建接收选择与输入结束的协调器。
    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, range: range)
    }
}
