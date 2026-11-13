import AppKit
import SpookyKit

// MARK: - Stash Menu

extension WorkingCopyFileList.Coordinator {
    /// 储藏菜单项对应的动作与文件。
    private struct StashChoice {
        /// 是否保留工作区。
        let snapshot: Bool

        /// 是否跳过对话框。
        let quick: Bool

        /// 右键菜单作用的条目。
        let entries: [StatusEntry]
    }

    /// 丢弃之后的储藏项：储藏与快照所选文件，按住 ⌥ 时换成跳过对话框的快速版本；
    /// 没有作用对象时以通用标题列出且不可用。
    func addStashItems(to menu: NSMenu, entries: [StatusEntry]) {
        let enabled = session.canStash(entries)

        // 每组依次是单个对象、多个对象与没有作用对象时的资源键，常规项在前、快速项在后
        let groups = [
            (
                false,
                ["stash.stashFile", "stash.stashItems", "stash.saveMenu"],
                ["stash.quickStashFile", "stash.quickStashItems", "stash.quickSaveMenu"]
            ),
            (
                true,
                ["stash.snapshotFile", "stash.snapshotItems", "stash.snapshotMenu"],
                ["stash.quickSnapshotFile", "stash.quickSnapshotItems", "stash.quickSnapshotMenu"]
            ),
        ]

        for (snapshot, regularKeys, quickKeys) in groups {
            // 单个对象显示名称，多个对象显示数量；树形里一个目录算一项
            let title = countedTitle(single: regularKeys[0], multiple: regularKeys[1], generic: regularKeys[2])
            let quickTitle = countedTitle(single: quickKeys[0], multiple: quickKeys[1], generic: quickKeys[2])

            menu.addItem(
                stashItem(title, choice: StashChoice(snapshot: snapshot, quick: false, entries: entries), enabled: enabled)
            )

            // ⌥ 变体紧跟在常规项之后，按住 ⌥ 时替换它
            let quick = stashItem(
                quickTitle,
                choice: StashChoice(snapshot: snapshot, quick: true, entries: entries),
                enabled: enabled
            )
            quick.isAlternate = true
            quick.keyEquivalentModifierMask = .option
            menu.addItem(quick)
        }
    }

    /// 交给会话的储藏入口；快速版本直接执行，其余打开部分储藏的对话框。
    @objc
    private func stashMenu(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? StashChoice else { return }
        session.requestSaveStash(snapshot: choice.snapshot, entries: choice.entries, quick: choice.quick)
    }

    /// 菜单可用性由会话决定，不依赖响应链的隐式校验。
    private func stashItem(_ title: String, choice: StashChoice, enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(stashMenu(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        item.representedObject = choice
        return item
    }
}
