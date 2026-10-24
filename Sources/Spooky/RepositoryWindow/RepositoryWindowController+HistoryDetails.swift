import AppKit
import SpookyKit
import SwiftUI

// MARK: - History Details

extension RepositoryWindowController {
    /// Repository › Export Revision…：在历史里选中一个提交时预选它，否则预选 HEAD。
    @objc
    func exportRevision() {
        let commit = session.activeView == .history ? session.history.selectedCommit?.id : nil
        presentRevisionDialog(.export(revision: commit.map { String($0.prefix(8)) }, paths: [], archive: false))
    }

    /// Repository › Compare Revisions…：在历史里选中一个提交时预填为第一个版本。
    @objc
    func compareRevisions() {
        let commit = session.activeView == .history ? session.history.selectedCommit?.shortID : nil
        presentRevisionDialog(.compare(base: commit))
    }

    /// View › History › Verify Signatures：切换列表行的签名按钮，与列表头的视图选项共用偏好。
    @objc
    func toggleVerifySignatures() {
        let key = CommitSignatureStore.verifiesKey
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
    }

    /// 导出、保存补丁与比较版本的对话框以 sheet 呈现。
    func presentRevisionDialog(_ request: RevisionRequest) {
        guard let window, window.attachedSheet == nil, session.repository != nil else {
            return
        }

        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed
        sheet.contentViewController = NSHostingController(
            rootView: RevisionDialog(
                session: session,
                request: request,
                repository: session.repository
            ) { [weak sheet] in
                if let sheet { window.endSheet(sheet) }
            }
        )

        window.beginSheet(sheet)
    }

    /// 导出、比较与签名校验动作的可用性；动作不属于本组时为 nil。
    func historyDetailsAvailability(of item: any NSValidatedUserInterfaceItem, repositoryView: Bool) -> Bool? {
        switch item.action {
        case #selector(exportRevision), #selector(compareRevisions):
            return repositoryView && session.status?.branch.oid != nil

        case #selector(toggleVerifySignatures):
            let verifies = UserDefaults.standard.bool(forKey: CommitSignatureStore.verifiesKey)
            (item as? NSMenuItem)?.state = verifies ? .on : .off
            return !showsManager && session.activeView == .history

        default:
            return nil
        }
    }
}
