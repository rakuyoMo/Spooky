import SpookyKit
import SwiftUI

/// 暂存区与工作区状态并排显示，字母沿用 Git 状态码。
struct FileStatusView: View {
    /// 原始状态条目。
    let entry: StatusEntry

    /// 辅助技术与悬停提示使用本地化全称。
    private var description: String {
        switch entry.kind {
        case .untracked: AppLocalization.text("status.untracked")
        case .ignored: AppLocalization.text("status.ignored")
        case .conflicted: AppLocalization.text("status.conflicted")
        case .tracked:
            AppLocalization.text(
                "status.description",
                changeName(entry.staged),
                changeName(entry.unstaged)
            )
        }
    }

    /// 最多两枚状态徽标与可访问的完整说明。
    var body: some View {
        HStack(spacing: 3) {
            switch entry.kind {
            case .untracked:
                badge("?")

            case .ignored:
                badge("!")

            case .conflicted:
                badge("U")

            case .tracked:
                badge(entry.staged.map { String($0.rawValue) } ?? "")
                badge(entry.unstaged.map { String($0.rawValue) } ?? "")
            }
        }
        .help(description)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(description)
    }

    /// 状态字母不会仅靠颜色传达差异；无改动的一侧保留空位。
    private func badge(_ code: String) -> some View {
        Text(code)
            .font(.custom("Monaco", size: 10))
            .foregroundStyle(.white)
            .frame(width: 17, height: 16)
            .background(code.isEmpty ? .clear : color(code), in: RoundedRectangle(cornerRadius: 2))
    }

    /// 状态颜色取自命名色，不使用图片资源。
    private func color(_ code: String) -> Color {
        let name =
            switch code {
            case "A", "C": "green_file_status_background_color"
            case "M", "R", "T": "blue_file_status_background_color"
            case "D", "U": "red_file_status_background_color"
            default: "gray_file_status_background_color"
            }

        return AppPalette.color(name)
    }

    /// 将 Git 状态映射为资源键。
    private func changeName(_ change: FileChange?) -> String {
        let key =
            switch change {
            case .modified: "status.modified"
            case .typeChanged: "status.typeChanged"
            case .added: "status.added"
            case .deleted: "status.deleted"
            case .renamed: "status.renamed"
            case .copied: "status.copied"
            case .unmerged: "status.conflicted"
            case nil: "status.unchanged"
            }

        return AppLocalization.text(key)
    }
}
