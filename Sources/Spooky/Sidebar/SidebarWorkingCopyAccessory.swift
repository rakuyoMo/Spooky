import SpookyKit
import SwiftUI

// MARK: - SidebarWorkingCopyAccessory

/// Working Copy 入口末尾的标记，侧边栏的行与极窄版式的视图导航共用。
///
/// 有进行中的操作时显示 18 × 18 pt 的操作图标，没有时显示不为零的改动文件数；
/// 加载期间照常显示上一次的结果，进度显示在入口的图标上。
struct SidebarWorkingCopyAccessory: View {
    /// 当前窗口会话。
    let session: RepositorySession

    /// 操作图标或改动文件数，都没有时不占位置。
    var body: some View {
        switch RepositorySidebarView.WorkingCopyMarker.current(
            progress: session.context?.progress,
            status: session.status
        ) {
        case .operation(let symbol):
            // 自绘的图形按前景样式填色，随所在行的选中状态变色；可访问性名称与操作横幅的标题相同
            AppSymbolShape(name: symbol)
                .frame(width: 18, height: 18)
                .accessibilityElement()
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel(session.operationBannerTitle ?? "")

        case .changes(let count):
            SidebarCountBadge(count: count)
                .accessibilityLabel(AppLocalization.text("workspace.changed", count))

        case nil:
            EmptyView()
        }
    }
}
