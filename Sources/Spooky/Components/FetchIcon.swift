import AppKit

// MARK: - FetchIcon

/// 获取的图标：朝左下的空心弧形箭头，与克隆的 `arrow.down.circle` 区分开；工具栏的 Fetch 段与 Activity 里获取的记录共用。
///
/// 图片由 `scripts/make-fetch-icon.swift` 绘制，@1x 与 @2x 两张放在资源目录。
@MainActor
enum FetchIcon {
    /// 模板图，由 AppKit 与 SwiftUI 按外观与状态着色；辅助功能的说明与 Fetch 段的标签相同。
    static let image: NSImage = {
        let image = Bundle.module.image(forResource: "FetchTemplate") ?? NSImage()
        image.isTemplate = true
        image.accessibilityDescription = AppLocalization.text("sync.fetch")
        return image
    }()
}
