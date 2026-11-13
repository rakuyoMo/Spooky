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

/// 提交详情的头部：标签与值两列，右侧作者头像，提交人邮箱不同时再加提交人头像；可在摘要与全部之间切换。
struct CommitMetadataView: View {
    /// 已从列表读取的提交记录。
    let commit: HistoryCommit

    /// 校验过的签名；还没有结果或没有签名时不显示签名行。
    let signature: CommitSignature?

    /// 摘要和全部信息之间切换。
    @State
    private var expanded = false

    /// 信息列与头像列顶端对齐，头像距右 20 pt。
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 4) {
                rows
            }

            Spacer(minLength: 4)

            avatars

            Button {
                expanded.toggle()
            } label: {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .frame(width: 13, height: 13)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(AppLocalization.text("history.metadata"))
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .font(.system(size: 12))
    }

    /// 摘要只有作者、提交日期与哈希；全部信息再加作者日期、提交人、树与父提交。
    @ViewBuilder
    private var rows: some View {
        row("history.author", commit.author + " <" + commit.authorEmail + ">")
        row("history.commitDate", commit.commitDate.formatted(date: .abbreviated, time: .standard))
        row("history.hash", commit.id)

        if expanded {
            row("history.authorDate", commit.authorDate.formatted(date: .abbreviated, time: .standard))
            row("history.committer", commit.committer + " <" + commit.committerEmail + ">")
            row("history.treeHash", commit.tree)
            row("history.parents", commit.parents.joined(separator: "\n"))
        }

        signatureRows
    }

    /// 有签名时的签名行。
    private var signatureRows: some View {
        ForEach(Self.signatureRows(signature), id: \.key) {
            row($0.key, $0.value)
        }
    }

    /// 作者头像 80 pt；提交人邮箱与作者不同时再加提交人头像。
    private var avatars: some View {
        HStack(spacing: 8) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 80)

            if commit.committerEmail.caseInsensitiveCompare(commit.authorEmail) != .orderedSame {
                InitialsAvatar(name: commit.committer, email: commit.committerEmail, size: 80)
            }
        }
        .padding(.trailing, 12)
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

    /// 标签用三级文字色，值用二级文字色，长哈希允许换行。
    private func row(_ key: String, _ value: String) -> some View {
        GridRow(alignment: .top) {
            Text(AppLocalization.text(key))
                .foregroundStyle(.tertiary)

            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
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
