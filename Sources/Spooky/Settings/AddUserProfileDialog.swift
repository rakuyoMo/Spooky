import AppKit
import SwiftUI

// MARK: - AddUserProfileDialog

/// 把仓库当前的提交人身份存成身份档案：姓名、邮箱与签名密钥取自仓库，只填写档案标题。
///
/// 标题为空或与已有档案重名时不能添加，重名的原因显示在错误区。头部文字对齐距左 120 pt 的对齐线，应用图标挂在左侧。
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

    /// 头部、标题输入、错误区与底栏。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            HStack(spacing: 8) {
                Text(AppLocalization.text("profiles.title"))

                TextField("", text: $title)
                    .accessibilityLabel(AppLocalization.text("profiles.title"))
            }
            .font(.system(size: 13))
            .padding(.leading, 150)
            .padding(.trailing, 20)
            .padding(.vertical, 20)

            if titleExists {
                errorRow
            }

            footer
        }
        .frame(width: 480)
    }
}

// MARK: - Private

extension AddUserProfileDialog {
    /// 头部文字与错误文字共用的左对齐线。
    private static let alignment = 120.0

    /// 去掉首尾空格后的标题。
    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespaces)
    }

    /// 已有同名档案。
    private var titleExists: Bool {
        UserProfiles.decode(storage).contains { $0.title == trimmedTitle }
    }

    /// 64 pt 应用图标与右侧的标题、说明；说明写出要保存的姓名、邮箱与签名密钥，文字列宽 340 pt。
    private var header: some View {
        HStack(alignment: .top, spacing: Self.alignment - 32 - 64) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text("profiles.add"))
                    .font(.system(size: 14, weight: .bold))

                Text(
                    AppLocalization.text(
                        "profiles.add.message",
                        name,
                        email,
                        signingKey.map(UserProfiles.keyDescription) ?? AppLocalization.text("signing.none")
                    )
                )
                .font(.system(size: 13))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(idealWidth: 340, maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 32)
        .padding(.trailing, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 黄色警告图标挂在对齐线左侧，原因文字从对齐线开始。
    private var errorRow: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            Text(AppLocalization.text("profiles.titleExists"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, Self.alignment - 4 - 18)
        .padding(.trailing, 20)
        .padding(.bottom, 12)
    }

    /// 取消与添加；标题为空或重名时添加不可用。
    private var footer: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)

            Button(action: close) {
                Text(AppLocalization.text("action.cancel"))
                    .frame(minWidth: 56)
            }
            .keyboardShortcut(.cancelAction)

            Button(action: add) {
                Text(AppLocalization.text("profiles.add.submit"))
                    .frame(minWidth: 56)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(trimmedTitle.isEmpty || titleExists)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(height: 53, alignment: .top)
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
