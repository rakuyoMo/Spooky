import SwiftUI

// MARK: - SettingsFailureView

/// 设置页读写配置失败时的说明：黄色警告图标、标题与可选中的原因。
struct SettingsFailureView: View {
    /// 标题：哪一次读写没有成功。
    let title: String

    /// 失败的原因，可选中复制。
    let details: String

    /// 原因是不是命令输出的原文：原文用等宽字体，其余用界面字体。
    var isOutput = false

    /// 图标挂在左侧，标题与原因上下排列。
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))

                Text(details)
                    .font(isOutput ? .system(size: 11).monospaced() : .system(size: 11))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
