import AppKit
import SwiftUI
import Testing

@testable import Spooky

/// 侧边栏分支行在窄侧边栏里的排版。
@MainActor
struct SidebarBranchRowTests {
    /// 窄侧边栏里名称是辨认分支的唯一依据，宽度不够时先让陈旧时长让出宽度。
    @Test("宽度不够时陈旧时长先让出，名称保持完整", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func staleDurationYieldsToName() async {
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
    }

    /// 在给定宽度下排出一行，读出名称与陈旧时长两个元素的位置；陈旧时长整段让出时为零。
    ///
    /// - Parameters:
    ///   - width: 行的宽度。
    ///   - name: 分支名。
    ///   - staleLabel: 陈旧时长元素的辅助功能名称。
    ///   - status: 行的注记。
    /// - Returns: 名称与陈旧时长的位置与大小。
    private func frames(
        width: CGFloat,
        name: String,
        staleLabel: String,
        status: SidebarBranchStatus
    ) async -> (name: CGRect, stale: CGRect) {
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

        return (nameFrame, staleFrame)
    }
}
