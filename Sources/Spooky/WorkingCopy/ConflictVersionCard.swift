import AppKit
import SpookyKit
import SwiftUI

// MARK: - ConflictVersionCard

/// 冲突向导上排的一张版本卡片：上栏是标题、版本菜单与版本摘要，有提交来源时下栏是这一侧的提交。
///
/// 选中时边框变蓝；单击与 ⌘ 单击由向导处理。
struct ConflictVersionCard: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 冲突文件。
    let entry: StatusEntry

    /// 这张卡片对应的一侧。
    let side: ConflictSide

    /// 这一侧的原文；这一侧删除了文件时为 nil。
    let data: Data?

    /// 这一侧版本所在的提交；没有提交来源时为 nil。
    let commit: HistoryCommit?

    /// 卡片是否选中。
    let isSelected: Bool

    /// 设置里的提交日期格式。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

    /// 标题行、版本摘要与提交信息。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(title)

                Spacer(minLength: 0)

                ConflictVersionMenu(session: session, entry: entry, side: side, data: data)
            }

            ConflictVersionSummary(
                path: entry.path,
                change: entry.conflict?.change(theirs: side == .theirs),
                date: commit.map { dateFormat.string(from: $0.commitDate) }
            )
            .padding(.top, 12)

            if let commit {
                Divider()
                    .padding(.vertical, 12)

                footer(commit)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ConflictTile(isSelected: isSelected))
        .contentShape(Rectangle())
    }

    /// 卡片标题：应用补丁或储藏的一侧是状态描述，不加引用名的引号。
    private var title: String {
        guard side == .theirs, session.context?.progress == nil else {
            return AppLocalization.text("conflict.version", Self.name(of: side, in: session))
        }

        return AppLocalization.text("conflict.version.applied")
    }

    /// 一侧的引用名。
    static func name(of side: ConflictSide, in session: RepositorySession) -> String {
        side == .ours ? session.oursName : session.theirsName
    }

    /// 提交来源：48 pt 头像、作者、日期、短哈希与标题。
    private func footer(_ commit: HistoryCommit) -> some View {
        HStack(alignment: .top, spacing: 12) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(commit.author)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("\(dateFormat.string(from: commit.commitDate))  \(commit.shortID)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(commit.subject)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .help(commit.subject)
            }
        }
    }
}

// MARK: - ConflictVersionSummary

/// 一个版本的摘要：文件类型图标、文件名、改动徽标与修改时间；版本卡片与结果框共用。
struct ConflictVersionSummary: View {
    /// 文件在仓库内的路径。
    let path: String

    /// 这一侧相对共同祖先的改动；结果框显示合并时为 nil，改由 `badge` 给出。
    let change: ConflictChange?

    /// 修改时间；没有提交来源时为 nil，不显示。
    let date: String?

    /// 改动徽标；为 nil 时按 `change` 取。
    var badge: ConflictBadge? = nil

    /// 图标在左，右侧上行是文件名与徽标、下行是时间。
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: WorkingCopyFileHeader.icon(path: path, isFolder: false))
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(RepositorySession.fileName(path))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    badge ?? change.map(ConflictBadge.init(change:))
                }

                if let date {
                    Text(date)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - ConflictBadge

/// 版本的改动类型徽标：大写短词，按改动类型着色。
struct ConflictBadge: View {
    /// 合并两侧的徽标。
    static let merge = Self(key: "conflict.change.merge", color: .yellow)

    /// 徽标文字的资源键。
    let key: String

    /// 徽标颜色。
    let color: Color

    /// 圆角描边里的小号粗体字。
    var body: some View {
        Text(AppLocalization.text(key))
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color))
            .fixedSize()
    }

    /// 按改动取文字与颜色。
    init(change: ConflictChange) {
        switch change {
        case .added: self.init(key: "conflict.change.added", color: .green)
        case .modified: self.init(key: "conflict.change.modified", color: .blue)
        case .deleted: self.init(key: "conflict.change.deleted", color: .red)
        }
    }

    /// 指定文字与颜色。
    private init(key: String, color: Color) {
        self.key = key
        self.color = color
    }
}

// MARK: - ConflictTile

/// 版本卡片与结果框的底色与边框；选中时边框变蓝。
struct ConflictTile: View {
    /// 是否选中。
    let isSelected: Bool

    /// 圆角底色加描边。
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(AppPalette.color("repository_mergeconflict_tile_background_light_color"))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.accentColor : AppPalette.color("general_border_color"),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }
}
