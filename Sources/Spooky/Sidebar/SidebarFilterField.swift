import SwiftUI

// MARK: - SidebarFilterField

/// 侧边栏底栏的过滤框：平时收成一个 22 × 22 的按钮，鼠标移入或点按时展开成 181 pt 宽的胶囊形搜索框。
///
/// 移出时文字为空且不在编辑就收起；Esc 只清空文字，仍在编辑；结束编辑时文字为空同样收起。
struct SidebarFilterField: View {
    /// 展开后的宽度，右侧的按钮多少不影响它。
    static let expandedWidth: CGFloat = 181

    /// 过滤文字。
    @Binding
    var text: String

    /// 是否展开成搜索框。
    @State
    private var isExpanded = false

    /// 搜索框是否在编辑。
    @FocusState
    private var isFocused: Bool

    /// 按钮在搜索框左端，展开后与输入框、清除按钮共用一个灰色胶囊底，编辑时外圈画焦点环。
    var body: some View {
        HStack(spacing: 0) {
            Button(action: expandAndFocus) {
                Image(systemName: symbol)
                    .foregroundStyle(text.isEmpty ? Color.secondary : Color.accentColor)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(AppLocalization.text("sidebar.filter"))

            if isExpanded {
                TextField(AppLocalization.text("sidebar.filter"), text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFocused)
                    .onExitCommand { text = "" }
                    .padding(.trailing, 6)
                    .transition(.opacity)

                // 有文字时右端出现清除按钮
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .padding(.trailing, 4)
                    .accessibilityLabel(AppLocalization.text("sidebar.filter.clear"))
                }
            }
        }
        .frame(height: 22)
        .frame(width: isExpanded ? Self.expandedWidth : 22, alignment: .leading)
        .background {
            if isExpanded {
                Capsule()
                    .fill(.quaternary)
            }
        }
        .overlay {
            if isExpanded, isFocused {
                Capsule()
                    .stroke(Color(nsColor: .keyboardFocusIndicatorColor), lineWidth: 3)
            }
        }
        .padding(.leading, isExpanded ? 0 : 4)
        .onHover { inside in
            if inside {
                setExpanded(true)
            } else if text.isEmpty, !isFocused {
                setExpanded(false)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused, text.isEmpty { setExpanded(false) }
        }
    }

    /// 按钮图标：有过滤文字时换成实心的版本，并用强调色着色。
    private var symbol: String {
        text.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
    }

    /// 点按钮：展开并开始编辑。
    private func expandAndFocus() {
        setExpanded(true)
        isFocused = true
    }

    /// 展开与收起都带透明度与宽度的动画。
    private func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded = expanded
        }
    }
}
