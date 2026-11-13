import SpookyKit
import SwiftUI

// MARK: - CommitDetailBar

/// 提交详情的 40 pt 顶栏：左侧可选中的短哈希，右侧 `Changeset | Tree` 切换。
struct CommitDetailBar: View {
    /// 当前提交。
    let commit: HistoryCommit

    /// 显示文件树；否则显示变更集。
    @Binding
    var showsTree: Bool

    /// 哈希距左 20 pt，分段控件宽 141 pt、距右 20 pt。
    var body: some View {
        HStack {
            Text(commit.shortID)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Spacer()

            Picker("", selection: $showsTree) {
                Text(AppLocalization.text("history.changeset")).tag(false)
                Text(AppLocalization.text("history.tree")).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 141)
            .accessibilityLabel(AppLocalization.text("history.detailMode"))
        }
        .padding(.horizontal, 20)
        .frame(height: 40)
        .background(.bar)
    }
}

// MARK: - CommitMetadataView

/// 提交详情的头部：标签与值两列，右侧是提交人与作者的头像，右上角的三角在展开与收起之间切换。
struct CommitMetadataView: View {
    /// 头部的一行：文字值或引用标记。
    enum Row: Equatable {
        /// 标签的资源键与可选中的值。
        case text(key: String, value: String)

        /// 指向这个提交的引用标记。
        case refs
    }

    /// 保存展开状态的偏好键，所有窗口与重启后共用。
    static let expandedKey = "commitDetailHeaderExpanded"

    /// 已从列表读取的提交记录。
    let commit: HistoryCommit

    /// 校验过的签名；还没有结果或没有签名时不显示签名行。
    let signature: CommitSignature?

    /// 指向这个提交的引用，随引用快照变化。
    let references: [RepositoryReference]

    /// HEAD 是否指向这个提交。
    let isHead: Bool

    /// 校验标签签名用的执行器。
    let runner: GitRunner?

    /// 展开时显示全部字段；没有保存过时展开。
    @AppStorage(Self.expandedKey)
    private var expanded = true

