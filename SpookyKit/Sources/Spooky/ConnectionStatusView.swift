import SpookyKit
import SwiftUI

/// 服务器身份和连接反馈始终留在旧快照旁，断线时仍能阅读文件列表。
struct ConnectionStatusView: View {
    /// 当前窗口会话。
    let session: RepositorySession

    /// 诊断默认收起，用户可展开复制原始 SSH 输出。
    @State
    private var showsDetails = false

    /// 状态、恢复动作和必要的诊断内容。
    var body: some View {
        if let host = session.repository?.host, let state = session.connectionState {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if state == .connecting || state == .reconnecting {
                        ProgressView().controlSize(.small)
                    }

                    Text(host + ": " + AppLocalization.text("connection." + state.rawValue))
                        .font(.system(size: 11))
                        .accessibilityIdentifier("connection-status")

                    Spacer()

                    if state == .unavailable {
                        Button(AppLocalization.text("action.reconnect")) { session.reconnect() }
                            .controlSize(.small)
                    }
                }

                if state != .connected {
                    Text(AppLocalization.text("connection.cached"))
                        .font(.system(size: 11))
                }

                if let failure = session.failure {
                    DisclosureGroup(failure.title, isExpanded: $showsDetails) {
                        FailureDetailsView(failure: failure)
                    }
                    .font(.system(size: 11))
                }

                if let recovery = session.recovery {
                    Text(AppLocalization.text(
                        "connection.recovery",
                        recovery.status.branch.head ?? AppLocalization.text("branch.detachedShort"),
                        recovery.status.entries.count,
                        AppLocalization.text(recovery.indexLocked ? "state.yes" : "state.no"),
                        AppLocalization.text(recovery.merging ? "state.yes" : "state.no"),
                        AppLocalization.text(recovery.rebasing ? "state.yes" : "state.no")
                    ))
                    .font(.system(size: 11))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.color(state == .connected ? "general_info_background_color" : "general_warning_bg_color"))
        }
    }
}
