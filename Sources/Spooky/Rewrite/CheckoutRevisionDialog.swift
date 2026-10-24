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

    /// 解析出的去向；解析之前或失败时为 nil。
    @State
    private var destination: CheckoutTarget?

    /// 版本解析失败的说明。
    @State
    private var error = ""

    /// 版本组合框与去向说明。
    var body: some View {
        RewriteDialogFrame(
            session: session,
            title: AppLocalization.text("rewrite.checkout.title"),
            help: AppLocalization.text("rewrite.checkout.help"),
            primary: AppLocalization.text("rewrite.checkout.button"),
            canSubmit: destination != nil,
            error: session.revisionCandidates.isEmpty && error.isEmpty ? AppLocalization.text("rewrite.noRefs") : error,
            cancel: close,
            submit: perform
        ) {
            form
        } options: {
            EmptyView()
        }
        .onAppear { target = revision ?? "" }
        .task(id: target) { await resolve() }
    }
}

// MARK: - Layout

extension CheckoutRevisionDialog {
    /// 版本输入与分离 HEAD 的说明。
    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
            GridRow {
                Text(AppLocalization.text("rewrite.revision")).gridColumnAlignment(.trailing)

                RevisionComboBox(
                    text: $target,
                    items: session.revisionCandidates,
                    label: AppLocalization.text("rewrite.revision"),
                    visibleItems: 10,
                    completes: true
                )
                .frame(maxWidth: 350)
            }

            if case .detached(let commit) = destination {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

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
}

// MARK: - Actions

extension CheckoutRevisionDialog {
    /// 输入停顿后判断去向；无法解析时说明原因，主按钮不可用。
    private func resolve() async {
        destination = nil

        guard !target.isEmpty, let runner = session.runner else {
            error = ""
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
            let resolved = try await RepositoryRewrite(runner: runner).checkoutTarget(for: target)
            try Task.checkCancellation()

            destination = resolved
            error = ""
        } catch {
            if !Task.isCancelled { self.error = AppLocalization.text("rewrite.error.revision") }
        }
    }

    /// 检出；仓库暂不可写时对话框保持打开。
    private func perform() {
        if session.checkout(revision: target) { close() }
    }
}
