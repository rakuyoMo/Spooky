import AppKit
import SwiftUI

// MARK: - AddUserProfileDialog

/// 把仓库当前的提交人身份存成身份档案：姓名、邮箱与签名密钥取自仓库，只填写档案标题。
///
/// 标题为空或与已有档案重名时不能添加，重名的原因显示在错误区。
struct AddUserProfileDialog: View {
    /// 档案的姓名。
    let name: String

    /// 档案的邮箱。
    let email: String

    /// 档案的签名密钥；为 nil 时档案不带密钥。
    let signingKey: String?

    /// 关闭对话框。
    let close: () -> Void

    /// 全部档案的 JSON。
    @AppStorage(UserProfiles.key)
    private var storage = Data()

    /// 档案标题。
    @State
    private var title = AppLocalization.text("profiles.newProfile")

    /// 对话框骨架里放标题输入；标题重名的原因显示在错误区。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("profiles.add"),
            message: AppLocalization.text(
                "profiles.add.message",
                name,
                email,
                signingKey.map(UserProfiles.keyDescription) ?? AppLocalization.text("signing.none")
            ),
            submitTitle: AppLocalization.text("profiles.add.submit"),
            error: titleExists ? AppLocalization.text("profiles.titleExists") : nil,
            canSubmit: !trimmedTitle.isEmpty && !titleExists,
            cancel: close,
            submit: add
        ) {
            HStack(spacing: 8) {
                Text(AppLocalization.text("profiles.title"))

                TextField("", text: $title)
                    .accessibilityLabel(AppLocalization.text("profiles.title"))
            }
            .padding(.leading, 150)
            .padding(.trailing, 20)
            .padding(.vertical, 20)
        }
    }
}

// MARK: - Private

extension AddUserProfileDialog {
    /// 去掉首尾空格后的标题。
    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespaces)
    }

    /// 已有同名档案。
    private var titleExists: Bool {
        UserProfiles.decode(storage).contains { $0.title == trimmedTitle }
    }

    /// 追加新档案，已有档案原样保留。
    private func add() {
        let profile = UserProfile(title: trimmedTitle, name: name, email: email, signingKey: signingKey)
        storage = UserProfiles.encode(UserProfiles.decode(storage) + [profile])
        close()
    }
}

// MARK: - UserProfiles

extension UserProfiles {
    /// 在窗口上以 sheet 打开 “Add User Profile”，把当前提交人身份存成新档案。
    ///
    /// - Parameters:
    ///   - name: 当前的 `user.name`。
    ///   - email: 当前的 `user.email`。
    ///   - signingKey: 当前的 `user.signingkey`；为 nil 时档案不带密钥。
    ///   - window: 提交区所在的窗口。
    @MainActor
    static func add(name: String, email: String, signingKey: String?, in window: NSWindow) {
        let parent = window.attachedSheet ?? window
        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed

        let content = NSHostingController(
            rootView: AddUserProfileDialog(name: name, email: email, signingKey: signingKey) { [weak sheet] in
                if let sheet {
                    parent.endSheet(sheet)
                }
            }
        )

        // sheet 的高度取内容的理想尺寸，说明折成几行就留几行的高度。
        content.sizingOptions = .preferredContentSize
        sheet.contentViewController = content
        parent.beginSheet(sheet)
    }
}
