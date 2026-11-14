import SpookyKit
import SwiftUI

// MARK: - FileStatusView

/// 暂存区与工作区状态并排显示，字母沿用 Git 状态码。
///
/// 两枚 16 × 16 的徽标固定占 42 × 16 的区域：左边一枚贴区域左缘，两枚相隔 6；没有变化的一侧留空位。
struct FileStatusView: View {
    /// 原始状态条目。
    let entry: StatusEntry

    /// 文件标记了 assume-unchanged，悬停说明 Git 不检查它的改动。
    var assumeUnchanged = false

    /// 停止跟踪后工作区里同一路径的未跟踪文件并进这一行：右边一枚写未跟踪。
    var untrackedCopy = false

    /// 辅助技术与悬停提示使用本地化全称：普通文件分两行写出已暂存与未暂存的变化，冲突文件只说明冲突类型。
    var description: String {
        if assumeUnchanged {
            return AppLocalization.text("files.assumeUnchanged.status")
        }

        switch entry.kind {
        case .ignored: return AppLocalization.text("status.ignored")

        case .conflicted: return AppLocalization.text("conflict.toolTip", (entry.conflictKind ?? .bothModified).title)

        case .unchanged: return AppLocalization.text("status.unchanged")

        // 未跟踪的文件两行都写未跟踪
        case .untracked:
            let untracked = AppLocalization.text("status.untracked")
            return AppLocalization.text("status.description", untracked, untracked)

        case .tracked:
            return AppLocalization.text(
                "status.description",
                Self.changeName(entry.staged),
                untrackedCopy ? AppLocalization.text("status.untracked") : Self.changeName(entry.unstaged)
            )
        }
    }

    /// 左右两枚状态徽标与可访问的完整说明；未跟踪与被忽略的文件只在右边一枚的位置画徽标，没有改动的文件不画。
    var body: some View {
        HStack(spacing: 6) {
            Self.badge(codes.staged)
            Self.badge(codes.unstaged)
        }
        .frame(width: 42, height: 16, alignment: .leading)
        .help(description)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(description)
    }

    /// 左右两枚徽标的字母，空字符串表示这一侧没有徽标。
    var codes: (staged: String, unstaged: String) {
        switch entry.kind {
        case .untracked: ("", "?")

        case .ignored: ("", "!")

        case .unchanged: ("", "")

        // 冲突文件的两枚是 Git 的未合并两码，如 AA、UU、DU，与普通文件的暂存区 / 工作区两列含义不同
        case .tracked, .conflicted:
            (
                entry.staged.map { String($0.rawValue) } ?? "",
                untrackedCopy ? "?" : entry.unstaged.map { String($0.rawValue) } ?? ""
            )
        }
    }

    /// 状态字母不会仅靠颜色传达差异；无改动的一侧保留空位。
    ///
    /// - Parameters:
    ///   - code: 状态字母，空字符串表示无改动。
    ///   - size: 徽标的边长。
    static func badge(_ code: String, size: CGFloat = 16) -> some View {
        Text(code)
            .font(.custom("Monaco", size: 10))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
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

// MARK: - DirectoryStatusView

/// 树形目录行的两枚状态徽标，版式与文件行相同：每一列汇总其下在这一列有改动的条目。
struct DirectoryStatusView: View {
    /// 目录下当前显示的条目。
    let entries: [StatusEntry]

    /// 左右两枚徽标的字母，空字符串表示这一列下没有改动。
    ///
    /// 一列下全是删除写 “D”，全是未跟踪写 “?”，全是被忽略写 “!”，只有未跟踪与被忽略时写 “?”；
    /// 其余组合（含只有新增、新增与删除混合）都写 “M”。冲突文件按修改计。
    var codes: (staged: String, unstaged: String) {
        let columns = entries.map { entry -> (staged: String, unstaged: String) in
            let codes = FileStatusView(entry: entry).codes

            guard entry.kind == .conflicted else { return codes }

            return (codes.staged.isEmpty ? "" : "M", codes.unstaged.isEmpty ? "" : "M")
        }

        return (Self.summary(columns.map(\.staged)), Self.summary(columns.map(\.unstaged)))
    }

    /// 两枚徽标与可访问的说明，说明的写法与文件行相同。
    var body: some View {
        let codes = codes
        let description = AppLocalization.text(
            "status.description",
            Self.name(of: codes.staged),
            Self.name(of: codes.unstaged)
        )

        HStack(spacing: 6) {
            FileStatusView.badge(codes.staged)
            FileStatusView.badge(codes.unstaged)
        }
        .frame(width: 42, height: 16, alignment: .leading)
        .help(description)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(description)
    }

    /// 一列的汇总字母。
    private static func summary(_ codes: [String]) -> String {
        let changed = Set(codes.filter { !$0.isEmpty })

        guard !changed.isEmpty else { return "" }

        if changed.count == 1, let code = changed.first, ["D", "?", "!"].contains(code) {
            return code
        }

        return changed == ["?", "!"] ? "?" : "M"
    }

    /// 汇总字母的本地化全称。
    private static func name(of code: String) -> String {
        switch code {
        case "?": AppLocalization.text("status.untracked")
        case "!": AppLocalization.text("status.ignored")
        default: FileStatusView.changeName(code.first.flatMap(FileChange.init(rawValue:)))
        }
    }
}

// MARK: - FileChangeStatusView

/// 提交里一个文件的状态徽标：字母与底色和工作区的徽标相同，默认尺寸也相同，只有一枚；辅助技术读出状态全称。
struct FileChangeStatusView: View {
    /// Git raw 格式的状态字母，如 `M`、`A`。
    let code: String

    /// 徽标的边长；整页提交详情的文件行用 18。
    var size: CGFloat = 16

    /// 认得的字母读出本地化全称，认不得的照原样读出字母。
    private var description: String {
        guard let change = code.first.flatMap(FileChange.init(rawValue:)) else {
            return code
        }

        return FileStatusView.changeName(change)
    }

    /// 一枚状态徽标；认不得的字母落在灰色底上。
    var body: some View {
        FileStatusView.badge(code, size: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(description)
    }
}
