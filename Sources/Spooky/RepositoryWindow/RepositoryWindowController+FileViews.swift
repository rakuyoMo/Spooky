import AppKit
import SpookyKit
import SwiftUI

// MARK: - File Views

extension RepositoryWindowController {
    /// 搜索框范围菜单的顺序，菜单项的 tag 是这里的序号。
    private static let fileHistoryScopes: [FileHistoryFilter.Scope] = [.message, .hash, .author, .committer]

    /// 范围菜单项的标题。
    private static func title(of scope: FileHistoryFilter.Scope) -> String {
        switch scope {
        case .message: AppLocalization.text("fileHistory.scope.message")
        case .hash: AppLocalization.text("fileHistory.scope.hash")
        case .author: AppLocalization.text("fileHistory.scope.author")
        case .committer: AppLocalization.text("fileHistory.scope.committer")
        }
    }

    /// 搜索框在各范围下的占位文字。
    private static func placeholder(of scope: FileHistoryFilter.Scope) -> String {
        switch scope {
        case .message: AppLocalization.text("fileHistory.search.message")
        case .hash: AppLocalization.text("fileHistory.search.hash")
        case .author: AppLocalization.text("fileHistory.search.author")
        case .committer: AppLocalization.text("fileHistory.search.committer")
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

        // 列表不延伸到工具栏下面，免得列表的底色与分隔线穿过工具栏上的项
        timelineItem.allowsFullHeightLayout = false

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

    /// 文件历史里的搜索框按说明、提交哈希、作者或提交人筛选，范围在搜索框左侧以 File History 为标题的菜单里切换；
    /// 除提交哈希外，输入时分 Authors、Messages、Committers 三组补全。
    func configureFileHistorySearch(_ field: NSSearchField) {
        let scope = session.fileHistory.scope
        let menu = NSMenu()
        let state = session.fileHistory
        let suggestions = session.history.suggestions

        // 作者与提交人来自会话在后台维护的贡献者，说明来自已读出的时间线
        contributorCompletion.attach(
            to: field,
            suggestions: { [weak state] query in
                guard let state, state.scope != .hash, let runner = state.runner, let head = state.head else {
                    return []
                }

                let contributors = await suggestions.contributors(runner: runner, head: head)

                return ContributorSuggestion.matches(query, in: contributors.authors, group: .authors)
                    + ContributorSuggestion.messages(query, in: state.commits.map(\.subject))
                    + ContributorSuggestion.matches(query, in: contributors.committers, group: .committers)
            },
            apply: { [weak self] in self?.acceptFileHistorySuggestion($0) }
        )

        menu.addItem(.sectionHeader(title: AppLocalization.text("fileHistory.title")))

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

    /// 接受补全：按建议所属的分组换到对应的范围，再与键入一样写入会话，由文件历史按新内容重读。
    private func acceptFileHistorySuggestion(_ suggestion: ContributorSuggestion) {
        let scope: FileHistoryFilter.Scope? =
            switch suggestion.group {
            case .authors: .author
            case .messages: .message
            case .committers: .committer
            case nil: nil
            }

        if let scope, scope != session.fileHistory.scope {
            session.fileHistory.scope = scope
            refreshFileHistorySearchField()
        }

        session.searchText = suggestion.text
    }

    /// 切换搜索范围后按新范围重读，并更新菜单的勾选与占位文字。
    @objc
    private func selectFileHistorySearchScope(_ sender: NSMenuItem) {
        guard Self.fileHistoryScopes.indices.contains(sender.tag) else {
            return
        }

        session.fileHistory.scope = Self.fileHistoryScopes[sender.tag]
        refreshFileHistorySearchField()
    }

    /// 范围变化后重新配置工具栏的搜索框：菜单的勾选与占位文字随之更新。
    private func refreshFileHistorySearchField() {
        let item = window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "search" }

        if let field = (item as? NSSearchToolbarItem)?.searchField {
            configureFileHistorySearch(field)
        }
    }
}
