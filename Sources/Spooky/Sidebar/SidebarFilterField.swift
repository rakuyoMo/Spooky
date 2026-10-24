import SwiftUI

// MARK: - SidebarFilterField

/// 侧边栏底栏的过滤框：平时收成一个 22 × 22 的按钮，鼠标移入或点按时展开成搜索框。
///
/// 移出时文字为空且不在编辑就收起；Esc 清空并收起；结束编辑时文字为空同样收起。
struct SidebarFilterField: View {
    /// 过滤文字。
    @Binding
    var text: String

    /// 是否展开成搜索框。
    @State
    private var isExpanded = false

    /// 搜索框是否在编辑。
    @FocusState
    private var isFocused: Bool

    /// 按钮在搜索框左端，展开后与输入框共用一个圆角底框。
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
                    .onExitCommand(perform: clear)
                    .padding(.trailing, 6)
                    .transition(.opacity)
            }
        }
        .frame(height: 22)
        .frame(maxWidth: isExpanded ? .infinity : 22, alignment: .leading)
        .background {
            if isExpanded {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .strokeBorder(Color(nsColor: .separatorColor))
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

    /// Esc：清空文字、结束编辑并收起。
    private func clear() {
        text = ""
        isFocused = false
        setExpanded(false)
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
