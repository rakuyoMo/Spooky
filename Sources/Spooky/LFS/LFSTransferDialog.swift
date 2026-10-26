import SpookyKit
import SwiftUI

// MARK: - LFSTransferDialog

/// LFS 对象的获取、拉取与推送：选一个远端，传输进度写进 Activity；仓库还没有远端时说明原因。
struct LFSTransferDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 传输的种类。
    let transfer: LFSTransfer

    /// 关闭 sheet。
    let close: () -> Void

    /// 选中的远端。
    @State
    private var remote = ""

    /// 一个 “Remote:” 下拉。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: transfer.title,
            message: message,
            submitTitle: submitTitle,
            error: remotes.isEmpty ? AppLocalization.text("sync.noRemotes") : "",
            isValid: remotes.contains(remote),
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(AppLocalization.text("sync.remote")) {
                Picker("", selection: $remote) {
                    ForEach(remotes, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
            }
        }
        .onAppear(perform: prepare)
    }
}

// MARK: - Private

extension LFSTransferDialog {
    /// 仓库的远端名。
    private var remotes: [String] {
        session.history.snapshot?.remotes.map(\.name) ?? []
    }

    /// 说明这次传输做什么。
    private var message: String {
        switch transfer {
        case .fetch: AppLocalization.text("lfs.fetch.message")
        case .pull: AppLocalization.text("lfs.pull.message")
        case .push: AppLocalization.text("lfs.push.message")
        }
    }

    /// 主按钮标题。
    private var submitTitle: String {
        switch transfer {
        case .fetch: AppLocalization.text("sync.fetch")
        case .pull: AppLocalization.text("sync.pull")
        case .push: AppLocalization.text("sync.push")
        }
    }

    /// 预选当前分支的上游远端，没有上游时选第一个远端。
    private func prepare() {
        let head = session.history.branches.first { $0.isLocal && $0.name == session.status?.branch.head }
        remote = head?.upstreamRemote.flatMap { remotes.contains($0) ? $0 : nil } ?? remotes.first ?? ""
    }

    /// 开始传输后关闭；仓库暂不可写时保留对话框。
    private func submit() {
        if session.transferLFS(transfer, remote: remote) {
            close()
        }
    }
}
