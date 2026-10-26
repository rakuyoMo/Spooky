import AppKit
import SpookyKit
import SwiftUI

// MARK: - Pull Requests

extension RepositoryWindowController {
    /// ⌘4 与侧边栏：主视图换成请求列表与详情，第一次显示时读取。
    @objc
    func showPullRequests() {
        guard let repository = session.repository else {
            return
        }

        guard showsManager else {
            session.showPullRequests()
            return
        }

        session.activeView = .pullRequests
        display(repository)

        if !session.pullRequests.isLoaded {
            session.reloadPullRequests()
        }
    }

    /// Repository › Create Pull Request…：在请求视图里新建，源分支预选当前分支。
    @objc
    func createPullRequest() {
        showPullRequests()
        session.requestPullRequest(.create(sourceBranch: nil))
    }

    /// 请求动作的可用性，并按选中远端的服务把菜单项换成 Pull Request 或 Merge Request 的叫法；动作不属于本组时为 nil。
    func pullRequestAvailability(of item: any NSValidatedUserInterfaceItem, repositoryView: Bool) -> Bool? {
        switch item.action {
        case #selector(showPullRequests):
            (item as? NSMenuItem)?.title = session.pullRequestText("show.menu")
            return session.repository != nil

        case #selector(createPullRequest):
            (item as? NSMenuItem)?.title = session.pullRequestText("create.menu")
            return repositoryView

        default:
            return nil
        }
    }

    /// 请求列表与详情分栏，宽度按请求视图单独保存。
    func makePullRequestsSplit() -> NSSplitViewController {
        let split = NSSplitViewController()
        split.splitView.isVertical = true
        split.splitView.dividerStyle = .thin
        Self.setAutosaveName("Spooky.PullRequests", of: split)

        let list = NSHostingController(rootView: PullRequestListView(session: session))
        list.sizingOptions = [.minSize]

        let listItem = NSSplitViewItem(contentListWithViewController: list)
        listItem.minimumThickness = 260
        listItem.holdingPriority = .init(475)
        listItem.canCollapse = false

        let detail = NSHostingController(rootView: PullRequestDetailView(session: session))
        detail.sizingOptions = [.minSize]

        let detailItem = NSSplitViewItem(viewController: detail)
        detailItem.holdingPriority = .init(470)
        detailItem.canCollapse = false

        split.addSplitViewItem(listItem)
        split.addSplitViewItem(detailItem)

        if UserDefaults.standard.object(forKey: "NSSplitView Subview Frames Spooky.PullRequests") == nil {
            split.splitView.setPosition(320, ofDividerAt: 0)
        }

        return split
    }

    /// 呈现请求的对话框；对话框在操作开始后才关闭。
    func presentPullRequestRequest(_ request: PullRequestRequest) {
        guard let window, session.repository != nil, window.attachedSheet == nil else {
            return
        }

        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed

        let close = { [weak sheet] in
            if let sheet { window.endSheet(sheet) }
        }

        let dialog =
            switch request {
            case .create(let branch):
                AnyView(PullRequestFormDialog(session: session, request: nil, preselectedBranch: branch, close: close))

            case .edit(let request):
                AnyView(PullRequestFormDialog(session: session, request: request, close: close))

            case .merge(let request):
                AnyView(MergePullRequestDialog(session: session, request: request, close: close))

            case .comment(let request):
                AnyView(PullRequestTextDialog(session: session, request: request, kind: .comment, close: close))

            case .checkout(let request):
                AnyView(PullRequestTextDialog(session: session, request: request, kind: .checkout, close: close))

            case .associate(let remote, let url):
                AnyView(AssociateRemoteDialog(session: session, remote: remote, url: url, close: close))
            }

        sheet.contentViewController = NSHostingController(rootView: dialog)
        window.beginSheet(sheet)
    }
}
