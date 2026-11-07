import AppKit
import SwiftUI

// MARK: - HeaderMaterial

/// 跟随窗口活跃状态的原生头部材质，文件头部与提交区共用。
struct HeaderMaterial: NSViewRepresentable {
    /// 不强调的 headerView 材质在窗口内部混合。
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .headerView
        view.blendingMode = .withinWindow
        view.state = .followsWindowActiveState
        return view
    }

    /// 材质不依赖视图模型。
    func updateNSView(_: NSVisualEffectView, context _: Context) { }
}
