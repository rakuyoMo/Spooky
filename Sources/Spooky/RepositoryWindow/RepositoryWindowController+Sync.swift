import AppKit
import SpookyKit
import SwiftUI

// MARK: - Sync Actions

extension RepositoryWindowController {
    /// 同步对话框：选远端分支，依次获取、拉取、推送。
    @objc
    func sync() { presentSyncDialog(.sync) }

    /// 变基对话框：选分支，把当前分支变基到它上面。
    @objc
    func rebase() { presentSyncDialog(.rebase) }

    /// 安全强推对话框：核对远端分支后带期望值强推。
    @objc
    func forcePushWithLease() { presentSyncDialog(.forcePush) }

    /// 推送任意版本到远端引用的对话框。
    @objc
    func pushRevision() { presentSyncDialog(.pushRevision) }

    /// 跳过对话框获取远端，选项沿用获取对话框的记忆。
    @objc
    func quickFetch() { session.quickFetch() }

    /// 跳过对话框拉取 HEAD 的跟踪分支。
    @objc
    func quickPull() { session.quickPull() }

    /// 跳过对话框把 HEAD 推到它的跟踪分支。
    @objc
    func quickPush() { session.quickPush() }

    /// 跳过对话框同步 HEAD 与它的跟踪分支。
    @objc
    func quickSync() { session.quickSync() }

    /// 跳过对话框把 HEAD 的跟踪分支合并进来。
    @objc
    func quickMerge() { session.quickMerge() }

    /// 跳过对话框把 HEAD 变基到它的跟踪分支上。
    @objc
    func quickRebase() { session.quickRebase() }

    /// 同步相关对话框以 sheet 呈现；对话框自己开始写操作，结束后关闭。
    func presentSyncDialog(_ kind: SyncDialogKind) {
        guard session.canWrite, let window, window.attachedSheet == nil else {
            return
        }

        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed
        sheet.contentViewController = NSHostingController(
            rootView: SyncDialog(session: session, kind: kind) { [weak sheet] in
                if let sheet {
                    window.endSheet(sheet)
                }
            }
        )
        window.beginSheet(sheet)
    }

    /// 同步、变基、强推、推送任意版本与各快速操作的可用性；动作不属于本组时为 nil。
    func syncAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        switch action {
        case #selector(quickFetch):
            repositoryView && session.canFetch

        case #selector(quickPull):
            repositoryView && session.canPull

        case #selector(quickPush), #selector(forcePushWithLease):
            repositoryView && session.canPush

        case #selector(sync), #selector(quickSync):
            repositoryView && session.canSync

        case #selector(quickMerge):
            repositoryView && session.canMerge

        case #selector(rebase), #selector(quickRebase):
            repositoryView && session.canRebase

        case #selector(pushRevision):
            repositoryView && session.canPushRevision

        default:
            nil
        }
    }
}

// MARK: - Sync Toolbar

extension RepositoryWindowController {
    /// 工具栏按钮的常态与快速动作，以及各自的提示文字。
    private static let quickActions: [
        (action: Selector, quick: Selector, tip: String, quickTip: String)
    ] = [
        (#selector(fetch), #selector(quickFetch), "sync.fetch.tip", "sync.quickFetch.tip"),
        (#selector(pull), #selector(quickPull), "sync.pull.tip", "sync.quickPull.tip"),
        (#selector(push), #selector(quickPush), "sync.push.tip", "sync.quickPush.tip"),
        (#selector(sync), #selector(quickSync), "sync.sync.tip", "sync.quickSync.tip"),
        (#selector(merge), #selector(quickMerge), "sync.merge.tip", "sync.quickMerge.tip"),
        (#selector(rebase), #selector(quickRebase), "sync.rebaseHead.tip", "sync.quickRebase.tip"),
    ]

    /// 工具栏的同步项：Fetch | Pull | Push 分组、Sync 按钮、Merge | Rebase 分组；其它标识返回 nil。
    func makeSyncToolbarItem(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        switch identifier.rawValue {
        case "sync":
            return makeSegmentedGroup(
                identifier,
                segments: [
                    ("sync.fetch", "arrow.down.circle", #selector(fetch)),
                    ("sync.pull", "arrow.down.to.line", #selector(pull)),
                    ("sync.push", "arrow.up.circle", #selector(push)),
                ]
            )

        case "merge":
            return makeSegmentedGroup(
                identifier,
                segments: [
                    ("sync.merge", "arrow.triangle.merge", #selector(merge)),
                    ("sync.rebaseHead", "arrow.triangle.branch", #selector(rebase)),
                ]
            )

        case "synchronize":
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.label = AppLocalization.text("sync.sync")
            item.image = NSImage(
                systemSymbolName: "arrow.triangle.2.circlepath",
                accessibilityDescription: item.label
            )
            item.target = self
            item.action = #selector(sync)
            updateQuickAction(of: item, option: NSEvent.modifierFlags.contains(.option))
            return item

        default:
            return nil
        }
    }

    /// 按住 ⌥ 时把同步相关按钮换成快速操作与对应提示；松开或窗口不再是主窗口时复原。
    func updateQuickToolbarItems(option: Bool) {
        for item in window?.toolbar?.items ?? [] {
            let items = (item as? NSToolbarItemGroup)?.subitems ?? [item]

            for subitem in items {
                updateQuickAction(of: subitem, option: option)
            }
        }

        window?.toolbar?.validateVisibleItems()
    }

    /// 一个分段按钮组，每段带自己的动作与提示，点按是瞬时的。
    private func makeSegmentedGroup(
        _ identifier: NSToolbarItem.Identifier,
        segments: [(label: String, symbol: String, action: Selector)]
    ) -> NSToolbarItemGroup {
        let group = NSToolbarItemGroup(
            itemIdentifier: identifier,
            images: segments.map {
                // 取不到符号时以空图占位，分段数与标签保持一致。
                NSImage(systemSymbolName: $0.symbol, accessibilityDescription: nil) ?? NSImage()
            },
            selectionMode: .momentary,
            labels: segments.map { AppLocalization.text($0.label) },
            target: self,
            action: nil
        )

        // 始终以分段控件显示，空间不足时整组进入工具栏的溢出菜单。
        group.controlRepresentation = .expanded

        // 每段带上自己的动作：点击直接分派到对应动作，工具栏自动校验时也逐段决定可用性。
        for (segment, action) in zip(group.subitems, segments.map(\.action)) {
            segment.target = self
            segment.action = action
            updateQuickAction(of: segment, option: NSEvent.modifierFlags.contains(.option))
        }

        return group
    }

    /// 按 ⌥ 的状态设置一个按钮的动作与提示，按钮由它当前的常态或快速动作认出；服务器仓库的提示带主机前缀。
    private func updateQuickAction(of item: NSToolbarItem, option: Bool) {
        let actions = Self.quickActions.first { entry in
            [entry.action, entry.quick].contains(item.action)
        }

        guard let actions else {
            return
        }

        item.action = option ? actions.quick : actions.action

        let tip = AppLocalization.text(option ? actions.quickTip : actions.tip)
        item.toolTip = session.repository?.host.map { $0 + ": " + tip } ?? tip
    }
}
