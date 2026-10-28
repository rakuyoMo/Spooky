import SpookyKit
import SwiftUI

// MARK: - RewriteDialogFrame

/// 改写操作对话框共用的骨架：头部、内容、提示、可折叠的选项与底栏。
///
/// 对话框只收集参数，主按钮执行后立即关闭，进度与失败由仓库窗口承接。
struct RewriteDialogFrame<Content: View, Options: View>: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 对话框标题。
    let title: String

    /// 标题下方的说明。
    let help: String

    /// 主按钮的文字。
    let primary: String

    /// 参数完整、可以执行。
    let canSubmit: Bool

    /// 会改写历史：服务器仓库上说明操作在哪台机器上执行。
    var rewritesHistory = false

    /// 输入校验或加载失败的说明；为空时不显示。
    var error = ""

    /// 对话框自己加载数据时底栏的状态文字；为空时不显示。
    var progress = ""

    /// 取消只关闭对话框。
    let cancel: () -> Void

    /// 执行并关闭对话框。
    let submit: () -> Void

    /// 表单内容。
    @ViewBuilder
    let content: () -> Content

    /// 折叠在 Options 里的选项；没有选项时为 EmptyView。
    @ViewBuilder
    let options: () -> Options

    /// 选项展开状态不记忆，每次打开都收起。
    @State
    private var optionsExpanded = false

    /// 自上而下：头部、内容、提示、选项与底栏。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            content()
                .font(.system(size: 13))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            notices

            if Options.self != EmptyView.self {
                DisclosureGroup(AppLocalization.text("dialog.options"), isExpanded: $optionsExpanded) {
                    options()
                        .font(.system(size: 13))
                        .padding(.vertical, 12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppPalette.color("general_secondary_background_color"))
            }

            footer
        }
        .frame(width: 540)
    }
}

// MARK: - Layout

extension RewriteDialogFrame {
    /// 头部：图标、标题、服务器仓库的位置与说明。
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 42))
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))

                // 服务器仓库在标题下写出带主机前缀的位置，本机仓库没有这一行
                if let repository = session.repository, repository.host != nil {
                    Text(repository.displayPath)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(help)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 输入问题、仓库暂不可写与服务器上执行的说明。
    @ViewBuilder
    private var notices: some View {
        if !error.isEmpty {
            notice(error, systemImage: "exclamationmark.triangle")
        }

        // 断线或其它写操作进行中时主按钮禁用，说明原因并保留已填写的参数
        if !session.canWrite {
            notice(AppLocalization.text("dialog.blocked"), systemImage: "exclamationmark.triangle")
        }

        if rewritesHistory, let host = session.repository?.host {
            notice(AppLocalization.text("rewrite.remote", host), systemImage: "server.rack")
        }
    }

    /// 底栏：左侧是对话框自己的加载状态，右侧是取消与主按钮。
    private var footer: some View {
        HStack(spacing: 8) {
            if !progress.isEmpty {
                ProgressView().controlSize(.small)

                Text(progress)
                    .font(.system(size: 13))
            }

            Spacer()

            Button(AppLocalization.text("action.cancel"), action: cancel)
                .keyboardShortcut(.cancelAction)

            Button(primary, action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit || !session.canWrite)
        }
        .padding(.horizontal, 20)
        .frame(height: 53)
    }

    /// 一行 12 pt 的提示，文字可选中。
    private func notice(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 12))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
    }
}

// MARK: - RewriteOption

/// 勾选项加一行 11 pt 的说明，说明与勾选框的标题对齐，只在禁用时随控件变灰。
struct RewriteOption: View {
    /// 勾选项文字的本地化键，说明的键在其后加 `.help`。
    let key: String

    /// 勾选状态。
    @Binding
    var isOn: Bool

    /// 勾选框在上，说明在下。
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(AppLocalization.text(key), isOn: $isOn)

            Text(AppLocalization.text(key + ".help"))
                .font(.system(size: 11))
                .padding(.leading, 19)
                .fixedSize(horizontal: false, vertical: true)
        }
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
