import SpookyKit
import SwiftUI

// MARK: - SetParentBranchDialog

/// 为本地分支选择父分支：候选是其它本地分支与远端分支，已有父分支时预先选中并说明会被替换。
struct SetParentBranchDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 要设置父分支的本地分支。
    let branch: RepositoryReference

    /// 关闭 sheet。
    let close: () -> Void

    /// 打开对话框时的仓库；提交时仓库已切换则不执行。
    @State
    private var repository: RepositoryLocation?

    /// 当前的父分支；读取完成前为 nil。
    @State
    private var currentParent: String?

    /// 选中的父分支完整引用名。
    @State
    private var parent = ""

    /// 读取父分支失败的说明。
    @State
    private var error = ""

    /// “Parent:” 下拉，宽不超过 350。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text("branch.parent.set"),
            message: message,
            submitTitle: AppLocalization.text("branch.parent.set"),
            error: error,
            isValid: !parent.isEmpty && parent != currentParent,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(AppLocalization.text("branch.parent.field")) {
                Picker("", selection: $parent) {
                    ForEach(candidates) { Text($0.name).tag($0.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 350, alignment: .leading)
            }
        }
        .task { await load() }
    }
}

// MARK: - Actions

extension SetParentBranchDialog {
    /// 父分支的候选：其它本地分支在前，远端分支在后。
    private var candidates: [RepositoryReference] {
        let branches = session.history.branches.filter { $0.id != branch.id }
        return branches.filter(\.isLocal) + branches.filter(\.isRemote)
    }

    /// 说明写出分支名；已有父分支时补一句它会被替换。
    private var message: String {
        let base = AppLocalization.text("branch.parent.message", branch.name)

        guard let currentParent else {
            return base
        }

        let name = candidates.first { $0.id == currentParent }?.name ?? currentParent
        return base + "\n\n" + AppLocalization.text("branch.parent.replace", name)
    }

    /// 读出当前的父分支并预先选中；没有时选中第一个候选。
    private func load() async {
        repository = session.repository
        parent = candidates.first?.id ?? ""

        guard let runner = session.runner else {
            return
        }

        do {
            currentParent = try await RepositoryReferences(runner: runner).metadata()[branch.id]?.parent

            if let currentParent, candidates.contains(where: { $0.id == currentParent }) {
                parent = currentParent
            }
        } catch {
            self.error = ReferenceDialogRows.validationMessage(error, in: session)
        }
    }

    /// 写入父分支；仓库忙碌或已切换时表单保持打开。
    private func submit() {
        let parent = parent
        let branch = branch

        guard session.repository == repository else {
            return
        }

        let started = session.performGit(
            { runner, _ in try await RepositoryReferences(runner: runner).setParent(parent, of: branch.id) },
            title: AppLocalization.text("branch.parent.set"),
            undo: .reversible
        )

        if started {
            close()
        }
    }
}
