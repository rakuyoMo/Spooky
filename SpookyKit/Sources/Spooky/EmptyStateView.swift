import SwiftUI

/// 图标、18 pt 标题与说明组成的通用空状态。
struct EmptyStateView: View {
    /// 本地化后的标题。
    let title: String

    /// 本地化后的说明。
    let message: String

    /// 系统符号名称。
    let symbol: String

    /// 各元素以 12 pt 间距纵向居中排列。
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 58, weight: .light))
                .frame(width: 128, height: 100)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
