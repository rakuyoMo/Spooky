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

    /// 储藏列表与详情分栏，尺寸按储藏视图单独保存。
    func makeStashSplit() -> NSSplitViewController {
        let split = makeInnerSplit(name: "Spooky.Stashes")

        let list = NSHostingController(rootView: StashListView(session: session))
        list.sizingOptions = [.minSize]
        let listItem = NSSplitViewItem(contentListWithViewController: list)
        listItem.minimumThickness = listMinimumThickness(200)
        listItem.holdingPriority = .init(475)
        listItem.canCollapse = false

        // 列表不延伸到工具栏下面，免得列表的底色与分隔线穿过工具栏上的项
        listItem.allowsFullHeightLayout = false

        let detail = NSHostingController(rootView: StashDetailView(session: session))
        detail.sizingOptions = [.minSize]
        let detailItem = NSSplitViewItem(viewController: detail)
        detailItem.holdingPriority = .init(470)
        detailItem.canCollapse = false

        split.addSplitViewItem(listItem)
        split.addSplitViewItem(detailItem)
        return split
    }

    /// 工具栏的储藏分段组：Apply | Save，空间不足时整组进入溢出菜单；自定义面板里写 Apply Stash、Save Stash。
    func makeStashToolbarItem(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        let segments: [(label: String, palette: String, symbol: String, action: Selector)] = [
            ("toolbar.applyStash", "stash.apply", "tray.and.arrow.down", #selector(applyStash)),
            ("toolbar.saveStash", "stash.save", "tray.and.arrow.up", #selector(saveStash)),
        ]

        let group = NSToolbarItemGroup(
            itemIdentifier: identifier,
            images: segments.map {
                // 取不到符号时以空图占位，分段数与标签保持一致；辅助功能读段名
                NSImage(systemSymbolName: $0.symbol, accessibilityDescription: AppLocalization.text($0.label))
                    ?? NSImage()
            },
            selectionMode: .momentary,
            labels: segments.map { AppLocalization.text($0.label) },
            target: self,
            action: nil
        )
        group.controlRepresentation = .expanded

        // 每段带上自己的动作、面板名与提示，工具栏自动校验时逐段决定可用性。
        for (segment, entry) in zip(group.subitems, segments) {
            segment.target = self
            segment.action = entry.action
            segment.paletteLabel = AppLocalization.text(entry.palette)
            updateTip(of: segment)
        }

        return group
    }

    /// 储藏动作的可用性；动作不属于本组时为 nil。
    func stashAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        switch action {
        case #selector(showStashes):
            repositoryView

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

        presentDialog { close in
            StashDialog(
                session: session,
                request: request,
                repository: session.repository,
                close: close
            )
        }
    }
}
