import AppKit
import SpookyKit
import SwiftUI

// MARK: - LFS

extension RepositoryWindowController {
    /// Repository › LFS › Update：不经对话框，按当前版本的 Git LFS 更新钩子。
    @objc
    func updateLFS() {
        session.updateLFS()
    }

    /// Repository › LFS › Fetch…：选远端后下载当前检出需要的 LFS 对象。
    @objc
    func fetchLFS() {
        presentLFSTransfer(.fetch)
    }

    /// Repository › LFS › Pull…：选远端后下载 LFS 对象并换出工作区里的内容。
    @objc
    func pullLFS() {
        presentLFSTransfer(.pull)
    }

    /// Repository › LFS › Push…：选远端后上传本地分支与标签用到的 LFS 对象。
    @objc
    func pushLFS() {
        presentLFSTransfer(.push)
    }

    /// Repository › LFS › Track…：输入交给 Git LFS 跟踪的规则。
    @objc
    func trackLFS() {
        presentFileRequest(.form(.lfsPattern([])))
    }

    /// LFS 动作的可用性；动作不属于本组时为 nil。
    func lfsAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        switch action {
        case #selector(updateLFS), #selector(fetchLFS), #selector(pullLFS), #selector(pushLFS), #selector(trackLFS):
            repositoryView && session.canWrite

        default:
            nil
        }
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 以 sheet 呈现 LFS 传输对话框；传输开始后才关闭。
    private func presentLFSTransfer(_ transfer: LFSTransfer) {
        guard let window, session.repository != nil, window.attachedSheet == nil, session.canWrite else {
            return
        }

        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed

        let close = { [weak sheet] in
            if let sheet { window.endSheet(sheet) }
        }

        sheet.contentViewController = NSHostingController(
            rootView: LFSTransferDialog(session: session, transfer: transfer, close: close)
        )
        window.beginSheet(sheet)
    }
}
