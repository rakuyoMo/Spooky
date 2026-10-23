import AppKit
import QuickLookUI
import SpookyKit

// MARK: - WorkingCopyQuickLook

/// 工作区列表的 Quick Look 面板数据源：面板只拿到本机路径，服务器文件先取到会话缓存。
@MainActor
final class WorkingCopyQuickLook: NSObject {
    /// 当前会话，负责取得本机副本。
    private let session: RepositorySession

    /// 面板正在预览的本机文件。
    private var urls: [URL] = []

    /// 面板是否由本列表控制。
    private var controlling = false

    /// 取得本机副本的任务，选区变化时取消旧任务。
    private var task: Task<Void, Never>?

    /// 面板是否开着。
    var isVisible: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
    }

    /// 创建数据源，不立即打开面板。
    init(session: RepositorySession) {
        self.session = session
    }

    /// 面板开着时关闭，否则预览给定的文件。
    func toggle(_ entries: [StatusEntry]) {
        guard !isVisible else {
            QLPreviewPanel.shared().orderOut(nil)
            return
        }

        load(entries)
        QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
    }

    /// 列表选区变化时，面板开着就改为预览新的所选文件。
    func selectionChanged() {
        guard controlling, isVisible else { return }

        load(session.selectedEntries)
    }

    /// 面板开始由本列表控制。
    func begin(_ panel: QLPreviewPanel?) {
        controlling = true
        panel?.dataSource = self
        panel?.reloadData()
    }

    /// 面板不再由本列表控制，停止取得副本。
    func end(_: QLPreviewPanel?) {
        controlling = false
        task?.cancel()
        task = nil
        urls = []
    }

    /// 取得所选文件的本机路径后刷新面板。
    private func load(_ entries: [StatusEntry]) {
        task?.cancel()
        urls = []

        task = Task { [weak self] in
            guard let self else { return }

            let urls = await session.localFiles(entries)
            guard !Task.isCancelled else { return }

            self.urls = urls

            if controlling {
                QLPreviewPanel.shared().reloadData()
            }
        }
    }
}

// MARK: - QLPreviewPanelDataSource

extension WorkingCopyQuickLook: @preconcurrency QLPreviewPanelDataSource {
    /// 预览项数量。
    func numberOfPreviewItems(in _: QLPreviewPanel?) -> Int {
        urls.count
    }

    /// 第几个预览项的本机文件。
    func previewPanel(_: QLPreviewPanel?, previewItemAt index: Int) -> (any QLPreviewItem)? {
        // URL 结构体不符合 QLPreviewItem，交给面板的是桥接后的 NSURL
        // swiftlint:disable:next legacy_objc_type
        urls.indices.contains(index) ? urls[index] as NSURL : nil
    }
}
