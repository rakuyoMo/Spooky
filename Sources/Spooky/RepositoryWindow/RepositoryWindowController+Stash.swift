import AppKit
import SpookyKit
import SwiftUI

// MARK: - Stash

extension RepositoryWindowController {
    /// 主菜单与工具栏的保存入口，储藏全部本地改动。
    @objc
    func saveStash() { session.requestSaveStash(snapshot: false) }

    /// 主菜单的快照入口，保存全部本地改动并保留工作区。
    @objc
    func createSnapshot() { session.requestSaveStash(snapshot: true) }

    /// 主菜单与工具栏的应用入口；储藏视图中预选当前选中的储藏。
    @objc
    func applyStash() {
        let selected = session.activeView == .stashes ? session.stashes.selectedStash : nil
        session.requestApplyStash(selected)
    }

    /// 储藏列表与详情分栏，宽度按储藏视图单独保存。
    func makeStashSplit() -> NSSplitViewController {
        let split = NSSplitViewController()
        split.splitView.isVertical = true
        split.splitView.dividerStyle = .thin
        Self.setAutosaveName("Spooky.Stashes", of: split)

        let list = NSHostingController(rootView: StashListView(session: session))
        list.sizingOptions = [.minSize]
        let listItem = NSSplitViewItem(contentListWithViewController: list)
        listItem.minimumThickness = 200
        listItem.holdingPriority = .init(475)
        listItem.canCollapse = false

        let detail = NSHostingController(rootView: StashDetailView(session: session))
        detail.sizingOptions = [.minSize]
        let detailItem = NSSplitViewItem(viewController: detail)
        detailItem.holdingPriority = .init(470)
        detailItem.canCollapse = false

        split.addSplitViewItem(listItem)
        split.addSplitViewItem(detailItem)
        return split
    }

    /// 工具栏的储藏分段组：应用 | 保存，空间不足时整组进入溢出菜单。
    func makeStashToolbarItem(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        let group = NSToolbarItemGroup(
            itemIdentifier: identifier,
            images: ["tray.and.arrow.up", "tray.and.arrow.down"]
                .map {
                    // 取不到符号时以空图占位，分段数与标签保持一致。
                    NSImage(systemSymbolName: $0, accessibilityDescription: nil) ?? NSImage()
                },
            selectionMode: .momentary,
            labels: ["stash.apply", "stash.save"].map { AppLocalization.text($0) },
            target: self,
            action: nil
        )
        group.controlRepresentation = .expanded

        // 每段带上自己的动作，工具栏自动校验时逐段决定可用性。
        for (segment, action) in zip(group.subitems, [#selector(applyStash), #selector(saveStash)]) {
            segment.target = self
            segment.action = action
        }

        return group
    }

    /// 储藏动作的可用性；动作不属于本组时为 nil。
    func stashAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        switch action {
        case #selector(showStashes):
            session.repository != nil

        case #selector(saveStash), #selector(createSnapshot):
            repositoryView && session.canSaveStash

        case #selector(applyStash):
            repositoryView && session.canApplyStash

        default:
            nil
        }
    }

    /// 储藏对话框以 sheet 呈现；提交时仓库已切换或不可写则保持打开。
    func presentStash(_ request: StashRequest) {
        guard let window, window.attachedSheet == nil, session.repository != nil else {
            // 无法询问时，被挡住的操作照常报告失败，不能静默丢弃
            if case .autoStash(let pending) = request { session.declineAutoStash(pending) }
            return
        }

        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed
        sheet.contentViewController = NSHostingController(
            rootView: StashDialog(
                session: session,
                request: request,
                repository: session.repository
            ) { [weak sheet] in
                if let sheet { window.endSheet(sheet) }
            }
        )
        window.beginSheet(sheet)
    }
}
