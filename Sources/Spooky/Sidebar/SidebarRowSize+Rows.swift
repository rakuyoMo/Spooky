import SwiftUI

// MARK: - SidebarRowSize

/// 侧边栏条目行随系统 “侧边栏图标大小” 取的行高、字体与列表档位。
///
/// 侧边栏列表的条目行不能低于列表所在档位的默认行高（小 24、中 32、大 40 pt），
/// 所以列表固定在默认行高不超过目标行高的档位，条目行再换回系统的档位与字体，定成目标行高。
extension SidebarRowSize {
    /// 条目行的高度：小档 24、中档 28、大档 32 pt。
    var rowHeight: CGFloat {
        switch self {
        case .small: 24
        case .medium: 28
        case .large: 32
        @unknown default: 28
        }
    }

    /// 列表固定的档位：小档与中档取小档，大档取中档。
    ///
    /// 列表按这一档的默认行高估计尚未显示的行的位置；大档的估计与实际相同，中档的行比估计高 4 pt。
    var listSize: SidebarRowSize {
        switch self {
        case .small, .medium: .small
        case .large: .medium
        @unknown default: .small
        }
    }

    /// 条目行的字体，与列表在这一档默认使用的字体相同。
    var rowFont: Font {
        switch self {
        case .small: .subheadline
        case .medium: .body
        case .large: .title3
        @unknown default: .body
        }
    }
}
