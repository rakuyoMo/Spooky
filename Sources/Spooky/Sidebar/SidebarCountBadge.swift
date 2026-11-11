import SwiftUI

// MARK: - SidebarCountBadge

/// 侧边栏行尾的计数：平时是深色胶囊；所在行选中且窗口活跃时去掉底色，数字为白色。
struct SidebarCountBadge: View {
    /// 显示的个数。
    let count: Int

    /// 所在行选中且窗口活跃时为 `.increased`。
    @Environment(\.backgroundProminence)
    private var prominence

    /// 11 pt 的数字，左右 6、上下 2 pt 的边距。
    var body: some View {
        let isProminent = prominence == .increased

        Text(count.formatted())
            .font(.system(size: 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(
                isProminent
                    ? AnyShapeStyle(Color(nsColor: .alternateSelectedControlTextColor))
                    : AnyShapeStyle(.primary)
            )
            .background(
                isProminent ? Color.clear : AppPalette.color("sidebarBadgeBackgroundColor"),
                in: Capsule()
            )
    }
}
