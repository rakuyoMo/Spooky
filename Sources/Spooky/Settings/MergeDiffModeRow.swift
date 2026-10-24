import Foundation
import SpookyKit
import SwiftUI

// MARK: - MergeDiffMode

extension MergeDiffMode {
    /// Settings → General 的 “Show diffs for merge commits” 偏好键。
    static let preferenceKey = "historyMergeDiffMode"

    /// 当前偏好；没有设置过时与第一父提交比较。
    static var preferred: MergeDiffMode {
        let value = UserDefaults.standard.object(forKey: preferenceKey) as? Int
        return value.flatMap(MergeDiffMode.init(rawValue:)) ?? .firstParent
    }

    /// 设置里显示的选项文字。
    var title: String {
        switch self {
        case .off: AppLocalization.text("history.mergeDiff.off")
        case .firstParent: AppLocalization.text("history.mergeDiff.firstParent")
        case .mergedFilePaths: AppLocalization.text("history.mergeDiff.mergedFilePaths")
        }
    }
}

// MARK: - MergeDiffModeRow

/// General 页的合并提交 Diff 方式：提交详情与整页详情都按它读取合并提交的改动。
struct MergeDiffModeRow: View {
    /// 偏好里保存的原始值。
    @AppStorage(MergeDiffMode.preferenceKey)
    private var mode = MergeDiffMode.firstParent.rawValue

    /// 右对齐的标签与 278 pt 宽的弹出菜单。
    var body: some View {
        GridRow {
            Text(AppLocalization.text("history.mergeDiff"))
                .gridColumnAlignment(.trailing)

            Picker("", selection: $mode) {
                ForEach(MergeDiffMode.allCases, id: \.self) {
                    Text($0.title).tag($0.rawValue)
                }
            }
            .labelsHidden()
            .frame(width: 278)
            .accessibilityLabel(AppLocalization.text("history.mergeDiff"))
        }
    }
}
