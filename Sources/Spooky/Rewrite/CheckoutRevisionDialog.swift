import SpookyKit
import SwiftUI

// MARK: - CheckoutRevisionDialog

/// 检出任意版本：输入或从引用列表里选；不是本地分支时写明 HEAD 会分离在哪个提交上。
struct CheckoutRevisionDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 预填的版本；为 nil 时为空。
    let revision: String?

    /// 关闭对话框。
    let close: () -> Void

    /// 输入或选中的版本。
    @State
    private var target = ""

    /// 解析出的去向与解析失败的说明，记着对应的版本；输入停顿期间仍显示上一次的，主按钮不可用。
    @State
    private var destination = RevisionPreview<String, CheckoutTarget>()

    /// 版本组合框与去向说明；仓库还没有引用时错误区说明原因，仍可直接输入版本。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("rewrite.checkout.title"),
            message: AppLocalization.text("rewrite.checkout.help"),
            submitTitle: AppLocalization.text("rewrite.checkout.button"),
            error: notice,
            isValid: destination.value(for: target) != nil,
            cancel: close,
            submit: perform
        ) {
            rows
        }
        .onAppear { target = revision ?? "" }
        .task(id: target) { await resolve() }
    }
}

// MARK: - Layout

extension CheckoutRevisionDialog {
    /// 错误区的文字：版本解析失败的说明；仓库还没有引用时说明原因。
    private var notice: String {
        guard destination.error.isEmpty, session.revisionCandidates.isEmpty else {
            return destination.error
        }

        return AppLocalization.text("rewrite.noRefs")
    }

    /// 填满输入列的版本组合框，以及分离 HEAD 时的说明。
    @ViewBuilder
    private var rows: some View {
        // 组合框是 AppKit 控件，没有文字基线可对，标签与它按竖直居中对齐
        DialogFormRow(label: AppLocalization.text("rewrite.revision"), alignment: .center) {
            RevisionComboBox(
                text: $target,
                items: session.revisionCandidates,
                label: AppLocalization.text("rewrite.revision"),
                visibleItems: 10,
                completes: true
            )
        }

        if case .detached(let commit) = destination.value {
            DialogFormField {
                Label(
                    AppLocalization.text("rewrite.checkout.detached", String(commit.prefix(8))),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Actions

extension CheckoutRevisionDialog {
    /// 输入停顿后判断去向；无法解析时说明原因，主按钮不可用。
    private func resolve() async {
        let input = target

        // 输入停顿期间保留上一次的去向与错误，新结果出来后一次替换
        guard !input.isEmpty, let runner = session.runner else {
            DialogAnimation.perform { destination.show(nil, for: input) }
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
            let found = try await RepositoryRewrite(runner: runner).checkoutTarget(for: input)
            try Task.checkCancellation()

            DialogAnimation.perform { destination.show(found, for: input) }
        } catch {
            if !Task.isCancelled {
                DialogAnimation.perform {
                    destination.show(nil, error: AppLocalization.text("rewrite.error.revision"), for: input)
                }
            }
        }
    }

    /// 检出；仓库暂不可写时对话框保持打开。
    private func perform() {
        if session.checkout(revision: target) { close() }
    }
}
