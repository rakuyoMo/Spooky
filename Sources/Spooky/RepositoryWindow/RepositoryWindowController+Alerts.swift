import AppKit
import SpookyKit
import SwiftUI

// MARK: - Alerts

extension RepositoryWindowController {
    /// 以 Git 错误框挂成 sheet；窗口已有 sheet 时叠在它上面，如执行期间保持打开的表单，关掉后回到那个 sheet。
    /// 拉大后的尺寸记在 `GitErrorDialog` 名下。
    func showFailure(_ failure: AppFailure) {
        guard let window else {
            return
        }

        DialogWindow.present(on: window.attachedSheet ?? window, autosaveName: "GitErrorDialog") { [weak self] close in
            GitErrorDialog(
                failure: failure,
                close: close,
                chooseAnother: failure.isOpeningFailure ? { self?.chooseAnotherRepository(after: failure) } : nil
            )
        }
    }

    /// 读取仓库状态失败：仓库已不在原处时整个窗口换成丢失页，与打开时就找不到的是同一页；
    /// 显示仓库列表时后台会话的失败不弹框，其余弹出 Git 错误框。
    ///
    /// - Parameters:
    ///   - error: 读取抛出的错误，用来认出仓库是否已不在原处。
    ///   - failure: 错误的呈现。
    func presentReadFailure(_ error: any Error, _ failure: AppFailure) {
        guard !showsManager, let location = session.repository else {
            return
        }

        // 换成丢失页时会话随之关闭，窗口再次成为 key 窗口也不会再读取这个仓库
        guard !RepositoryManagerController.isMissing(location, error: error) else {
            showMissingRepository(location, reason: .notFound)
            return
        }

        showFailure(failure)
    }

    /// 以确认版对话框挂成 sheet 请用户确认；窗口已有 sheet 时不叠加。
    func showConfirmation(_ request: ConfirmationRequest) {
        presentDialog { close in
            ConfirmationDialog(request: request, close: close)
        }
    }

    /// 进行中的操作没有任何改动时以系统提示框确认是否保留空提交；窗口已有 sheet 时不叠加。
    func showEmptyCommitPrompt(_ request: EmptyCommitRequest) {
        guard let window, window.attachedSheet == nil else {
            return
        }

        let alert = Self.emptyCommitAlert(request)

        alert.beginSheetModal(for: window) { response in
            Self.finishEmptyCommit(
                request,
                response: response,
                suppressed: alert.suppressionButton?.state == .on
            )
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
    /// 空提交的确认：系统提示框，按钮依次是保留空提交、中止当前操作（序列里是跳过这一步）与 Cancel，带不再提示的勾选框。
    static func emptyCommitAlert(_ request: EmptyCommitRequest) -> NSAlert {
        let keys = request.isSequence
            ? (message: "commit.empty.sequenceMessage", alternate: "commit.empty.skip")
            : (message: "commit.empty.message", alternate: "commit.empty.abort")

        let alert = NSAlert()
        alert.messageText = AppLocalization.text("commit.empty.title")
        alert.informativeText = AppLocalization.text(keys.message)

        alert.addButton(withTitle: AppLocalization.text("commit.empty.use"))
        alert.addButton(withTitle: AppLocalization.text(keys.alternate))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))

        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = AppLocalization.text("commit.empty.doNotShowAgain")

        return alert
    }

    /// 按空提交提示框的结果执行：勾上不再提示时，无论选哪个按钮（包括 Cancel）都关掉这项警告；Cancel 不执行 Git。
    ///
    /// - Parameters:
    ///   - request: 会话发来的确认请求。
    ///   - response: 提示框的结果，按钮依 `emptyCommitAlert(_:)` 的顺序。
    ///   - suppressed: 是否勾上了不再提示。
    static func finishEmptyCommit(
        _ request: EmptyCommitRequest,
        response: NSApplication.ModalResponse,
        suppressed: Bool
    ) {
        if suppressed {
            UserDefaults.standard.set(false, forKey: WorkingCopyPreferences.warnsEmptyCommit)
        }

        switch response {
        case .alertFirstButtonReturn:
            request.commit()

        case .alertSecondButtonReturn:
            request.alternate()

        default:
            break
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
