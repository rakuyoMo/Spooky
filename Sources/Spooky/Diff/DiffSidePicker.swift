import AppKit
import SpookyKit
import SwiftUI

// MARK: - DiffSidePicker

/// AppKit 分段控件可以分别禁用没有改动的一侧。
struct DiffSidePicker: NSViewRepresentable {
    /// 分段选择只更新模型，由详情发起异步读取。
    @MainActor
    final class Coordinator: NSObject {
        /// 最新绑定。
        var parent: DiffSidePicker

        /// 保存初始绑定。
        init(_ parent: DiffSidePicker) { self.parent = parent }

        /// 原生选择转换为比较方向。
        @objc
        func changed(_ sender: NSSegmentedControl) {
            parent.side = sender.selectedSegment == 0 ? .staged : .unstaged
        }
    }

    /// 当前暂存侧。
    @Binding
    var side: DiffSide

    /// 暂存侧是否可用。
    let staged: Bool

    /// 工作区侧是否可用。
    let unstaged: Bool

    /// 分段动作桥接。
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 保持 Staged、Unstaged 的固定顺序。
    func makeNSView(context: Context) -> NSSegmentedControl {
        NSSegmentedControl(
            labels: [AppLocalization.text("working.staged"), AppLocalization.text("working.unstaged")],
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.changed(_:))
        )
    }

    /// 刷新后没有内容的一侧立即禁用。
    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        control.selectedSegment = side == .staged ? 0 : 1
        control.setEnabled(staged, forSegment: 0)
        control.setEnabled(unstaged, forSegment: 1)
        control.setAccessibilityLabel(AppLocalization.text("working.diffSide"))
    }

}
