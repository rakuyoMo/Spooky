import AppKit
import SpookyKit
import SwiftUI

// MARK: - File Views

extension RepositoryWindowController {
    /// 搜索框范围菜单的顺序，菜单项的 tag 是这里的序号。
    private static let fileHistoryScopes: [FileHistoryFilter.Scope] = [.author, .committer, .revision]

    /// 范围菜单项的标题。
    private static func title(of scope: FileHistoryFilter.Scope) -> String {
        switch scope {
        case .author: AppLocalization.text("fileHistory.scope.author")
        case .committer: AppLocalization.text("fileHistory.scope.committer")
        case .revision: AppLocalization.text("fileHistory.scope.revision")
        }
    }

    /// 搜索框在各范围下的占位文字。
    private static func placeholder(of scope: FileHistoryFilter.Scope) -> String {
        switch scope {
        case .author: AppLocalization.text("fileHistory.search.author")
        case .committer: AppLocalization.text("fileHistory.search.committer")
        case .revision: AppLocalization.text("fileHistory.search.revision")
        }
    }

    /// 文件历史的时间线与详情分栏；时间线最小 100 pt，宽度按文件历史单独保存。
    func makeFileHistorySplit() -> NSSplitViewController {
        let split = NSSplitViewController()
        split.splitView.isVertical = true
        split.splitView.dividerStyle = .thin
        Self.setAutosaveName("Spooky.FileHistory", of: split)

        // 窗口与分栏决定内容尺寸，HostingController 只提供最小内容约束
        let timeline = NSHostingController(
            rootView: FileHistoryTimelineView(session: session, state: session.fileHistory)
        )
        timeline.sizingOptions = [.minSize]

        let timelineItem = NSSplitViewItem(contentListWithViewController: timeline)
        timelineItem.minimumThickness = 100
        timelineItem.holdingPriority = .init(475)
        timelineItem.canCollapse = false

        let detail = NSHostingController(
            rootView: FileHistoryDetailView(session: session, state: session.fileHistory)
        )
        detail.sizingOptions = [.minSize]

        let detailItem = NSSplitViewItem(viewController: detail)
        detailItem.holdingPriority = .init(470)
        detailItem.canCollapse = false

        split.addSplitViewItem(timelineItem)
        split.addSplitViewItem(detailItem)
        return split
    }

    /// 文件原文与 Blame 不分栏，直接占满详情区。
    func makeFileContentView() -> NSViewController {
        let controller = NSHostingController(
            rootView: FileContentView(session: session, state: session.fileContent)
        )
        controller.sizingOptions = [.minSize]
        return controller
    }

    /// 文件历史里的搜索框按作者、提交人或版本筛选，范围在搜索框左侧的菜单里切换；按作者或提交人筛选时补全姓名。
    func configureFileHistorySearch(_ field: NSSearchField) {
        let scope = session.fileHistory.scope
        let menu = NSMenu()

        // 接受补全后与键入一样写入会话，由文件历史按新内容重读
        contributorCompletion.attach(to: field, state: session.fileHistory) { [weak self] in
            self?.session.searchText = $0
        }

        for (index, candidate) in Self.fileHistoryScopes.enumerated() {
            let item = NSMenuItem(
                title: Self.title(of: candidate),
                action: #selector(selectFileHistorySearchScope(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            item.state = candidate == scope ? .on : .off
            menu.addItem(item)
        }

        field.searchMenuTemplate = menu
        field.placeholderString = Self.placeholder(of: scope)
    }

    /// 切换搜索范围后按新范围重读，并更新菜单的勾选与占位文字。
    @objc
    private func selectFileHistorySearchScope(_ sender: NSMenuItem) {
        guard Self.fileHistoryScopes.indices.contains(sender.tag) else {
            return
        }

        session.fileHistory.scope = Self.fileHistoryScopes[sender.tag]

        let item = window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "search" }

        if let field = (item as? NSSearchToolbarItem)?.searchField {
            configureFileHistorySearch(field)
        }
    }
}
