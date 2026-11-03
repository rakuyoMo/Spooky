import SwiftUI

// MARK: - CommitCommentsDialog

/// 提交信息含注释行时的询问：删除或保留注释，可以勾选不再询问；去掉注释后信息为空时只能保留注释提交。
///
/// 骨架的确认版：能删除注释时用备选底栏，Cancel 贴按钮组左端，Keep Comments 与 Remove Comments 贴右端，
/// 内容区是不再询问的勾选框；只能保留注释时只有 Cancel 与 Keep Comments and Commit。
struct CommitCommentsDialog: View {
    /// 去掉注释后信息是否为空。
    let empty: Bool

    /// 关闭对话框。
    let close: () -> Void

    /// 交回选择与是否不再询问，此时对话框已经关闭；取消时不调用。
    let finish: (CommentHandling, Bool) -> Void

    /// 头部、不再询问的勾选框与底栏。
    var body: some View {
        ConfirmationDialog(
            title: AppLocalization.text(empty ? "commit.commentsOnly" : "commit.comments"),
            message: AppLocalization.text(empty ? "commit.commentsOnly.help" : "commit.comments.help"),
            submitTitle: AppLocalization.text(empty ? "commit.keepCommentsAndCommit" : "commit.removeComments"),
            alternate: empty
                ? nil
                : (
                    title: AppLocalization.text("commit.keepComments"),
                    action: { finish(.keep, $0) }
                ),
            checkbox: empty ? nil : AppLocalization.text("commit.doNotAskAgain"),
            close: close
        ) { doNotAskAgain in
            finish(empty ? .keep : .remove, doNotAskAgain)
        }
    }
}
