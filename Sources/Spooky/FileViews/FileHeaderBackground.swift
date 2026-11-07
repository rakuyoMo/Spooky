import AppKit
import SwiftUI

// MARK: - FileHeaderBackground

/// 文件头部的窗口内材质，分隔线内嵌在头部底边。
struct FileHeaderBackground: View {
    /// 背景不改变头部的总高度。
    var body: some View {
        HeaderMaterial()
            .overlay(alignment: .bottom) {
                Color(nsColor: .separatorColor).frame(height: 1)
            }
    }
}
