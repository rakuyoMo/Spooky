import SwiftUI

/// 变更集单文件的读取进度，保持与文件头相同的 32 pt 行高。
struct ChangesetDiffLoadingView: View {
    /// 转圈距左侧 3 pt，文字左缘位于 25 pt。
    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)

            Text(AppLocalization.text("working.loadingDiff"))
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: .disabledControlTextColor))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 32)
    }
}
