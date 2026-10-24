import SpookyKit
import SwiftUI

// MARK: - PublishTagDialog

/// 发布标签：选一个本地标签与一个远端，在远端新建同名标签；选项区可跳过钩子。
struct PublishTagDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 预选的标签短名；为 nil 时选第一个标签。
    let tag: String?

    /// 关闭 sheet。
    let close: () -> Void

    /// 打开对话框时的仓库；提交时仓库已切换则不执行。
    @State
    private var repository: RepositoryLocation?

    /// 选中的标签短名。
    @State
    private var selectedTag = ""

    /// 选中的远端。
    @State
    private var remote = ""

    /// 跳过钩子只在本次表单生效。
    @State
    private var skipHooks = false

    /// “Local Tag:” 与 “Remote:” 两个下拉。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text("tag.publish"),
            message: AppLocalization.text("tag.publish.message"),
            submitTitle: AppLocalization.text("tag.publish"),
            error: error,
            isValid: !selectedTag.isEmpty && !remote.isEmpty,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(AppLocalization.text("tag.local")) {
                Picker("", selection: $selectedTag) {
                    ForEach(session.tags) { Text($0.name).tag($0.name) }
                }
                .labelsHidden()
            }

            ReferenceDialogRows.row(AppLocalization.text("sync.remote")) {
                Picker("", selection: $remote) {
                    ForEach(session.history.snapshot?.remotes ?? []) { Text($0.name).tag($0.name) }
                }
                .labelsHidden()
            }
        } options: {
            ReferenceOption(
                title: AppLocalization.text("sync.skipHooks"),
                help: AppLocalization.text("sync.skipHooks.help"),
                isOn: $skipHooks
            )
        }
        .onAppear(perform: prepare)
    }
}

// MARK: - Actions

extension PublishTagDialog {
    /// 没有本地标签或没有远端时说明原因。
    private var error: String {
        if session.tags.isEmpty {
            return AppLocalization.text("tag.noTags")
        }

        if session.history.snapshot?.remotes.isEmpty ?? true {
            return AppLocalization.text("sync.noRemotes")
        }

        return ""
    }

    /// 预选入口指定的标签与当前分支的上游远端。
    private func prepare() {
        repository = session.repository
        selectedTag = tag ?? session.tags.first?.name ?? ""

        let remotes = session.history.snapshot?.remotes.map(\.name) ?? []
        let head = session.history.branches.first { $0.isLocal && $0.name == session.status?.branch.head }
        let upstream = head?.upstreamRemote.flatMap { remotes.contains($0) ? $0 : nil }
        remote = upstream ?? remotes.first ?? ""
    }

    /// 捕获表单值后开始推送；仓库忙碌或已切换时表单保持打开。
    private func submit() {
        let tag = selectedTag
        let remote = remote
        let skipHooks = skipHooks

        guard session.repository == repository else {
            return
        }

        let started = session.performGit(
            { runner, output in
                try await RepositoryTags(runner: runner).publish(tag, to: remote, skipHooks: skipHooks, onOutput: output)
            },
            title: AppLocalization.text("tag.publish")
        )

        if started {
            close()
        }
    }
}
