import AppKit
import SwiftUI

// MARK: - FittedSegmentedPicker

/// 详情与仓库设置头部的分段选择：每段按自己的标题定宽，不取最宽的一段。
struct FittedSegmentedPicker<Value: Hashable>: NSViewRepresentable {
    /// 选中的段。
    @Binding
    var selection: Value

    /// 各段的值与标题，按显示顺序。
    let options: [(value: Value, title: String)]

    /// 整个分段控件的辅助功能名称。
    let accessibilityLabel: String

    /// 接收原生控件动作的对象。
    func makeCoordinator() -> SegmentTarget {
        SegmentTarget()
    }

    /// 按标题定宽的常规尺寸分段控件。
    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: options.map(\.title),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(SegmentTarget.changed(_:))
        )

        control.segmentDistribution = .fit
        control.controlSize = .regular
        update(control, coordinator: context.coordinator)
        return control
    }

    /// 标题、选中段与动作跟着最新的值。
    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        update(control, coordinator: context.coordinator)
    }
}

// MARK: - SegmentTarget

/// 分段控件的动作目标：把选中的段号交给当前的处理。
@MainActor
final class SegmentTarget: NSObject {
    /// 选中段变化后的处理。
    var change: (Int) -> Void = { _ in }

    /// 原生控件的动作。
    @objc
    func changed(_ sender: NSSegmentedControl) {
        change(sender.selectedSegment)
    }
}

// MARK: - Private

extension FittedSegmentedPicker {
    /// 写入标题、选中段、辅助功能名称与动作。
    private func update(_ control: NSSegmentedControl, coordinator: SegmentTarget) {
        for (index, option) in options.enumerated() where index < control.segmentCount {
            control.setLabel(option.title, forSegment: index)
        }

        control.selectedSegment = options.firstIndex { $0.value == selection } ?? -1
        control.setAccessibilityLabel(accessibilityLabel)

        let binding = $selection
        let values = options.map(\.value)

        coordinator.change = { index in
            guard values.indices.contains(index) else {
                return
            }

            binding.wrappedValue = values[index]
        }
    }
}
