import AppKit

// MARK: - Changeset Preferences

extension SpookyApplicationController {
    /// 保存下一次读取变更集时采用的阈值，当前详情的展开范围与补丁保持不变。
    @objc
    func setAutoExpand(_ sender: NSMenuItem) {
        changesetPreferences.set(sender.tag, forKey: "historyAutoExpand")
    }
}
