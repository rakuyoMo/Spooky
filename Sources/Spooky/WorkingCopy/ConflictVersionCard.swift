import AppKit
import SpookyKit
import SwiftUI

// MARK: - ConflictVersionCard

/// 冲突向导上排的一张版本卡片，分三段、段间各一条分隔线：标题栏、版本摘要，有提交来源时还有这一侧的提交栏。
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

    /// 标题栏、版本摘要与提交栏。
    var body: some View {
        VStack(spacing: 0) {
            ConflictTileTitle(title: Self.title(of: side, in: session)) {
                ConflictVersionMenu(session: session, entry: entry, side: side, data: data)
            }

            Divider()

            ConflictVersionSummary(
                path: entry.path,
                contents: [data],
                badge: entry.conflict.map { ConflictBadge(change: $0.change(theirs: side == .theirs)) },
                date: commit?.commitDate
            )

            if let commit {
                Divider()

                footer(commit)
            }
        }
        .modifier(ConflictTile(isSelected: isSelected))
        .contentShape(Rectangle())
    }

    /// 一侧的引用名。
    static func name(of side: ConflictSide, in session: RepositorySession) -> String {
        side == .ours ? session.oursName : session.theirsName
    }

    /// 一侧的标题：应用补丁或储藏的一侧是状态描述，不加引用名的引号。
    static func title(of side: ConflictSide, in session: RepositorySession) -> String {
        guard side == .theirs, session.context?.progress == nil else {
            return AppLocalization.text("conflict.version", name(of: side, in: session))
        }

        return AppLocalization.text("conflict.version.applied")
    }

    /// 提交栏：高 64 pt、底色深一档；48 × 48 的方形头像，右边是次要色的作者与日期，下一行是等宽字的短哈希接提交说明。
    private func footer(_ commit: HistoryCommit) -> some View {
        HStack(spacing: 10) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 48, isSquare: true)
                .help("\(commit.author) <\(commit.authorEmail)>")

            VStack(alignment: .leading, spacing: 3) {
                Text("\(commit.author)  \(dateFormat.string(from: commit.commitDate))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(commit.shortID)
                        .font(.system(size: 11, design: .monospaced))
                        .fixedSize()

                    Text(commit.subject)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .help("\(commit.shortID) \(commit.subject)")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(AppPalette.color("repository_mergeconflict_tile_background_dark_color"))
    }
}

// MARK: - ConflictTileTitle

/// 版本卡片与结果框的标题栏：高 50 pt，13 pt 半粗的标题，右侧可放菜单按钮。
struct ConflictTileTitle<Accessory: View>: View {
    /// 标题。
    let title: String

    /// 标题右侧的内容。
    @ViewBuilder
    let accessory: Accessory

    /// 标题在左，放不下时尾部截断；右侧内容靠右。
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .help(title)

            Spacer(minLength: 0)

            accessory
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
    }
}

extension ConflictTileTitle where Accessory == EmptyView {
    /// 只有标题的标题栏。
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

// MARK: - ConflictTile

/// 版本卡片与结果框的底色与边框：内容按圆角裁切，选中时边框变蓝。
struct ConflictTile: ViewModifier {
    /// 是否选中。
    let isSelected: Bool

    /// 圆角底色加描边。
    func body(content: Content) -> some View {
        content
            .background(AppPalette.color("repository_mergeconflict_tile_background_light_color"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.accentColor : AppPalette.color("general_border_color"),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }
}
