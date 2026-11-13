import AppKit
import QuartzCore
import SwiftUI

// MARK: - DialogAnimation

/// 对话框显示期间内容变化的动画：0.2 s ease-out，窗口边缘与内容同时开始、同时结束；应用级模态窗口里一次到位。
///
/// 骨架自己的输入（说明、错误区、底栏的进度）变化时由骨架带上这段动画；
/// 各对话框内容区里会改变高度的状态都经 `perform(_:)` 修改，同一次修改里的几处变化合成一段动画。
@MainActor
enum DialogAnimation {
    /// 动画时长，窗口与内容共用。
    static let duration: TimeInterval = 0.2

    /// 当前应使用的动画；应用级模态窗口里为 nil。
    static var current: Animation? {
        NSApp.modalWindow == nil ? .easeOut(duration: duration) : nil
    }

    /// 在对话框的动画里修改状态。
    ///
    /// - Parameter body: 修改状态的动作。
    /// - Returns: 动作的返回值。
    static func perform<Result>(_ body: () throws -> Result) rethrows -> Result {
        try withAnimation(current, body)
    }
}

// MARK: - DialogSizing

/// 对话框窗口的尺寸跟随内容：骨架报上内容的理想尺寸，窗口以 `DialogAnimation` 的缓动改到这个尺寸。
///
/// 改尺寸时保持顶边；挂成 sheet 时系统会把 sheet 重新摆到父窗口的竖直中线上，变高时上下两边各动一半。
/// 窗口还没显示或在应用级模态里时一次到位。
@MainActor
final class DialogSizing {
    /// 不限尺寸的提议：骨架按它给出理想尺寸。
    static let unconstrained = CGSize(width: CGFloat.infinity, height: CGFloat.infinity)

    /// 对话框所在的窗口。
    private weak var window: NSWindow? = nil

    /// 是否按内容的最小尺寸约束窗口；由 `DialogWindow` 接到可以拉大的窗口的托管控制器上。
    var tracksMinimumSize: ((Bool) -> Void)? = nil

    /// 可以拉大的对话框收起选项区之前的内容高度，再展开时回到这个高度。
    private var heightBeforeCollapse: CGFloat? = nil

    /// 创建窗口的尺寸跟随。
    ///
    /// - Parameter window: 对话框所在的窗口。
    init(window: NSWindow) {
        self.window = window
    }

    /// 把窗口的内容区改成内容的理想尺寸；尺寸不变时什么也不做。
    ///
    /// - Parameter size: 内容的理想尺寸。
    func fit(_ size: CGSize) {
        guard let window else {
            return
        }

        let current = window.contentRect(forFrameRect: window.frame).size

        guard abs(current.width - size.width) > 0.5 || abs(current.height - size.height) > 0.5 else {
            return
        }

        resize(window, toContentSize: size)
    }

    /// 可以拉大的对话框切换选项区：收起时窗口减去选项区的高度，再展开时回到收起前的高度。
    ///
    /// 切换期间暂停按内容的最小尺寸约束窗口，否则展开时窗口会先跳到新的最小高度。
    ///
    /// - Parameters:
    ///   - expanded: 切换后选项区是否展开。
    ///   - optionsHeight: 选项区展开时的高度。
    func toggleOptions(expanded: Bool, optionsHeight: CGFloat) {
        guard let window else {
            return
        }

        let current = window.contentRect(forFrameRect: window.frame).size
        var target = current

        if expanded {
            target.height = heightBeforeCollapse ?? current.height + optionsHeight
            heightBeforeCollapse = nil
        } else {
            heightBeforeCollapse = current.height
            target.height = current.height - optionsHeight
        }

        tracksMinimumSize?(false)

        resize(window, toContentSize: target) { [weak self] in
            self?.tracksMinimumSize?(true)
        }
    }
}

// MARK: - Private

extension DialogSizing {
    /// 保持顶边与水平中线改窗口的尺寸；窗口可见且不在应用级模态里时做动画。
    private func resize(_ window: NSWindow, toContentSize size: CGSize, completion: (@MainActor () -> Void)? = nil) {
        let content = NSRect(origin: .zero, size: size)
        var frame = window.frameRect(forContentRect: content)

        // AppKit 的坐标原点在左下角，保持顶边即新的原点等于原顶边减去新高度
        frame.origin.x = window.frame.midX - frame.width / 2
        frame.origin.y = window.frame.maxY - frame.height

        guard window.isVisible, DialogAnimation.current != nil else {
            window.setFrame(frame, display: true)
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = DialogAnimation.duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(frame, display: true)
        } completionHandler: {
            MainActor.assumeIsolated { completion?() }
        }
    }
}

// MARK: - EnvironmentValues + DialogSizing

extension EnvironmentValues {
    /// 对话框所在窗口的尺寸跟随；不经 `DialogWindow` 呈现时为 nil，窗口尺寸由呈现方决定。
    @Entry
    var dialogSizing: DialogSizing? = nil
}
