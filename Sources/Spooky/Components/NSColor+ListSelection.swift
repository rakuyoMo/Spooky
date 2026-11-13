import AppKit

// MARK: - NSColor

extension NSColor {
    /// 列表选中底的颜色，随键盘焦点与窗口状态变化；历史列表的行与提交详情的变更文件行共用。
    ///
    /// - Parameters:
    ///   - emphasized: 列表有键盘焦点。
    ///   - key: 窗口是 key window。
    ///   - background: 列表的底色，窗口不是 key window 时与未强调的选中色各取一半。
    /// - Returns: 窗口是 key 时，列表有焦点是强调色、没有焦点是未强调的选中色；窗口不是 key 时不看焦点，一律是混合色。
    static func listSelection(emphasized: Bool, key: Bool, background: NSColor) -> NSColor {
        let unemphasized = NSColor.unemphasizedSelectedContentBackgroundColor

        if key {
            return emphasized ? .controlAccentColor : unemphasized
        }

        // 混合的两种颜色都随外观变化，按画的时候的外观各自取色再混合
        return NSColor(name: nil) { appearance in
            var blended = unemphasized

            appearance.performAsCurrentDrawingAppearance {
                blended = unemphasized.blended(withFraction: 0.5, of: background) ?? unemphasized
            }

            return blended
        }
    }
}
