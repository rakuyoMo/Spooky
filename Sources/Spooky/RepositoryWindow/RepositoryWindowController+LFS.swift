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

    /// LFS 动作的可用性：仓库自己启用了 Git LFS 才可用，判断由打开子菜单时的读取给出；动作不属于本组时为 nil。
    func lfsAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        switch action {
        case #selector(updateLFS), #selector(fetchLFS), #selector(pullLFS), #selector(pushLFS), #selector(trackLFS):
            repositoryView
                && session.canWrite
                && session.repository != nil
                && lfsEnabledRepository == session.repository

        default:
            nil
        }
    }

    /// 读一次当前仓库是否启用了 Git LFS，记下结果供 LFS 各项的可用性使用。
    func readLFSAvailability() async {
        let repository = session.repository
        let enabled = await session.isLFSEnabled()

        lfsEnabledRepository = enabled ? repository : nil
    }
}

// MARK: - LFSMenuReader

/// Repository › LFS 子菜单的代理：每次打开时为前台的仓库窗口读一次 Git LFS 是否启用，读完后重新校验各项。
///
/// 是否启用要读仓库配置与钩子，不放进刷新的轮询里。
@MainActor
final class LFSMenuReader: NSObject, NSMenuDelegate {
    /// 主菜单使用的实例。
    static let shared = LFSMenuReader()

    /// 打开时找到会接收 LFS 动作的仓库窗口，读完后刷新菜单项的可用状态。
    func menuWillOpen(_ menu: NSMenu) {
        let target = NSApp.target(forAction: #selector(RepositoryWindowController.updateLFS), to: nil, from: nil)
        guard let controller = target as? RepositoryWindowController else { return }

        Task {
            await controller.readLFSAvailability()
            menu.update()
        }
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 以 sheet 呈现 LFS 传输对话框；传输开始后才关闭。
    private func presentLFSTransfer(_ transfer: LFSTransfer) {
        guard session.repository != nil, session.canWrite else {
            return
        }

        presentDialog { close in
            LFSTransferDialog(session: session, transfer: transfer, close: close)
        }
    }
}
