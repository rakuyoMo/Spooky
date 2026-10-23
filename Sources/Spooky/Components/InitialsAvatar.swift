import SwiftUI

// MARK: - InitialsAvatar

/// 没有头像图片时的圆形占位：显示姓名前两个词的首字母。
struct InitialsAvatar: View {
    /// 提交人或档案的姓名。
    let name: String

    /// 圆形的直径。
    let size: CGFloat

    /// 首字母按直径缩放字号，底色使用系统的四级填充色。
    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(.quaternary, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Private

extension InitialsAvatar {
    /// 前两个词各取首字母并转成大写；没有姓名时为空。
    private var initials: String {
        name.split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
    }
}
