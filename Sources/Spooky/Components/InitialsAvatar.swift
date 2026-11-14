import SwiftUI

// MARK: - InitialsAvatar

/// 头像，默认是圆形：有头像地址时按地址取图片，否则按邮箱取；没有图片时显示姓名前两个词的首字母。
///
/// 图片在后台读取，读到之前与读不到时都显示首字母，同一个人的占位在各处一致。
struct InitialsAvatar: View {
    /// 提交人或档案的姓名。
    let name: String

    /// 取头像图片用的邮箱；没有头像地址时使用。
    let email: String?

    /// 托管服务给出的头像地址；有地址时不按邮箱取。
    let avatarURL: URL?

    /// 圆形的直径或方形的边长。
    let size: CGFloat

    /// 是否画成方形；冲突向导的提交栏用方形。
    let isSquare: Bool

    /// 读到的头像图片。
    @State
    private var image: NSImage? = nil

    /// 头像按圆形或方形裁切，外圈 1 pt 分隔线色的描边；首字母按尺寸缩放字号，用次要文字色，底色是头像的命名底色。
    var body: some View {
        let shape = isSquare ? AnyShape(Rectangle()) : AnyShape(Circle())

        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(shape)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(AppPalette.color("avatar_background_color"), in: shape)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            // 描边画在裁切范围以内，图片与首字母占位都有
            if isSquare {
                Rectangle().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            } else {
                Circle().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
        .task(id: avatarURL?.absoluteString ?? email) {
            // 行被复用换成别人时先回到首字母，避免短暂显示上一个人的头像
            image = nil

            if let avatarURL {
                image = await AvatarStore.shared.image(at: avatarURL)
            } else {
                image = await AvatarStore.shared.image(for: email)
            }
        }
    }

    /// 创建头像；邮箱与头像地址都不传时只显示首字母。
    ///
    /// - Parameters:
    ///   - name: 姓名，取首字母用。
    ///   - email: 取 Gravatar 头像用的邮箱。
    ///   - avatarURL: 托管服务给出的头像地址。
    ///   - size: 圆形的直径或方形的边长。
    ///   - isSquare: 是否画成方形。
    init(
        name: String,
        email: String? = nil,
        avatarURL: URL? = nil,
        size: CGFloat,
        isSquare: Bool = false
    ) {
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
        self.size = size
        self.isSquare = isSquare
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
