import AppKit
import SwiftUI

// MARK: - FileHistoryDetailPicker

/// Diff / Raw 分段选择：对象能力未知或为目录时禁用 Raw。
struct FileHistoryDetailPicker: NSViewRepresentable {
    /// 将原生动作传回最新绑定。
    final class Coordinator: NSObject {
        /// 当前模式绑定。
        var parent: FileHistoryDetailPicker

        /// 保存初始绑定。
        init(_ parent: FileHistoryDetailPicker) { self.parent = parent }

        /// 仅允许可用的原文段改变状态。
        @objc
        func changed(_ sender: NSSegmentedControl) {
            parent.mode = sender.selectedSegment == 1 && parent.allowsRaw ? .raw : .diff
        }
    }

    /// 模式改变后由历史状态读取内容。
    @Binding
    var mode: FileHistoryDetailMode

    /// 当前提交的目标能否显示原文。
    let allowsRaw: Bool

    /// 创建动作桥接。
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 使用原生标题宽度和常规尺寸。
    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: [AppLocalization.text("fileHistory.diff"), AppLocalization.text("showFile.raw")],
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.changed(_:))
        )
        configure(control)
        return control
    }

    /// 对象能力与选择同步刷新。
    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        configure(control)
    }

    /// 真实构建与更新共用的属性设置。
    func configure(_ control: NSSegmentedControl) {
        control.segmentStyle = .texturedSquare
        control.controlSize = .regular
        control.trackingMode = .selectOne
        control.selectedSegment = mode == .raw && allowsRaw ? 1 : 0
        control.setEnabled(allowsRaw, forSegment: 1)
    }
}
