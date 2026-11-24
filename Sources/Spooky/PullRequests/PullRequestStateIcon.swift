import AppKit
import SpookyKit
import SwiftUI

// MARK: - PullRequestStateIcon

/// 请求状态的图标：打开、草稿、已关闭与已合并各一种，图案取自 Octicons，颜色按状态取命名色；提示与无障碍标签写出状态名。
struct PullRequestStateIcon: View {
    /// 资源包里 Octicons 的目录，图标与许可证放在一起。
    nonisolated static let directory = Bundle.module.url(forResource: "Octicons", withExtension: nil)

    /// 四种图标的模板图，以文件名为键，第一次用到时读出。
    private static let images: [String: NSImage] = {
        let names = ["git-pull-request-16", "git-pull-request-draft-16", "git-pull-request-closed-16", "git-merge-16"]

        return names.reduce(into: [:]) { images, name in
            guard let image = directory.flatMap({ NSImage(contentsOf: $0.appending(path: name + ".svg")) }) else {
                return
            }

            image.isTemplate = true
            images[name] = image
        }
    }()

    /// 显示的请求。
    let request: PullRequest

    /// 16 × 16 的模板图，按状态着色。
    var body: some View {
        Image(nsImage: Self.images[Self.imageName(for: request)] ?? NSImage())
            .renderingMode(.template)
            .foregroundStyle(AppPalette.color(Self.colorName(for: request)))
            .frame(width: 16, height: 16)
            .help(request.stateTitle)
            .accessibilityLabel(request.stateTitle)
    }

    /// 状态对应的 Octicons 文件名，不带扩展名；打开着的草稿用草稿的图标。
    static func imageName(for request: PullRequest) -> String {
        switch request.state {
        case .open: request.isDraft ? "git-pull-request-draft-16" : "git-pull-request-16"
        case .closed: "git-pull-request-closed-16"
        case .merged: "git-merge-16"
        }
    }

    /// 状态对应的命名色。
    static func colorName(for request: PullRequest) -> String {
        let state =
            switch request.state {
            case .open: request.isDraft ? "draft" : "open"
            case .closed: "closed"
            case .merged: "merged"
            }

        return "repository_pullrequests_state_" + state + "_color"
    }
}

// MARK: - PullRequest

extension PullRequest {
    /// 状态名：打开着的草稿写草稿。
    var stateTitle: String {
        switch state {
        case .open: AppLocalization.text(isDraft ? "pullRequests.state.draft" : "pullRequests.state.open")
        case .closed: AppLocalization.text("pullRequests.state.closed")
        case .merged: AppLocalization.text("pullRequests.state.merged")
        }
    }
}
