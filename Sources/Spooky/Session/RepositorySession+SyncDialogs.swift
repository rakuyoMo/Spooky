import Foundation
import SpookyKit

// MARK: - SyncDialogRequest

/// 同步相关对话框的请求：种类与入口预选的分支或版本，由仓库窗口以 sheet 呈现。
struct SyncDialogRequest {
    /// 对话框种类。
    let kind: SyncDialogKind

    /// 变基的目标分支（完整引用名），或推送任意版本的来源（分支名或标签名）；为 nil 时按 HEAD 的跟踪关系预选。
    var preselection: String? = nil
}

// MARK: - Requests

extension RepositorySession {
    /// 请求打开同步相关对话框；侧边栏与标签的右键菜单经它预选右键的分支或标签。
    func requestSyncDialog(_ kind: SyncDialogKind, preselecting preselection: String? = nil) {
        guard canWrite else {
            return
        }

        onSyncRequest?(SyncDialogRequest(kind: kind, preselection: preselection))
    }
}
