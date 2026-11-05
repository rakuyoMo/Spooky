import AppKit
import SwiftUI

// MARK: - FileHeaderBackground

/// 文件头部的窗口内材质，分隔线内嵌在头部底边。
struct FileHeaderBackground: View {
    /// 背景不改变头部的总高度。
    var body: some View {
        FileHeaderMaterial()
            .overlay(alignment: .bottom) {
                Color(nsColor: .separatorColor).frame(height: 1)
            }
    }
}

// MARK: - FileHeaderMaterial

/// 跟随窗口活跃状态的原生文件头部材质。
private struct FileHeaderMaterial: NSViewRepresentable {
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
