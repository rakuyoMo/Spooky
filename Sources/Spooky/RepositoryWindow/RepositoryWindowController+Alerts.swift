import AppKit
import SpookyKit

// MARK: - Alerts

extension RepositoryWindowController {
    /// 把错误原文放入可滚动、可复制的附件，恢复操作在 sheet 结束后执行。
    func showFailure(_ failure: AppFailure) {
        guard let window else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = failure.title
        alert.informativeText = failure.message + "\n\n" + failure.context
        alert.addButton(withTitle: AppLocalization.text("action.close"))
        alert.addButton(withTitle: AppLocalization.text(
            failure.isOpeningFailure ? "action.chooseAnother" : "action.refresh"
        ))

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 175))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.isSelectable = true
        text.isRichText = false
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.textColor = .secondaryLabelColor
        text.textContainerInset = NSSize(width: 8, height: 8)
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.string = failure.details
        text.setAccessibilityLabel(AppLocalization.text("error.details"))
        scroll.documentView = text
        alert.accessoryView = scroll

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertSecondButtonReturn else {
                return
            }

            if failure.isOpeningFailure {
                if failure.isRemoteFailure { addRemoteRepository() }
                else { chooseRepository() }
            } else {
                refreshRepository()
            }
        }
    }

    /// 重连核对后报告中断写入的结果：HEAD 是否变化与仓库状态；写入没有被重试。
    func showRecovery(_ write: InterruptedWrite, snapshot: RemoteRecoverySnapshot?) {
        guard let window else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = AppLocalization.text("recovery.title")
        alert.informativeText = Self.recoveryMessage(write, snapshot: snapshot)
            + (session.repository.map { "\n\n" + AppLocalization.text("failure.location", $0.displayPath) } ?? "")
        alert.addButton(withTitle: AppLocalization.text("action.close"))

        // 中断时的错误 sheet 可能仍未关闭，AppKit 会在它结束后依次显示。
        alert.beginSheetModal(for: window)
    }
}
