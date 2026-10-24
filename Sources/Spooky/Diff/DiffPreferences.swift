import Foundation
import SpookyKit
import SwiftUI

// MARK: - DiffPreferences

/// Diff 的全局显示偏好：上下文行数与忽略空白对所有仓库的工作区和历史生效。
enum DiffPreferences {
    /// 上下文行数的偏好键。
    static let contextLinesKey = "diffContextLines"

    /// 忽略空白的偏好键。
    static let ignoresWhitespaceKey = "diffIgnoresWhitespace"

    /// 按当前偏好组成的选项；显示整个文件只属于当前视图，由调用方传入。
    ///
    /// - Parameters:
    ///   - showsEntireFile: 底栏的显示整个文件开关。
    ///   - defaults: 偏好来源，测试可以注入独立的偏好域。
    static func options(showsEntireFile: Bool = false, defaults: UserDefaults = .standard) -> DiffOptions {
        let stored = defaults.object(forKey: contextLinesKey) as? Int ?? DiffOptions.defaultContextLines

        // 不在档位中的旧值或手改的值按默认行数处理
        let context = DiffOptions.contextChoices.contains(stored) ? stored : DiffOptions.defaultContextLines

        return DiffOptions(
            contextLines: context,
            showsEntireFile: showsEntireFile,
            ignoresWhitespace: defaults.bool(forKey: ignoresWhitespaceKey)
        )
    }

    /// 上下文档位的菜单标题，如 “1 line” “5 lines”。
    static func contextTitle(_ lines: Int) -> String {
        lines == 1
            ? AppLocalization.text("diff.contextLine")
            : AppLocalization.text("diff.contextLines", lines)
    }
}

// MARK: - DiffPreferenceObserver

/// 全局 Diff 偏好变化后重新读取所在视图的 Diff，菜单与其它窗口里的修改同样生效。
private struct DiffPreferenceObserver: ViewModifier {
    /// 上下文行数。
    @AppStorage(DiffPreferences.contextLinesKey)
    private var contextLines = DiffOptions.defaultContextLines

    /// 忽略空白。
    @AppStorage(DiffPreferences.ignoresWhitespaceKey)
    private var ignoresWhitespace = false

    /// 重新读取的动作。
    let reload: () -> Void

    /// 只观察偏好，不改变内容布局。
    func body(content: Content) -> some View {
        content
            .onChange(of: contextLines) { reload() }
            .onChange(of: ignoresWhitespace) { reload() }
    }
}

extension View {
    /// 上下文行数或忽略空白的偏好改变时执行重新读取。
    func reloadsOnDiffPreferenceChange(_ reload: @escaping () -> Void) -> some View {
        modifier(DiffPreferenceObserver(reload: reload))
    }
}
