import SpookyKit
import SwiftUI

// MARK: - HostingUserAvatar

/// 托管服务上用户的圆形头像：按服务给出的地址取图，取不到时画首字母。
///
/// 提示与无障碍标签写用户的名字，没有名字时写用户名。
struct HostingUserAvatar: View {
    /// 头像的主人。
    let user: HostingUser

    /// 圆形的直径。
    let size: CGFloat

    /// 头像带上名字的提示，读屏时作为一个元素读出名字。
    var body: some View {
        InitialsAvatar(name: label, avatarURL: user.avatarURL, size: size)
            .help(label)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
    }

    /// 名字；没有名字时是用户名。
    private var label: String {
        guard let name = user.name, !name.isEmpty else {
            return user.username
        }

        return name
    }
}
