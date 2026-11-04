import AppKit
import SpookyKit
import SwiftUI

// MARK: - Alerts

extension RepositoryWindowController {
    /// 以 Git 错误框挂成 sheet；窗口已有 sheet 时排在它后面。拉大后的尺寸记在 `GitErrorDialog` 名下。
    func showFailure(_ failure: AppFailure) {
        guard let window else {
            return
        }

        DialogWindow.present(on: window, autosaveName: "GitErrorDialog") { [weak self] close in
            GitErrorDialog(
                failure: failure,
                close: close,
                chooseAnother: failure.isOpeningFailure ? { self?.chooseAnotherRepository(after: failure) } : nil
            )
        }
    }

    /// 以确认版对话框挂成 sheet 请用户确认；窗口已有 sheet 时不叠加。
    func showConfirmation(_ request: ConfirmationRequest) {
        presentDialog { close in
            ConfirmationDialog(request: request, close: close)
        }
    }

    /// 合并没有暂存的改动时询问建空合并提交还是中止合并：系统提示框，两个按钮都会执行动作。
    ///
    /// - Parameters:
    ///   - commit: 建空合并提交，sheet 已经结束。
    ///   - abort: 中止合并，sheet 已经结束。
    func showEmptyMergePrompt(commit: @escaping () -> Void, abort: @escaping () -> Void) {
        guard let window, window.attachedSheet == nil else { return }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppLocalization.text("working.emptyMerge")
        alert.informativeText = AppLocalization.text("working.emptyMerge.message")
        alert.addButton(withTitle: AppLocalization.text("working.emptyMerge"))
        alert.addButton(withTitle: AppLocalization.text("working.abort"))

        // Sheet 已结束后才开始写入，错误与进度由仓库视图承接
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                commit()
            } else if response == .alertSecondButtonReturn {
                abort()
            }
        }
    }

    /// 重连核对后以提示版报告中断写入的结果：HEAD 是否变化与仓库状态；写入没有被重试。
    func showRecovery(_ write: InterruptedWrite, snapshot: RemoteRecoverySnapshot?) {
        guard let window else {
            return
        }

        // 中断时的错误框可能还开着，AppKit 会在它结束后再挂上这一个
        DialogWindow.present(on: window) { close in
            Self.recoveryNotice(write, snapshot: snapshot, in: session.repository, close: close)
        }
    }
}

// MARK: - Notices

extension RepositoryWindowController {
    /// 中断写入的恢复说明：骨架的提示版，只有 Close；说明是核对结果，空一行后写出仓库。
    ///
    /// - Parameters:
    ///   - write: 被中断的写入。
    ///   - snapshot: 重连后的核对结果；为 nil 时写入未在服务器上开始。
    ///   - repository: 写入所在的仓库；为 nil 时不写仓库一行。
    ///   - close: 关掉提示。
    static func recoveryNotice(
        _ write: InterruptedWrite,
        snapshot: RemoteRecoverySnapshot?,
        in repository: RepositoryLocation?,
        close: @escaping () -> Void
    ) -> DialogLayout<EmptyView, EmptyView> {
        DialogLayout(
            title: AppLocalization.text("recovery.title"),
            message: recoveryMessage(write, snapshot: snapshot)
                + (repository.map { "\n\n" + AppLocalization.text("failure.location", $0.displayPath) } ?? ""),
            submitTitle: AppLocalization.text("action.close"),
            cancel: nil,
            submit: close
        )
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 打开失败后重新选择：服务器仓库重新打开添加服务器的表单，本机仓库重新选目录。
    ///
    /// 两者都等错误框从窗口上收起后再打开：目录面板以模态运行，否则会一直留在面板后面；表单在窗口已有 sheet 时不会挂上。
    private func chooseAnotherRepository(after failure: AppFailure) {
        Task { [weak self] in
            if failure.isRemoteFailure {
                self?.addRemoteRepository()
            } else {
                self?.coordinator?.openRepositoryPanel()
            }
        }
    }
}
