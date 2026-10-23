import AppKit
import SpookyKit

// MARK: - Diff

extension RepositoryWindowController {
    /// View › Diff Context Lines：写入全局偏好，各窗口的 Diff 随偏好重新读取。
    @objc
    func setDiffContextLines(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: DiffPreferences.contextLinesKey)
    }

    /// Diff 相关菜单项的可用性；不属于本组时返回空，交给其它分组判断。
    func diffAvailability(of item: any NSValidatedUserInterfaceItem) -> Bool? {
        switch item.action {
        case #selector(setDiffContextLines(_:)):
            if let item = item as? NSMenuItem {
                item.state = item.tag == DiffPreferences.options().contextLines ? .on : .off
            }

            return !showsManager && session.repository != nil

        default:
            return nil
        }
    }
}
