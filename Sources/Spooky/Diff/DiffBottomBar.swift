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

                Picker(AppLocalization.text("diff.context"), selection: $contextLines) {
                    ForEach(DiffOptions.contextChoices, id: \.self) {
                        Text(DiffPreferences.contextTitle($0)).tag($0)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .disabled(session.diffShowsEntireFile)
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
            toggle("diff.ignoreWhitespace", symbol: "space", isOn: $ignoresWhitespace)

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

    /// 30 pt 宽的图标开关，打开时图标使用强调色。
    private func toggle(_ key: String, symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Image(systemName: symbol)
                .foregroundStyle(isOn.wrappedValue ? Color.accentColor : .secondary)
        }
        .toggleStyle(.button)
        .buttonStyle(.borderless)
        .frame(width: 30)
        .help(AppLocalization.text(key))
        .accessibilityLabel(AppLocalization.text(key))
    }
}
