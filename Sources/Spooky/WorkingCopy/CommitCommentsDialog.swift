import AppKit
import SwiftUI

// MARK: - CommitCommentsDialog

/// 提交信息含注释行时的询问：删除或保留注释，可以勾选不再询问；去掉注释后信息为空时只能保留注释提交。
///
/// 没有输入区，头部文字、勾选框与按钮组都对齐距左 120 pt 的对齐线，应用图标挂在左侧。
struct CommitCommentsDialog: View {
    /// 去掉注释后信息是否为空。
    let empty: Bool

    /// 关闭对话框并交回选择与是否不再询问；取消时选择为 nil。
    let finish: (CommentHandling?, Bool) -> Void

    /// 勾选后把这次的选择存为 Editor 设置，以后不再询问。
    @State
    private var doNotAskAgain = false

    /// 头部、不再询问的勾选框与底栏。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if !empty {
                Toggle(AppLocalization.text("commit.doNotAskAgain"), isOn: $doNotAskAgain)
                    .toggleStyle(.checkbox)
                    .padding(.leading, Self.alignment)
                    .padding(.trailing, 20)
                    .padding(.vertical, 8)
            }

            footer
        }
        .frame(minWidth: 480)
    }
}

// MARK: - Private

extension CommitCommentsDialog {
    /// 头部文字、勾选框与按钮组共用的左对齐线。
    private static let alignment = 120.0

    /// 64 pt 应用图标与右侧的标题、说明；文字列默认宽 340 pt，按钮组需要更宽的窗口时随之加宽。
    private var header: some View {
        HStack(alignment: .top, spacing: Self.alignment - 32 - 64) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text(empty ? "commit.commentsOnly" : "commit.comments"))
                    .font(.system(size: 14, weight: .bold))

                Text(AppLocalization.text(empty ? "commit.commentsOnly.help" : "commit.comments.help"))
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(idealWidth: 340, maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 32)
        .padding(.trailing, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 能删除注释时取消贴在按钮组左端，保留与删除贴右端；只能保留时取消与保留并排在右端。
    private var footer: some View {
        HStack(spacing: 8) {
            if empty {
                Spacer(minLength: 0)
            }

            button("action.cancel") { finish(nil, false) }
                .keyboardShortcut(.cancelAction)

            if empty {
                button("commit.keepCommentsAndCommit") { finish(.keep, false) }
                    .keyboardShortcut(.defaultAction)
            } else {
                Spacer(minLength: 0)

                button("commit.keepComments") { finish(.keep, doNotAskAgain) }

                button("commit.removeComments") { finish(.remove, doNotAskAgain) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.leading, empty ? 20 : Self.alignment)
        .padding(.trailing, 20)
        .padding(.top, 12)
        .frame(height: 53, alignment: .top)
    }

    /// 最小 70 pt 宽、文字不截断的按钮；按钮组放不下时对话框随之加宽。
    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(AppLocalization.text(title))
                .frame(minWidth: 56)
        }
        .fixedSize()
    }
}
