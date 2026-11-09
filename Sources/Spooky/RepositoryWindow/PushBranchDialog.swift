import SpookyKit
import SwiftUI

// MARK: - PushBranchDialog

/// 本地分支拖到远端分支时的 Push Branch 对话框：只有本地分支与远端分支两个下拉，按拖动源与落点预选，没有推送选项。
///
/// 推送只作用于所选的这一对分支，不读推送表单保存的全部标签与子模块偏好；所选分支已不在候选里时不能提交。
struct PushBranchDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 拖放给出的预选。
    let request: PushBranchRequest

    /// 关闭 sheet。
    let close: () -> Void

    /// 所选本地分支的完整引用名。
    @State
    private var localBranch = ""

    /// 所选远端分支的完整引用名。
    @State
    private var remoteBranch = ""

    /// 对话框骨架：头部、两个下拉与底栏。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("sync.pushBranch"),
            message: AppLocalization.text("sync.pushBranch.help"),
            width: 450,
            submitTitle: AppLocalization.text("sync.pushBranch"),
            error: "",
            isValid: selection != nil,
            cancel: close,
            submit: perform
        ) {
            picker("branch.local", selection: $localBranch, references: localBranches)

            picker("sync.remoteBranch", selection: $remoteBranch, references: remoteBranches)
        }
        .onAppear {
            localBranch = request.localBranch
            remoteBranch = request.remoteBranch
        }
    }

    /// 本地分支的候选。
    private var localBranches: [RepositoryReference] {
        session.history.branches.filter(\.isLocal)
    }

    /// 远端分支的候选：已配置远端上的远端跟踪分支。
    private var remoteBranches: [RepositoryReference] {
        RepositoryOperationDialog.pushDestinations(in: session)
    }

    /// 所选的两个分支；任一已不在候选里时为 nil。
    private var selection: (local: RepositoryReference, remote: RepositoryReference)? {
        guard
            let local = localBranches.first(where: { $0.id == localBranch }),
            let remote = remoteBranches.first(where: { $0.id == remoteBranch })
        else { return nil }

        return (local, remote)
    }

    /// 列出分支短名的下拉。
    ///
    /// - Parameters:
    ///   - label: 标签的资源键。
    ///   - selection: 所选分支的完整引用名。
    ///   - references: 候选分支。
    private func picker(
        _ label: String,
        selection: Binding<String>,
        references: [RepositoryReference]
    ) -> some View {
        RepositoryDialogRows.row(AppLocalization.text(label)) {
            Picker("", selection: selection) {
                ForEach(references) { Text($0.name).tag($0.id) }
            }
            .labelsHidden()
            .buttonSizing(.flexible)
            .dialogFieldWidth(320)
        }
    }

    /// 提交时再核对一次两个分支，推送开始后关闭；仓库暂不可写时表单保持打开。
    private func perform() {
        guard let selection, session.pushBranch(selection.local, to: selection.remote) else {
            return
        }

        close()
    }
}
