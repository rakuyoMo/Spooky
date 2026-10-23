import AppKit
import SwiftUI

/// 内嵌错误的统一结构：标题、类别与仓库位置、恢复说明，以及可选择复制的原始输出。
struct FailureDetailsView: View {
    /// 要展示的错误。
    let failure: AppFailure

    /// 可选的重试动作，例如重新读取 Diff 或历史。
    var retry: (() -> Void)?

    /// 原文放在有高度上限的滚动区，长输出不会撑开所在视图。
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(failure.title)
                    .font(.system(size: 13, weight: .semibold))
                    .textSelection(.enabled)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppPalette.color("warning_tint_color"))
                    .accessibilityHidden(true)
            }

            Text(failure.context)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Text(failure.message)
                .font(.system(size: 12))

            ScrollView {
                Text(failure.details)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 175)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.color("general_border_color")))
            .accessibilityLabel(AppLocalization.text("error.details"))

            if let retry {
                Button(AppLocalization.text("action.refresh"), action: retry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
