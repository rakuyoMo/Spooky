import AppKit
import SpookyKit
import SwiftUI

// MARK: - DiffBottomBar

/// Diff 底栏：左侧两个开关，中间是块数与增删行数，右侧是上下文行数。
struct DiffBottomBar: View {
    /// 显示整个文件属于当前会话的视图状态。
    @Bindable
    var session: RepositorySession

    /// 统计来源。
    let diff: RepositoryDiff

    /// 全局的忽略空白偏好。
    @AppStorage(DiffPreferences.ignoresWhitespaceKey)
    private var ignoresWhitespace = false

    /// 全局的上下文行数偏好。
    @AppStorage(DiffPreferences.contextLinesKey)
    private var contextLines = DiffOptions.defaultContextLines

    /// 32 pt 高的材质底栏。
    var body: some View {
        DiffBottomBarLayout {
            toggles

            Text(DiffSummary.statistics(in: diff.files))
                .lineLimit(1)
                .truncationMode(.tail)
                .clipped()

            HStack(spacing: 4) {
                Text(AppLocalization.text("diff.context"))

                // 显示整个文件时同样可选
                ContextLinesPopUp(value: $contextLines)
            }
            .fixedSize()
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(height: 32)
        .background(.bar)
    }

    /// 左侧显示开关组成固定宽度的一组。
    private var toggles: some View {
        HStack(spacing: 4) {
            toggle("diff.ignoreWhitespace", symbol: "nosign", isOn: $ignoresWhitespace)

            toggle(
                "diff.showEntireFile",
                symbol: "arrow.up.and.down.text.horizontal",
                isOn: Binding(
                    get: { session.diffShowsEntireFile },
                    set: {
                        session.diffShowsEntireFile = $0
                        session.loadDiff()
                    }
                )
            )
        }
        .fixedSize()
    }

    /// 32 × 26 pt 的图标开关；打开时铺一块 30 × 24 pt 的强调色圆角底，图标变白。
    private func toggle(_ key: String, symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Image(systemName: symbol)
                .foregroundStyle(isOn.wrappedValue ? Color.white : .secondary)
                .frame(width: 30, height: 24)
                .background {
                    if isOn.wrappedValue {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.accentColor)
                    }
                }
                .frame(width: 32, height: 26)
                .contentShape(Rectangle())
        }
        .toggleStyle(.button)
        .buttonStyle(.plain)
        .help(AppLocalization.text(key))
        .accessibilityLabel(AppLocalization.text(key))
    }
}

// MARK: - ContextLinesPopUp

/// 上下文行数的无边框小号弹出按钮：只有行数与上下箭头，行数用正文色。
private struct ContextLinesPopUp: NSViewRepresentable {
    /// 选择后写回上下文行数。
    @MainActor
    final class Coordinator: NSObject {
        /// 上下文行数的偏好。
        var value: Binding<Int>

        /// 创建动作接收方。
        ///
        /// - Parameter value: 上下文行数的偏好。
        init(value: Binding<Int>) {
            self.value = value
        }

        /// 选了一档行数。
        @objc
        func choose(_ button: NSPopUpButton) {
            if let lines = button.selectedItem?.representedObject as? Int {
                value.wrappedValue = lines
            }
        }
    }

    /// 上下文行数的偏好。
    @Binding
    var value: Int

    /// 建立动作接收方。
    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    /// 无边框、小号、11 pt 字的弹出按钮，列出全部档位。
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.isBordered = false
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11)
        button.target = context.coordinator
        button.action = #selector(Coordinator.choose(_:))
        button.setAccessibilityLabel(AppLocalization.text("diff.context"))

        for lines in DiffOptions.contextChoices {
            button.addItem(withTitle: DiffPreferences.contextTitle(lines))
            button.lastItem?.representedObject = lines
        }

        return button
    }

    /// 选中当前的档位。
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.value = $value

        if let index = DiffOptions.contextChoices.firstIndex(of: value) {
            button.selectItem(at: index)
        }
    }
}
