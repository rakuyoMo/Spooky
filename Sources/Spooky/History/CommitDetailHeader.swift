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

    #warning(
        "TODO: 详情头部签名行的取舍是推断：有姓名与邮箱的 OpenPGP 签名显示 GPG User / GPG Key / GPG Status，其余只显示 Signing Status。核实方式：分别打开 OpenPGP 与 SSH 签名的提交，对照详情头部出现哪些行；只影响这几行。"
    )

    /// 有签名时的签名行。
    @ViewBuilder
    private var signatureRows: some View {
        if let signature, signature.status != .unsigned {
            if signature.name != nil {
                row("history.gpgUser", signature.signer)
                row("history.gpgKey", signature.key)
                row("history.gpgStatus", signature.status.title)
            } else {
                row("history.signingStatus", signature.status.title)
            }
        }
    }

    /// 作者头像 80 pt；提交人邮箱与作者不同时再加提交人头像。
    private var avatars: some View {
        HStack(spacing: 8) {
            InitialsAvatar(name: commit.author, size: 80)

            if commit.committerEmail.caseInsensitiveCompare(commit.authorEmail) != .orderedSame {
                InitialsAvatar(name: commit.committer, size: 80)
            }
        }
        .padding(.trailing, 12)
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

    /// 已有文件展开时按钮显示为全部收起。
    let expanded: Bool

    /// 全部展开或全部收起。
    let toggle: () -> Void

    /// 11 pt 文字，摘要用二级文字色。
    var body: some View {
        HStack {
            if !changes.isEmpty {
                Button(AppLocalization.text(expanded ? "history.collapseAll" : "history.expandAll"), action: toggle)
                    .buttonStyle(.borderless)
            }

            Spacer()

            Text(summary)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .padding(.leading, 3)
        .padding(.trailing, 8)
        .frame(height: 32)
    }

    /// 有增删行数时一起列出；组合 Diff 等没有统计的变更集只列文件数。
    private var summary: String {
        let counted = changes.filter { $0.additions != nil }

        guard !counted.isEmpty else {
            return AppLocalization.text("history.changes", changes.count)
        }

        return AppLocalization.text(
            "history.summary",
            changes.count,
            counted.compactMap(\.additions).reduce(0, +),
            counted.compactMap(\.deletions).reduce(0, +)
        )
    }
}
