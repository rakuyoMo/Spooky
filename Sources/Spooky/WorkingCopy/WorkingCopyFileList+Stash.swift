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

    /// 丢弃之后的储藏项：储藏与快照所选文件，按住 ⌥ 时换成跳过对话框的快速版本；没有作用对象时不列出。
    func addStashItems(to menu: NSMenu, entries: [StatusEntry]) {
        guard !menuTargets.isEmpty else { return }

        let enabled = session.canStash(entries)

        // 单个对象显示名称，多个对象显示数量；树形里一个目录算一项
        let name = menuTargets.count == 1 ? menuTargets.first?.name : nil
        let count = menuTargets.count

        // 资源键依次是单个文件、多个文件、快速单个文件与快速多个文件的文案
        let groups = [
            (false, ["stash.stashFile", "stash.stashItems", "stash.quickStashFile", "stash.quickStashItems"]),
            (true, ["stash.snapshotFile", "stash.snapshotItems", "stash.quickSnapshotFile", "stash.quickSnapshotItems"]),
        ]

        for (snapshot, keys) in groups {
            let title = name.map { AppLocalization.text(keys[0], $0) } ?? AppLocalization.text(keys[1], count)
            let quickTitle = name.map { AppLocalization.text(keys[2], $0) } ?? AppLocalization.text(keys[3], count)

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
