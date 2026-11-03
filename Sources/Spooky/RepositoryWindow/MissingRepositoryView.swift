import SpookyKit
import SwiftUI

// MARK: - MissingRepositoryView

/// 打开的仓库找不到或连不上时，代替整个仓库界面的空状态页：标题、说明与 Refresh、Close 两个按钮。
///
/// 服务器仓库区分 “主机连不上” 与 “路径不存在”；连不上时附上 SSH 的原始输出。
struct MissingRepositoryView: View {
    /// 打不开的原因。
    enum Reason {
        /// 路径不存在。
        case notFound

        /// 服务器连不上，带原始输出。
        case unreachable(AppFailure)
    }

    /// 打不开的仓库。
    let location: RepositoryLocation

    /// 打不开的原因。
    let reason: Reason

    /// 所在窗口的会话；重新打开期间按钮禁用并显示进度。
    let session: RepositorySession

    /// 重新检查并打开。
    let refresh: () -> Void

    /// 回到仓库管理。
    let close: () -> Void

    /// 空状态的按钮行位置上自上而下是连不上时的原始输出、Refresh 与 Close、重新打开期间的进度。
    var body: some View {
        EmptyStateView(title: title, message: message, symbol: symbol) {
            VStack(spacing: 8) {
                if case .unreachable(let failure) = reason {
                    ScrollView {
                        Text(failure.details)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxWidth: 480, maxHeight: 120)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.color("general_border_color")))
                    .accessibilityLabel(AppLocalization.text("error.details"))
                }

                HStack(spacing: 8) {
                    EmptyStateButton(AppLocalization.text("action.refresh"), action: refresh)
                        .disabled(session.isOpening)
                        .accessibilityIdentifier("missing-refresh")

                    EmptyStateButton(AppLocalization.text("action.close"), action: close)
                        .accessibilityIdentifier("missing-close")
                }

                if session.isOpening {
                    ProgressView(AppLocalization.text("loading.open"))
                        .controlSize(.small)
                }
            }
        }
    }

    /// 打开失败是否属于这一页：本机路径不存在，服务器上的路径不存在，或服务器连不上；其余失败仍走错误 sheet。
    ///
    /// - Parameters:
    ///   - location: 要打开的仓库。
    ///   - error: 打开时的错误。
    /// - Returns: 这一页的原因；不属于这一页时为 nil。
    static func reason(for location: RepositoryLocation, error: any Error) -> Reason? {
        if let remote = error as? RemoteConnectionError {
            switch remote.kind {
            case .pathUnavailable:
                return .notFound

            case .unavailable:
                return .unreachable(AppFailure(error: error, opening: true, location: location))

            default:
                return nil
            }
        }

        if location.host == nil, !FileManager.default.fileExists(atPath: location.path) {
            return .notFound
        }

        return nil
    }
}

// MARK: - Texts

extension MissingRepositoryView {
    /// 两种原因各自的标题。
    private var title: String {
        switch reason {
        case .notFound:
            AppLocalization.text("missing.title")

        case .unreachable:
            AppLocalization.text("missing.unreachable.title", location.host ?? "")
        }
    }

    /// 写出仓库位置的说明。
    var message: String {
        switch reason {
        case .notFound:
            AppLocalization.text("missing.message", messagePath)

        case .unreachable:
            AppLocalization.text("missing.unreachable.message", messagePath)
        }
    }

    /// 说明里的仓库位置：本机仓库把主目录缩写成 `~`；服务器仓库写 “<别名>:<路径>”，不缩写，`~` 只代表这台 Mac 的主目录。
    private var messagePath: String {
        location.host == nil ? HomePath.abbreviated(location.path) : location.displayPath
    }

    /// 路径不存在用带问号的文件夹，连不上用断开的网络。
    private var symbol: String {
        switch reason {
        case .notFound: "questionmark.folder"
        case .unreachable: "network.slash"
        }
    }
}
