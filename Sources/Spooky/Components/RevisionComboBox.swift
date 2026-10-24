import AppKit
import SwiftUI

// MARK: - RevisionComboBox

/// 可以直接输入、也可以从下拉列表选择的版本框；SwiftUI 没有组合框，由 NSComboBox 承担。
struct RevisionComboBox: NSViewRepresentable {
    /// 键入与选择都即时写回绑定。
    @MainActor
    final class Coordinator: NSObject, NSComboBoxDelegate {
        /// 最新的绑定与候选。
        var parent: RevisionComboBox

        /// 保存初始绑定。
        init(_ parent: RevisionComboBox) { self.parent = parent }

        /// 键入的文字写回绑定。
        func controlTextDidChange(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox else { return }

            parent.text = box.stringValue
        }

        /// 从下拉列表选中的候选写回绑定；通知早于输入框的更新，直接取所选的候选。
        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard
                let box = notification.object as? NSComboBox,
                let value = box.objectValueOfSelectedItem as? String
            else { return }

            parent.text = value
        }
    }

    /// 输入框里的版本。
    @Binding
    var text: String

    /// 下拉列表里的引用名。
    let items: [String]

    /// 读屏使用的名称。
    let label: String

    /// 键入与选择的桥接。
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 可编辑的组合框：下拉列表一次显示 5 项、行高 18 pt，键入时不自动补全。
    func makeNSView(context: Context) -> NSComboBox {
        let box = NSComboBox()
        box.font = .systemFont(ofSize: 13)
        box.numberOfVisibleItems = 5
        box.itemHeight = 18
        box.intercellSpacing = NSSize(width: 17, height: 0)
        box.delegate = context.coordinator
        return box
    }

    /// 候选或绑定变化时同步到控件；内容相同时不重写，避免打断正在进行的输入。
    func updateNSView(_ box: NSComboBox, context: Context) {
        context.coordinator.parent = self
        box.setAccessibilityLabel(label)

        if box.objectValues as? [String] != items {
            box.removeAllItems()
            box.addItems(withObjectValues: items)
        }

        if box.stringValue != text {
            box.stringValue = text
        }
    }
}
