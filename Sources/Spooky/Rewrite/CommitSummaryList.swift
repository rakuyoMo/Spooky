import SwiftUI

// MARK: - CommitSummaryList

/// 影响范围里的提交：短哈希、标题与右侧的去向说明，最多显示约八行，超出时滚动。
struct CommitSummaryList: View {
    /// 一行的内容。
    struct Row: Identifiable {
        /// 提交哈希。
        let id: String

        /// 提交标题。
        let subject: String

        /// 去向说明，如 “删除” “并入上一提交”；为空时不显示。
        var note = ""

        /// 是否已推送或已并入其它分支，以警告色标出。
        var isShared = false
    }

    /// 从新到旧的行。
    let rows: [Row]

    /// 每行等宽短哈希加标题。
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(rows) { row in
                    HStack(spacing: 8) {
                        Text(row.id.prefix(8))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Text(row.subject)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 8)

                        if !row.note.isEmpty {
                            Text(row.note)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        if row.isShared {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color(nsColor: .systemYellow))
                                .accessibilityLabel(AppLocalization.text("rewrite.shared"))
                        }
                    }
                    .font(.system(size: 12))
                }
            }
            .padding(8)
        }
        .frame(height: min(CGFloat(rows.count), 8) * 20 + 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppPalette.color("general_border_color")))
    }
}

// MARK: - RewriteWarnings

/// 改写已推送或已并入其它分支的提交时的警告；两者都没有时不显示。
struct RewriteWarnings: View {
    /// 范围里有已推送到上游的提交。
    let pushed: Bool

    /// 范围里有已并入其它分支的提交。
    let merged: Bool

    /// 每种情况一行，以系统黄色的警告符号开头。
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if pushed { warning("rewrite.warning.pushed") }

            if merged { warning("rewrite.warning.merged") }
        }
    }

    /// 一行警告。
    private func warning(_ key: String) -> some View {
        Label {
            Text(AppLocalization.text(key))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(nsColor: .systemYellow))
        }
        .font(.system(size: 12))
    }
}
