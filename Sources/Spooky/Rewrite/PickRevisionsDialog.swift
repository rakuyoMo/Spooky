import SpookyKit
import SwiftUI

// MARK: - PickRevisionsDialog

/// 反转与摘取的对话框：打开后先读取所选提交，涉及合并提交时选择主线。
struct PickRevisionsDialog: View {
    /// 对话框种类。
    enum Kind {
        /// 生成抵消所选提交的提交。
        case revert

        /// 把所选提交的改动应用到当前 HEAD。
        case cherryPick
    }

    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 反转或摘取。
    let kind: Kind

    /// 所选提交，按历史列表从新到旧。
    let commits: [String]

    /// 关闭对话框。
    let close: () -> Void

    /// 合并提交的父提交，按 Git 的顺序；不是合并提交时为空。
    @State
    private var parents: [HistoryCommit] = []

    /// 选中的主线，从 1 开始。
    @State
    private var mainline = 1

    /// 正在读取提交信息。
    @State
    private var loading = true

    /// 读取失败或选择不被允许的说明。
    @State
    private var error = ""

    /// 反转后直接提交，跨仓库记忆。
    @AppStorage("revertAutoCommit")
    private var revertCommits = true

    /// 摘取后直接提交，跨仓库记忆。
    @AppStorage("cherryPickCommit")
    private var pickCommits = true

    /// 摘取时能快进就快进，跨仓库记忆。
    @AppStorage("cherryPickFastForward")
    private var fastForward = false

    /// 内容区是直接提交的选项，选项区是主线与快进。
    var body: some View {
        RewriteDialogFrame(
            session: session,
            title: AppLocalization.text(titleKey),
            help: help,
            primary: AppLocalization.text(kind == .revert ? "rewrite.revert.button" : "rewrite.cherryPick.button"),
            canSubmit: !loading && error.isEmpty,
            error: error,
            progress: loading ? AppLocalization.text("rewrite.loadingCommits") : "",
            cancel: close,
            submit: perform
        ) {
            RewriteOption(
                key: kind == .revert ? "rewrite.revert.commit" : "rewrite.cherryPick.commit",
                isOn: kind == .revert ? $revertCommits : $pickCommits
            )
        } options: {
            options
        }
        .task { await load() }
    }
}

// MARK: - Layout

extension PickRevisionsDialog {
    /// 一个提交与多个提交的标题不同。
    private var titleKey: String {
        switch kind {
        case .revert: commits.count == 1 ? "rewrite.revert.title.one" : "rewrite.revert.title"
        case .cherryPick: commits.count == 1 ? "rewrite.cherryPick.title.one" : "rewrite.cherryPick.title"
        }
    }

    /// 说明写出提交数。
    private var help: String {
        switch kind {
        case .revert:
            commits.count == 1
                ? AppLocalization.text("rewrite.revert.help.one")
                : AppLocalization.text("rewrite.revert.help", commits.count)

        case .cherryPick:
            AppLocalization.text("rewrite.cherryPick.help")
        }
    }

    /// 主线只在涉及合并提交时可选；快进只对直接提交的摘取有效。
    private var options: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(AppLocalization.text("rewrite.mainline"))

                Picker("", selection: $mainline) {
                    ForEach(Array(parents.enumerated()), id: \.offset) { index, parent in
                        Text("\(parent.shortID) \(parent.subject)").tag(index + 1)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 350)
                .accessibilityLabel(AppLocalization.text("rewrite.mainline"))
            }
            .disabled(parents.count < 2)

            Text(AppLocalization.text("rewrite.mainline.help"))
                .font(.system(size: 11))
                .foregroundStyle(parents.count < 2 ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)

            if kind == .cherryPick {
                Divider()

                RewriteOption(key: "rewrite.cherryPick.fastForward", isOn: $fastForward)
                    .disabled(!pickCommits)
            }
        }
    }
}

// MARK: - Actions

extension PickRevisionsDialog {
    /// 读取所选提交；多个提交里有合并提交时不允许，只有一个合并提交时再读取它的父提交供选择主线。
    private func load() async {
        guard let runner = session.runner else { return }

        do {
            let rewrite = RepositoryRewrite(runner: runner)
            let loaded = try await rewrite.commits(commits)

            if loaded.count > 1, loaded.contains(where: { $0.parents.count > 1 }) {
                error = AppLocalization.text("rewrite.error.multipleMerges")
            } else if let merge = loaded.first, merge.parents.count > 1 {
                parents = try await rewrite.commits(merge.parents)
            }
        } catch {
            if !Task.isCancelled { self.error = AppLocalization.text("rewrite.error.loadCommits") }
        }

        loading = false
    }

    /// 按选项执行；仓库暂不可写时对话框保持打开。
    private func perform() {
        var options = PickOptions()
        options.commit = kind == .revert ? revertCommits : pickCommits
        options.mainline = parents.count > 1 ? mainline : nil
        options.fastForward = kind == .cherryPick && fastForward

        let started =
            switch kind {
            case .revert: session.revert(commits, options: options)
            case .cherryPick: session.cherryPick(commits, options: options)
            }

        if started { close() }
    }
}
