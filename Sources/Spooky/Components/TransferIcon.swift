import AppKit

// MARK: - TransferIcon

/// 获取、拉取、推送的一套图标：同一支弧形块状箭头，获取空心、朝左下，拉取实心、朝左下，推送实心、朝右上；
/// 工具栏的 Fetch | Pull | Push 三段与 Activity 里按传输方向的记录共用。
///
/// 图片由 `scripts/make-transfer-icons.swift` 绘制，每个图标的 @1x 与 @2x 两张放在资源目录。
@MainActor
enum TransferIcon {
    /// 获取的模板图。
    private static let fetch = image(named: "FetchTemplate", label: "sync.fetch")

    /// 拉取的模板图。
    private static let pull = image(named: "PullTemplate", label: "sync.pull")

    /// 推送的模板图。
    private static let push = image(named: "PushTemplate", label: "sync.push")

    /// 一个传输方向的模板图，由 AppKit 与 SwiftUI 按外观与状态着色。
    ///
    /// - Parameter transfer: 传输方向。
    static func image(for transfer: ActivityTransfer) -> NSImage {
        switch transfer {
        case .fetch: fetch
        case .pull: pull
        case .push: push
        }
    }

    /// 从资源目录读出一张模板图，辅助功能的说明与工具栏对应段的标签相同。
    ///
    /// - Parameters:
    ///   - name: 资源名，不带倍率后缀与扩展名。
    ///   - label: 工具栏对应段标签的资源键。
    private static func image(named name: String, label: String) -> NSImage {
        let image = Bundle.module.image(forResource: name) ?? NSImage()
        image.isTemplate = true
        image.accessibilityDescription = AppLocalization.text(label)
        return image
    }
}
