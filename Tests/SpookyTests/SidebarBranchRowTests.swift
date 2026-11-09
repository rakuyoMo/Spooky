import AppKit
import SwiftUI
import Testing

@testable import Spooky

/// 侧边栏分支行的排版与辅助功能。
@MainActor
struct SidebarBranchRowTests {
    /// 窄侧边栏里名称是辨认分支的唯一依据，宽度不够时先让陈旧时长让出宽度；行首图标的系统符号名与分支无关，不能让 VoiceOver 读出。
    @Test("宽度不够时陈旧时长先让出、名称保持完整，行首图标不朗读", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func staleDurationYieldsAndIconIsHidden() async {
        let name = "pinned-old"
        let staleLabel = AppLocalization.text("branch.staleFor", "2 years")

        var status = SidebarBranchStatus(condition: nil, staleMonths: nil)
        status.staleDuration = "2 years"

        let wide = await frames(width: 480, name: name, staleLabel: staleLabel, status: status)
        let narrow = await frames(width: 110, name: name, staleLabel: staleLabel, status: status)

        // 窄宽度下陈旧时长让出宽度
        #expect(wide.stale.width > narrow.stale.width)

        // 名称宽度与宽行相同，陈旧时长不越出行
        #expect(abs(narrow.name.width - wide.name.width) < 1)
        #expect(narrow.stale.maxX <= 110)

        // 这一行没有跟踪错误与默认分支标记，图片元素只可能来自行首图标
        #expect(wide.images.isEmpty)
    }

    /// 在给定宽度下排出一行，读出名称与陈旧时长两个元素的位置，以及全部图片元素的名称；陈旧时长整段让出时为零。
    ///
    /// - Parameters:
    ///   - width: 行的宽度。
    ///   - name: 分支名。
    ///   - staleLabel: 陈旧时长元素的辅助功能名称。
    ///   - status: 行的注记。
    /// - Returns: 名称与陈旧时长的位置与大小，以及图片元素的名称。
    private func frames(
        width: CGFloat,
        name: String,
        staleLabel: String,
        status: SidebarBranchStatus
    ) async -> (name: CGRect, stale: CGRect, images: [String]) {
        let elements = await AccessibilityProbe.elements(
            width: width,
            until: { elements in elements.contains { $0.value == name } }
        ) {
            SidebarBranchRow(name: name, symbol: "arrow.triangle.branch", status: status, help: "")
        }

        let nameFrame = elements.first { $0.value == name }?.frame ?? .zero

        // 整段让出后元素没有大小，读出的是空矩形，与读不到一样按零计
        let staleFrame = elements
            .first { $0.name == staleLabel }
            .map(\.frame)
            .flatMap { $0.isNull ? nil : $0 }
            ?? .zero

        let images = elements
            .filter { $0.role == "AXImage" }
            .map(\.name)

        return (nameFrame, staleFrame, images)
    }
}
