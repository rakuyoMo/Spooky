import SpookyKit
import SwiftUI

/// 所选状态条目的路径与 Diff 占位，路径支持选择和复制。
struct WorkingCopyDetailView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 路径头与内容空状态。
    var body: some View {
        if let selected = session.selectedID,
           let entry = session.status?.entries.first(where: {
               $0.path == selected.path && $0.kind == selected.kind
           }) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                        .font(.system(size: 24))
                        .accessibilityHidden(true)

                    Text(entry.path)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(entry.path)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(AppPalette.color("general_header_background_color"))

                Divider()

                VStack(spacing: 16) {
                    Text(entry.path)
                        .textSelection(.enabled)
                        .font(.system(size: 13))

                    if let original = entry.originalPath {
                        Text(AppLocalization.text("detail.originalPath", original))
                            .textSelection(.enabled)
                            .font(.system(size: 11))
                    }

                    EmptyStateView(
                        title: AppLocalization.text("detail.diff.title"),
                        message: AppLocalization.text("detail.diff.message"),
                        symbol: "doc.text.magnifyingglass"
                    )
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            EmptyStateView(
                title: AppLocalization.text("detail.empty.title"),
                message: AppLocalization.text("detail.empty.message"),
                symbol: "doc"
            )
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
