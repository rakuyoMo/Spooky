import SpookyKit
import SwiftUI

// MARK: - CommitIdentityView

/// 提交人的姓名、邮箱与头像；点头像弹出身份档案菜单，头像的提示写明提交时的签名状态。
struct CommitIdentityView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 姓名与邮箱右对齐叠放在 45 pt 头像左侧，提示显示签名状态。
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(session.committer.name)
                Text(session.committer.email)
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(minWidth: 50, alignment: .trailing)
            .textSelection(.enabled)
            .help(session.repository?.displayPath ?? "")

            Menu {
                IdentityProfileMenu(
                    name: session.committer.name,
                    email: session.committer.email,
                    signingKey: session.commitConfiguration?.signingKey,
                    canApply: session.canWrite,
                    apply: session.applyProfile
                )
            } label: {
                InitialsAvatar(name: session.committer.name, size: 45)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(signingStatus)
            .accessibilityLabel(AppLocalization.text("profiles.menu"))
        }
    }
}

// MARK: - Private

extension CommitIdentityView {
    /// 提交时会不会签名，以及使用的密钥与格式。
    private var signingStatus: String {
        guard let configuration = session.commitConfiguration else {
            return ""
        }

        guard configuration.signsCommits else {
            return AppLocalization.text("signing.off")
        }

        let format = configuration.signingFormat.displayName

        if let key = configuration.signingKey {
            return AppLocalization.text("signing.key", key, format)
        }

        // OpenPGP 没有配置密钥时由 gpg 按提交人邮箱选择密钥，其它格式必须配置密钥。
        return configuration.signingFormat == .openpgp
            ? AppLocalization.text("signing.defaultKey", format)
            : AppLocalization.text("signing.none")
    }
}

// MARK: - SigningFormat

extension SigningFormat {
    /// 界面显示的格式名，与 Git 文档中的写法一致。
    var displayName: String {
        switch self {
        case .openpgp: "OpenPGP"
        case .x509: "X.509"
        case .ssh: "SSH"
        }
    }
}
