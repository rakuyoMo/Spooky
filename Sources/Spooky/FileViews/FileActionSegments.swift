import AppKit
import SwiftUI

// MARK: - FileActionSegments

/// 文件头部的原生瞬时分段动作，宽度由各段本地化标题决定。
struct FileActionSegments: NSViewRepresentable {
    /// 依次排列的动作及其可用性。
    let actions: [FileViewAction]

    /// 键盘进入或离开控件时更新动作条的可见性。
    let focusChanged: (Bool) -> Void

    /// 原生控件直接保存动作，不额外建立目标代理。
    func makeNSView(context _: Context) -> FileActionSegmentControl {
        FileActionSegmentControl(actions: actions, focusChanged: focusChanged)
    }

    /// 刷新标题、可用性与闭包，保留控件的键盘焦点。
    func updateNSView(_ control: FileActionSegmentControl, context _: Context) {
        control.configure(actions: actions, focusChanged: focusChanged)
    }

    /// 优先采用标题的原生宽度，窄栏内接受宿主分配的可用宽度。
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: FileActionSegmentControl,
        context _: Context
    ) -> CGSize? {
        let intrinsic = nsView.intrinsicContentSize
        return CGSize(width: min(proposal.width ?? intrinsic.width, intrinsic.width), height: intrinsic.height)
    }
}

// MARK: - FileActionSegmentControl

/// 瞬时动作分段控件，获得键盘焦点时通知文件头部显示动作条。
final class FileActionSegmentControl: NSSegmentedControl {
    /// 当前各段执行的动作。
    private var actions: [FileViewAction] = []

    /// 头部的键盘焦点通知。
    private var focusChanged: (Bool) -> Void = { _ in }

    /// 使用原生常规尺寸与纹理圆角样式创建动作组。
    init(actions: [FileViewAction], focusChanged: @escaping (Bool) -> Void) {
        super.init(frame: .zero)

        segmentStyle = .texturedRounded
        trackingMode = .momentary
        controlSize = .regular
        segmentDistribution = .fillProportionally
        cell?.lineBreakMode = .byTruncatingMiddle
        target = self
        action = #selector(performAction)
        configure(actions: actions, focusChanged: focusChanged)
    }

    /// 控件只由代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("FileActionSegmentControl 不从归档恢复")
    }

    /// 更新真实渲染控件，零段宽表示按标题自动计算。
    func configure(actions: [FileViewAction], focusChanged: @escaping (Bool) -> Void) {
        self.actions = actions
        self.focusChanged = focusChanged
        segmentCount = actions.count

        for (index, item) in actions.enumerated() {
            setLabel(item.title, forSegment: index)
            setEnabled(item.enabled, forSegment: index)
            setWidth(0, forSegment: index)
        }

        invalidateIntrinsicContentSize()
    }

    /// 获得焦点时显示动作条，不依赖鼠标悬停。
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { focusChanged(true) }
        return accepted
    }

    /// 离开焦点后交回悬停状态控制可见性。
    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { focusChanged(false) }
        return accepted
    }

    /// 只执行当前仍然可用的分段动作。
    @objc
    private func performAction() {
        guard actions.indices.contains(selectedSegment), actions[selectedSegment].enabled else {
            return
        }

        actions[selectedSegment].perform()
    }
}