    /// 信息区上 8、下 4、左右 0，放在左右各 20 pt 的详情容器里；三角距顶、距右 8 pt。
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(Array(rows.enumerated()), id: \.offset) {
                    row($0.element)
                }
            }

            Spacer(minLength: 4)

            avatars
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .padding(.horizontal, CommitDetailView.contentInset)
        .font(.system(size: 12))
        .overlay(alignment: .topTrailing) {
            DisclosureTriangleButton(isExpanded: $expanded)
                .frame(width: 13, height: 13)
                .padding(8)
                .accessibilityLabel(AppLocalization.text("history.metadata"))
        }
    }

    /// 当前开合状态下的行；签名行只在展开时接在后面。
    private var rows: [Row] {
        let rows = Self.rows(
            commit,
            expanded: expanded,
            hasReferences: isHead || !references.isEmpty
        )

        guard expanded else {
            return rows
        }

        return rows + Self.signatureRows(signature).map { .text(key: $0.key, value: $0.value) }
    }

    /// 提交人头像在左、作者头像在右，各 80 pt；提交人邮箱与作者相同时只有作者头像。
    private var avatars: some View {
        HStack(spacing: 8) {
            if commit.committerEmail.caseInsensitiveCompare(commit.authorEmail) != .orderedSame {
                InitialsAvatar(name: commit.committer, email: commit.committerEmail, size: 80)
            }

            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 80)
        }
        .padding(.trailing, 12)
    }

    /// 头部的行：展开时依次是作者、作者日期、提交人、提交人日期、引用、哈希、每个父提交一行与树哈希，
    /// 收起时只有作者、作者日期与引用；没有引用时不列引用行。
    ///
    /// - Parameters:
    ///   - commit: 详情显示的提交。
    ///   - expanded: 头部是否展开。
    ///   - hasReferences: 是否有引用指向这个提交，HEAD 也算。
    ///   - locale: 日期所用的语言区域，测试固定。
    ///   - timeZone: 日期所用的时区，测试固定。
    static func rows(
        _ commit: HistoryCommit,
        expanded: Bool,
        hasReferences: Bool,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> [Row] {
        let date = { headerDate($0, locale: locale, timeZone: timeZone) }
        let refs: [Row] = hasReferences ? [.refs] : []

        let author: [Row] = [
            .text(key: "history.author", value: commit.author + " <" + commit.authorEmail + ">"),
            .text(key: "history.authorDate", value: date(commit.authorDate)),
        ]

        guard expanded else {
            return author + refs
        }

        let committer: [Row] = [
            .text(key: "history.committer", value: commit.committer + " <" + commit.committerEmail + ">"),
            .text(key: "history.commitDate", value: date(commit.commitDate)),
        ]

        let hashes: [Row] =
            [.text(key: "history.hash", value: commit.id)]
                + commit.parents.map { .text(key: "history.parentHash", value: $0) }
                + [.text(key: "history.treeHash", value: commit.tree)]

        return author + committer + refs + hashes
    }

    /// 头部的日期：完整日期、时间与时区，按语言区域书写，不随提交列表的日期格式变化。
    ///
    /// - Parameters:
    ///   - date: 作者或提交人日期。
    ///   - locale: 语言区域。
    ///   - timeZone: 时区。
    static func headerDate(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .long

        return formatter.string(from: date)
    }

    /// 签名行的标签键与值：有姓名与邮箱的 OpenPGP 签名是 GPG User、GPG Key、GPG Status，
    /// SSH 与其它签名是 Signing Key、Signing Status；没有短标识时不写密钥行，没有签名时没有签名行。
    static func signatureRows(_ signature: CommitSignature?) -> [(key: String, value: String)] {
        guard let signature, signature.status != .unsigned else {
            return []
        }

        let keyID = signature.shortKeyID
        let status = signature.status.title

        if !signature.isSSH, signature.name != nil, signature.email != nil {
            return [("history.gpgUser", signature.signer)]
                + (keyID.map { [("history.gpgKey", $0)] } ?? [])
                + [("history.gpgStatus", status)]
        }

        return (keyID.map { [("history.signingKey", $0)] } ?? [])
            + [("history.signingStatus", status)]
    }

    /// 一行：标签用三级文字色；值用二级文字色，单行、可选中、尾部截断，引用行是最宽 100、高 16 的引用标记。
    @ViewBuilder
    private func row(_ row: Row) -> some View {
        switch row {
        case .text(let key, let value):
            GridRow(alignment: .firstTextBaseline) {
                label(key)

                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
            }

        case .refs:
            GridRow(alignment: .center) {
                label("history.refs")

                HistoryRefBadges(
                    references: references,
                    isHead: isHead,
                    selected: false,
                    runner: runner,
                    maxWidth: 100
                )
                .frame(height: 16)
            }
        }
    }

    /// 行首的标签。
    private func label(_ key: String) -> some View {
        Text(AppLocalization.text(key))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }
}

// MARK: - ChangesetSummaryBar

/// 变更集摘要行，高 32 pt：左侧全部展开 / 收起，右侧文件数与增删行数；没有文件时不显示按钮。
struct ChangesetSummaryBar: View {
    /// 变更集里的文件。
    let changes: [CommitFileChange]

    /// 当前变更集的全部文件展开时，按钮显示为全部收起。
    let expanded: Bool

    /// 全部展开或全部收起。
    let toggle: () -> Void

    /// 11 pt 文字，摘要用二级文字色。
    var body: some View {
        HStack {
            if showsToggle {
                Button(AppLocalization.text(expanded ? "history.collapseAll" : "history.expandAll"), action: toggle)
                    .buttonStyle(.borderless)
                    .fixedSize()
                    .layoutPriority(1)
            }

            Spacer(minLength: 0)

            Text(Self.summary(changes))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.system(size: 11))
        .padding(.leading, 3)
        .padding(.trailing, 8)
        .frame(height: 32)
    }

    /// 空变更集保留摘要，但没有可展开的文件。
    var showsToggle: Bool { !changes.isEmpty }

    /// 文件数与两类行数分别选择单复数，未知统计按零累计。
    static func summary(_ changes: [CommitFileChange]) -> String {
        AppLocalization.text(
            "history.summary",
            countText("history.summary.files", changes.count),
            countText("history.summary.additions", changes.compactMap(\.additions).reduce(0, +)),
            countText("history.summary.deletions", changes.compactMap(\.deletions).reduce(0, +))
        )
    }

    /// 整页详情工具条的独立文件数。
    static func fileCount(_ count: Int) -> String {
        countText("history.changes", count)
    }

    /// 只有数量为一时选用单数，零与其它数量使用复数。
    private static func countText(_ key: String, _ count: Int) -> String {
        AppLocalization.text(count == 1 ? key + ".one" : key, count)
    }
}
