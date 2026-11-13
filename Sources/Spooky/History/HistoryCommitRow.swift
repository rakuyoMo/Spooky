import AppKit
import SpookyKit
import SwiftUI

// MARK: - HistoryCommitRow

/// 提交行提供中号双行和小号单行两种布局。
struct HistoryCommitRow: View {
    /// 选中行的文字使用系统的选中文字语义色。
    private static let selectedText = Color(nsColor: .alternateSelectedControlTextColor)

    /// 未拉取与父分支提交的文字颜色，选中时也不变。
    private static let dimmedText = Color(nsColor: .secondaryLabelColor)

    /// 图到头像（中号）或短哈希（小号）的距离，也是小号行没有图时短哈希距行首的距离。
    private static let spacing: CGFloat = 8

    /// 中号行的圆点中心距行顶的距离。
    private static let mediumDotCenter: CGFloat = 25

    /// 当前提交元信息。
    let commit: HistoryCommit

    /// 单行独立绘制模型。
    let graph: CommitGraphRow?

    /// 指向当前提交的完整引用。
    let references: [RepositoryReference]

    /// HEAD 作为独立蓝色徽标显示。
    let isHead: Bool

    /// 小号行高为 24 pt。
    let small: Bool

    /// 提交日期的显示格式。
    let dateFormat: CommitDateFormat

    /// 未推送提交在行尾显示上箭头。
    let unpushed: Bool

    /// 未拉取提交显示下箭头与弱化背景。
    let unpulled: Bool

    /// 与基准分支比较时，分叉点及其之下属于基准分支的提交，与未拉取的提交一样置灰。
    let isParent: Bool

    /// 被选中时文本和徽标采用选中配色。
    let selected: Bool

    /// 窗口的签名结果，开启签名校验时行末显示签名按钮。
    let signatures: CommitSignatureStore

    /// 校验签名与标签签名用的执行器。
    let runner: GitRunner?

    /// 图在最左侧，其余内容按档位排成单行或双行；整行不设悬停提示，辅助技术读出合并后的内容。
    var body: some View {
        HStack(spacing: 0) {
            if let graph {
                HistoryGraphView(row: graph, dotCenter: small ? nil : Self.mediumDotCenter)
                    .frame(width: Self.graphWidth(graph))
                    .accessibilityHidden(true)
            }

            // 图之外的内容比行的正中高 1 pt：头像底（中号）到行底的分隔线留 7 pt，短哈希底（小号）留 6 pt
            Group {
                if small {
                    smallLayout
                } else {
                    mediumLayout
                }
            }
            .padding(.leading, graph != nil || small ? Self.spacing : 0)
            .offset(y: -1)
        }
        .font(.system(size: small ? 11 : 12))
        .padding(.trailing, small ? 16 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(isDimmed ? Self.dimmedText : (selected ? Self.selectedText : .primary))
        .background(
            isDimmed && !selected
                ? AppPalette.color("general_alternate_row_background_color")
                : .clear
        )
        .accessibilityElement(children: .combine)
    }

    /// 行首到头像（中号）或短哈希（小号）左缘的距离：有图时是图宽加间距；没有图时小号行留出间距，中号行贴着行首。
    ///
    /// - Parameters:
    ///   - graph: 这一行的提交图；不显示图时为 nil。
    ///   - small: 是否是小号行。
    static func contentLeading(graph: CommitGraphRow?, small: Bool) -> CGFloat {
        guard let graph else {
            return small ? spacing : 0
        }

        return graphWidth(graph) + spacing
    }
}

// MARK: - Layouts

extension HistoryCommitRow {
    /// 小号单行：短哈希、引用、标题、作者、日期，行末是签名按钮与箭头。
    ///
    /// 间距依次为 4、4、4、8、4 pt；窄窗口里先截作者，其次是标题、引用与日期，短哈希始终完整。
    private var smallLayout: some View {
        HStack(spacing: 0) {
            hash
                .fixedSize()
                .layoutPriority(3)

            badges

            Text(commit.subject)
                .lineLimit(1)
                .padding(.leading, 4)
                .layoutPriority(0.25)

            // 空白最先让出
            Spacer(minLength: 0)
                .layoutPriority(-1)

            author
                .padding(.leading, 4)

            HStack(spacing: 4) {
                date
                signatureButton
                arrow
            }
            .padding(.leading, 8)
            .layoutPriority(1)
        }
    }

    /// 中号双行：作者头像在左；右侧上行为作者、引用、日期与箭头，下行为短哈希、标题与箭头正下方的签名按钮。
    private var mediumLayout: some View {
        HStack(spacing: Self.spacing) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 32)
                .opacity(isDimmed ? 0.5 : 1)
                .help("\(commit.author) <\(commit.authorEmail)>")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    author
                    badges
                    Spacer(minLength: 0)
                    date
                    arrow
                }

                HStack(spacing: 8) {
                    hash
                    Text(commit.subject).lineLimit(1)
                    Spacer(minLength: 0)
                    signatureButton
                }
            }
        }
    }
}

// MARK: - Elements

extension HistoryCommitRow {
    /// 未拉取的提交与比较时属于基准分支的提交：文字一律次要色、头像变灰，选中时也保持。
    private var isDimmed: Bool {
        unpulled || isParent
    }

    /// 作者、短哈希与日期的颜色。
    private var secondaryText: Color {
        selected && !isDimmed ? Self.selectedText : Self.dimmedText
    }

    /// 作者名。
    private var author: some View {
        Text(commit.author)
            .foregroundStyle(secondaryText)
            .lineLimit(1)
    }

    /// 哈希使用等宽字体，动作仍使用完整 ID。
    private var hash: some View {
        Text(commit.shortID)
            .font(.system(size: small ? 10 : 12, design: .monospaced))
            .foregroundStyle(secondaryText)
    }

    /// 列表按日期格式偏好显示提交人日期，完整两种日期在详情中展示。
    private var date: some View {
        Text(dateFormat.string(from: commit.commitDate))
            .foregroundStyle(secondaryText)
            .lineLimit(1)
            .layoutPriority(1)
    }

    /// 引用标记；在行里先于作者与标题取得宽度，日期仍最先。小号行里距短哈希 4 pt。
    @ViewBuilder
    private var badges: some View {
        if isHead || !references.isEmpty {
            HistoryRefBadges(references: references, isHead: isHead, selected: selected, runner: runner)
                .padding(.leading, small ? 4 : 0)
                .layoutPriority(0.5)
        }
    }

    /// 开启签名校验时的签名按钮。
    private var signatureButton: some View {
        CommitSignatureButton(store: signatures, commit: commit.id, runner: runner, small: small)
    }

    /// 未推送的提交是上箭头，未拉取的是下箭头；中号行的箭头占 12 × 12 pt。
    @ViewBuilder
    private var arrow: some View {
        if unpushed || unpulled {
            Image(systemName: unpushed ? "arrow.up" : "arrow.down")
                .font(.system(size: small ? 10 : 12))
                .frame(width: small ? nil : 12, height: small ? nil : 12)
                .accessibilityLabel(
                    AppLocalization.text(unpushed ? "history.unpushed" : "history.unpulled")
                )
        }
    }

    /// 图的宽度：每列 10 pt，另加 7 pt。
    private static func graphWidth(_ graph: CommitGraphRow) -> CGFloat {
        CGFloat(graph.columnCount) * 10 + 7
    }
}
