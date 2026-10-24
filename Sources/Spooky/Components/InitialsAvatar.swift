import SwiftUI

// MARK: - InitialsAvatar

/// 圆形头像：有邮箱时按邮箱取头像图片，没有图片时显示姓名前两个词的首字母。
///
/// 图片在后台读取，读到之前与读不到时都显示首字母，同一个人的占位在各处一致。
struct InitialsAvatar: View {
    /// 提交人或档案的姓名。
    let name: String

    /// 取头像图片用的邮箱；nil 时只显示首字母。
    let email: String?

    /// 圆形的直径。
    let size: CGFloat

    /// 读到的头像图片。
    @State
    private var image: NSImage? = nil

    /// 头像按圆形裁切；首字母按直径缩放字号，底色使用系统的四级填充色。
    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(.quaternary, in: Circle())
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: email) {
            // 行被复用换成别人时先回到首字母，避免短暂显示上一个人的头像
            image = nil
            image = await AvatarStore.shared.image(for: email)
        }
    }

    /// 创建头像；不传邮箱时只显示首字母。
    init(name: String, email: String? = nil, size: CGFloat) {
        self.name = name
        self.email = email
        self.size = size
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
