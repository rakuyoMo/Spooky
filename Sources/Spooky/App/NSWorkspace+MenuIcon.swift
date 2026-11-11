import AppKit

// MARK: - NSWorkspace + MenuIcon

extension NSWorkspace {
    /// 文件、目录或程序在菜单与弹出菜单里的 16 × 16 pt 图标。
    ///
    /// 系统图标默认是 32 × 32 pt，交给菜单项前先改成菜单的尺寸，按原比例缩小，不靠视图拉伸。
    /// 每次调用都向系统取一份新的图标，改尺寸不影响其它地方取到的图标。
    ///
    /// - Parameter path: 文件、目录或程序的路径。
    func menuIcon(forFile path: String) -> NSImage {
        let icon = icon(forFile: path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}
