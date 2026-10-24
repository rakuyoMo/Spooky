import SpookyKit
import SwiftUI

// MARK: - DeleteReferencesDialog

/// 删除本地分支、远端分支、标签或远端前的确认；本地分支可选同时删除跟踪的远端分支与强制删除，标签可选同时从远端删除。
struct DeleteReferencesDialog: View {
    /// 要删除的对象。
    enum Target {
        /// 本地分支。
        case branches([RepositoryReference])

        /// 远端分支。
        case remoteBranches([RepositoryReference])

        /// 本地标签的短名。
        case tags([String])

        /// 远端名。
        case remotes([String])
    }

    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 要删除的对象。
    let target: Target

    /// 关闭 sheet。
    let close: () -> Void

    /// 打开对话框时的仓库；提交时仓库已切换则不执行。
    @State
    private var repository: RepositoryLocation?

    /// 同时删除跟踪的远端分支，只用于一个跟踪远端分支的本地分支。
    @State
    private var deletesUpstream = false

    /// 强制删除未完全合并的分支。
    @State
    private var force = false

    /// 同时从远端删除标签。
    @State
    private var deletesRemoteTags = false

    /// 从哪个远端删除标签。
    @State
    private var remote = ""

    /// 确认说明与按对象出现的勾选项。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text(keys.title),
            message: message,
            submitTitle: AppLocalization.text(keys.submit),
            error: "",
            isValid: true,
            cancel: close,
            submit: submit
        ) {
            options
        }
        .onAppear {
            repository = session.repository
            remote = session.history.snapshot?.remotes.first?.name ?? ""
        }
    }
}

// MARK: - Layout

extension DeleteReferencesDialog {
    /// 本地分支的两个勾选项，或标签的远端选项；其余对象没有内容区。
    @ViewBuilder
    private var options: some View {
        switch target {
        case .branches:
            if let upstream = trackedUpstream {
                ReferenceDialogRows.option(
                    AppLocalization.text("branch.deleteUpstream"),
                    help: AppLocalization.text("branch.deleteUpstream.help", upstream),
                    isOn: $deletesUpstream
                )
            }

            ReferenceDialogRows.option(
                AppLocalization.text("branch.forceDelete"),
                help: AppLocalization.text("branch.forceDelete.help"),
                isOn: $force
            )

        case .tags:
            if let remotes = session.history.snapshot?.remotes, !remotes.isEmpty {
                ReferenceDialogRows.option(
                    AppLocalization.text("tag.deleteRemote"),
                    help: AppLocalization.text("tag.deleteRemote.help"),
                    isOn: $deletesRemoteTags
                )

                ReferenceDialogRows.row(AppLocalization.text("sync.remote")) {
                    Picker("", selection: $remote) {
                        ForEach(remotes) { Text($0.name).tag($0.name) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 350, alignment: .leading)
                    .disabled(!deletesRemoteTags)
                }
            }

        case .remoteBranches, .remotes:
            EmptyView()
        }
    }

    /// 标题与主按钮的文案键：单个与多个各一组；分支与标签的主按钮与标题相同。
    private var keys: (title: String, submit: String) {
        switch target {
        case .branches(let items):
            items.count == 1 ? ("branch.delete", "branch.delete") : ("branch.deleteMultiple", "branch.deleteMultiple")

        case .remoteBranches(let items):
            items.count == 1
                ? ("branch.deleteRemote", "branch.deleteRemote")
                : ("branch.deleteRemoteMultiple", "branch.deleteRemoteMultiple")

        case .tags(let items):
            items.count == 1 ? ("tag.delete", "tag.delete") : ("tag.deleteMultiple", "tag.deleteMultiple")

        case .remotes(let items):
            items.count == 1
                ? ("remote.delete", "remote.delete.submit")
                : ("remote.deleteMultiple", "remote.deleteMultiple.submit")
        }
    }

    /// 单个对象写出名字，多个对象写出个数。
    private var message: String {
        switch target {
        case .branches(let items):
            items.count == 1
                ? AppLocalization.text("branch.delete.message", items[0].name)
                : AppLocalization.text("branch.deleteMultiple.message", items.count)

        case .remoteBranches(let items):
            items.count == 1
                ? AppLocalization.text("branch.deleteRemote.message", items[0].name)
                : AppLocalization.text("branch.deleteRemoteMultiple.message", items.count)

        case .tags(let items):
            items.count == 1
                ? AppLocalization.text("tag.delete.message", items[0])
                : AppLocalization.text("tag.deleteMultiple.message", items.count)

        case .remotes(let items):
            items.count == 1
                ? AppLocalization.text("remote.delete.message", items[0])
                : AppLocalization.text("remote.deleteMultiple.message", items.count)
        }
    }

    /// 只删一个本地分支、且它跟踪远端分支时，那个远端分支的名字。
    private var trackedUpstream: String? {
        guard
            case .branches(let items) = target,
            items.count == 1,
            let remote = items[0].upstreamRemote,
            remote != ".",
            let branch = items[0].upstreamBranch?.dropFirst("refs/heads/".count)
        else {
            return nil
        }

        return remote + "/" + branch
    }
}

// MARK: - Actions

extension DeleteReferencesDialog {
    /// 捕获选项后开始删除；仓库忙碌或已切换时表单保持打开。
    private func submit() {
        guard session.repository == repository, start() else {
            return
        }

        close()
    }

    /// 按对象开始删除，返回是否已开始执行。
    private func start() -> Bool {
        let title = AppLocalization.text(keys.title)

        switch target {
        case .branches(let items):
            return session.deleteBranches(
                items.map(\.id),
                force: force,
                deletingUpstream: deletesUpstream && trackedUpstream != nil
            )

        case .remoteBranches(let items):
            // 按所属远端分组，每个远端一次推送
            let groups = Dictionary(grouping: items.compactMap(session.remoteParts(of:)), by: \.remote)
                .mapValues { $0.map { "refs/heads/" + $0.branch } }

            return session.performGit(
                { runner, output in
                    for (remote, branches) in groups.sorted(by: { $0.key < $1.key }) {
                        try await RepositoryReferences(runner: runner)
                            .deleteRemoteBranches(branches, on: remote, onOutput: output)
                    }
                },
                title: title
            )

        case .tags(let names):
            let remote = deletesRemoteTags && !remote.isEmpty ? remote : nil

            return session.performGit(
                { runner, output in
                    let tags = RepositoryTags(runner: runner)
                    try await tags.delete(names)

                    if let remote {
                        try await tags.deleteRemote(names, on: remote, onOutput: output)
                    }
                },
                title: title,
                undo: remote == nil ? .reversible : .irreversible
            )

        case .remotes(let names):
            return session.performGit(
                { runner, _ in
                    for name in names {
                        try await RepositoryRemotes(runner: runner).remove(name)
                    }
                },
                title: title,
                success: { [session] in
                    if let selected = session.selectedRemote, names.contains(selected) {
                        session.activeView = .history
                        session.onActiveViewChange?()
                    }
                }
            )
        }
    }
}
