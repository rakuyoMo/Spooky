import AppKit
import SwiftUI

// MARK: - ChangesetFileRow

/// 变更集里的一个文件：上面是文件行，展开时下面接这个文件的 Diff。
///
/// 点文件行左侧的三角切换展开；点行里其它任何位置，包括三角的上下左右与行的上下边缘，都交给 `select`。
struct ChangesetFileRow<Label: View, Diff: View>: View {
    /// 是否展开。
    @Binding
    var isExpanded: Bool

    /// 选中时垫满整行的颜色；没有选中时为 nil。
    let selection: NSColor?

    /// 点在三角以外的位置时调用。
    let select: () -> Void

    /// 三角右侧的一栏。
    @ViewBuilder
    let label: () -> Label

    /// 展开时显示的 Diff。
    @ViewBuilder
    let diff: () -> Diff

    /// 文件行与展开的 Diff 上下相接；Diff 左右各缩进 8 pt。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded {
                diff()
                    .padding(.horizontal, 8)
            }
        }
    }

    /// 文件行：整行 38 pt 高；三角宽 13 pt、距左缘 5 pt，三角右侧的一栏从 20 pt 起，右侧留 12 pt。
    ///
    /// 三角自己接收点击，行里其它位置都算点在这一行上。
    private var header: some View {
        HStack(spacing: 2) {
            ChangesetDisclosureButton(isExpanded: $isExpanded)
                .frame(width: 13, height: 13)

            label()
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .frame(height: 38)
        .background {
            // 选中底垫满整行：左右到列表边缘，上下到两条分隔线，直角
            if let selection {
                Color(nsColor: selection)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
    }
}

// MARK: - ChangesetDisclosureButton

/// 文件行左侧的系统披露三角：点它切换展开，辅助功能里是一个披露三角。
private struct ChangesetDisclosureButton: NSViewRepresentable {
    /// 按钮的动作接收方，把按钮的新状态写回展开状态。
    @MainActor
    final class Coordinator: NSObject {
        /// 这一行的展开状态。
        var isExpanded: Binding<Bool>

        /// 创建动作接收方。
        ///
        /// - Parameter isExpanded: 这一行的展开状态。
        init(isExpanded: Binding<Bool>) {
            self.isExpanded = isExpanded
        }

        /// 点击后按钮已切换到新状态，按它写回。
        @objc
        func toggle(_ sender: NSButton) {
            isExpanded.wrappedValue = sender.state == .on
        }
    }

    /// 是否展开。
    @Binding
    var isExpanded: Bool

    /// 创建动作接收方。
    func makeCoordinator() -> Coordinator {
        Coordinator(isExpanded: $isExpanded)
    }

    /// 开 / 关两态的披露按钮，开表示展开。
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(
            title: "",
            target: context.coordinator,
            action: #selector(Coordinator.toggle(_:))
        )

        button.bezelStyle = .disclosure
        button.setButtonType(.pushOnPushOff)

        return button
    }

    /// 同步展开状态；Expand All 与菜单里的展开 / 收起也经这里改变三角的方向。
    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.isExpanded = $isExpanded
        button.state = isExpanded ? .on : .off
    }
}
