import SpookyKit
import SwiftUI

// MARK: - FileStatusView

/// 暂存区与工作区状态并排显示，字母沿用 Git 状态码。
struct FileStatusView: View {
    /// 原始状态条目。
    let entry: StatusEntry

    /// 文件标记了 assume-unchanged，显示灰色徽标与对应说明。
    var assumeUnchanged = false

    /// 辅助技术与悬停提示使用本地化全称；冲突文件说明冲突类型。
    private var description: String {
        #warning("TODO: 悬停冲突文件的状态列，核对提示是否为 “File requires merging: <冲突类型>”；只影响冲突文件行的悬停提示")

        if assumeUnchanged {
            return AppLocalization.text("files.assumeUnchanged.status")
        }

        switch entry.kind {
        case .untracked: return AppLocalization.text("status.untracked")
        case .ignored: return AppLocalization.text("status.ignored")
        case .conflicted: return AppLocalization.text("conflict.toolTip", (entry.conflictKind ?? .bothModified).title)
        case .unchanged: return AppLocalization.text("status.unchanged")
        case .tracked:
            return AppLocalization.text(
                "status.description",
                Self.changeName(entry.staged),
                Self.changeName(entry.unstaged)
            )
        }
    }

    /// 最多两枚状态徽标与可访问的完整说明。
    var body: some View {
        HStack(spacing: 3) {
            switch entry.kind {
            case .untracked:
                Self.badge("?")

            case .ignored:
                Self.badge("!")

            case .conflicted:
                Self.badge("U")

            // 没有改动的文件不画徽标；assume-unchanged 用 ls-files -v 的小写标记 h
            case .unchanged:
                #warning("TODO: 打开 Show Assume-Unchanged Items，核实 assume-unchanged 文件的徽标字母，目前取 ls-files -v 的小写 h；只影响这类文件的徽标文字")
                Self.badge(assumeUnchanged ? "h" : "")

            case .tracked:
                Self.badge(entry.staged.map { String($0.rawValue) } ?? "")
                Self.badge(entry.unstaged.map { String($0.rawValue) } ?? "")
            }
        }
        .help(description)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(description)
    }

    /// 状态字母不会仅靠颜色传达差异；无改动的一侧保留空位。
    static func badge(_ code: String) -> some View {
        Text(code)
            .font(.custom("Monaco", size: 10))
            .foregroundStyle(.white)
            .frame(width: 17, height: 16)
            .background(code.isEmpty ? .clear : color(code), in: RoundedRectangle(cornerRadius: 2))
    }

    /// 将 Git 状态映射为资源键。
    static func changeName(_ change: FileChange?) -> String {
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

    /// 状态颜色取自命名色，不使用图片资源。
    private static func color(_ code: String) -> Color {
        let name =
            switch code {
            case "A", "C": "green_file_status_background_color"
            case "M", "R", "T": "blue_file_status_background_color"
            case "D", "U": "red_file_status_background_color"
            default: "gray_file_status_background_color"
            }

        return AppPalette.color(name)
    }
}

// MARK: - FileChangeStatusView

/// 提交里一个文件的状态徽标：字母、尺寸与底色和工作区的徽标相同，只有一枚；辅助技术读出状态全称。
struct FileChangeStatusView: View {
    /// Git raw 格式的状态字母，如 `M`、`A`。
    let code: String

    /// 认得的字母读出本地化全称，认不得的照原样读出字母。
    private var description: String {
        guard let change = code.first.flatMap(FileChange.init(rawValue:)) else {
            return code
        }

        return FileStatusView.changeName(change)
    }

    /// 一枚状态徽标；认不得的字母落在灰色底上。
    var body: some View {
        FileStatusView.badge(code)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(description)
    }
}
