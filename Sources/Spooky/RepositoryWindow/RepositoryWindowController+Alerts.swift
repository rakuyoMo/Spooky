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

    /// 进行中的操作没有任何改动时确认是否保留空提交；窗口已有 sheet 时不叠加。
    func showEmptyCommitPrompt(_ request: EmptyCommitRequest) {
        presentDialog { close in
            Self.emptyCommitDialog(request, close: close)
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
    /// 空提交的确认：主按钮保留空提交，备选是中止当前操作或跳过这一步，内容区是不再提示的勾选框。
    ///
    /// 勾上不再提示时，无论选哪个按钮（包括 Cancel）都关掉这项警告；Cancel 不执行 Git。
    ///
    /// - Parameters:
    ///   - request: 会话发来的确认请求。
    ///   - close: 关闭对话框。
    static func emptyCommitDialog(_ request: EmptyCommitRequest, close: @escaping () -> Void) -> ConfirmationDialog {
        let remember: (_ checked: Bool) -> Void = { checked in
            if checked {
                UserDefaults.standard.set(false, forKey: WorkingCopyPreferences.warnsEmptyCommit)
            }
        }

        let keys = request.isSequence
            ? (message: "commit.empty.sequenceMessage", alternate: "commit.empty.skip")
            : (message: "commit.empty.message", alternate: "commit.empty.abort")

        return ConfirmationDialog(
            title: AppLocalization.text("commit.empty.title"),
            message: AppLocalization.text(keys.message),
            submitTitle: AppLocalization.text("commit.empty.use"),
            alternate: (
                title: AppLocalization.text(keys.alternate),
                action: { checked in
                    remember(checked)
                    request.alternate()
                }
            ),
            checkbox: AppLocalization.text("commit.empty.doNotShowAgain"),
            close: close,
            cancel: remember
        ) { checked in
            remember(checked)
            request.commit()
        }
    }

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

    /// 核对结果的说明：没有新的核对表示写入未在服务器上开始，否则比较写入前后的 HEAD。
    static func recoveryMessage(_ write: InterruptedWrite, snapshot: RemoteRecoverySnapshot?) -> String {
        guard let snapshot else {
            return AppLocalization.text("recovery.notStarted", write.title)
        }

        let before = write.branch?.oid
        let after = snapshot.status.branch.oid
        let name: (String?) -> String = { $0.map { String($0.prefix(8)) } ?? AppLocalization.text("recovery.unborn") }
        let summary = before == after
            ? AppLocalization.text("recovery.unchanged", write.title, name(after))
            : AppLocalization.text("recovery.changed", write.title, name(before), name(after))
        let state = AppLocalization.text(
            "connection.recovery",
            snapshot.status.branch.head ?? AppLocalization.text("branch.detachedShort"),
            snapshot.status.entries.count,
            AppLocalization.text(snapshot.indexLocked ? "state.yes" : "state.no"),
            AppLocalization.text(snapshot.merging ? "state.yes" : "state.no"),
            AppLocalization.text(snapshot.rebasing ? "state.yes" : "state.no")
        )
        return summary + "\n\n" + state + "\n\n" + remoteReferenceChanges(write, snapshot: snapshot)
    }

    /// 中断前后远端跟踪分支的变化，每个变化的分支一行；获取或推送可能已经部分完成。
    static func remoteReferenceChanges(_ write: InterruptedWrite, snapshot: RemoteRecoverySnapshot) -> String {
        let before = write.remoteReferences
        let after = snapshot.remoteReferences

        // 提交取前 8 位，引用不存在时写 “无”
        let name: (String?) -> String = { object in
            object.map { String($0.prefix(8)) } ?? AppLocalization.text("recovery.noReference")
        }

        let changes = Set(before.keys).union(after.keys)
            .filter { before[$0] != after[$0] }
            .sorted()
            .map { reference in
                let branch = String(reference.dropFirst("refs/remotes/".count))
                return branch + "  " + name(before[reference]) + " → " + name(after[reference])
            }

        guard !changes.isEmpty else {
            return AppLocalization.text("recovery.remoteUnchanged")
        }

        return AppLocalization.text("recovery.remoteChanged") + "\n" + changes.joined(separator: "\n")
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
