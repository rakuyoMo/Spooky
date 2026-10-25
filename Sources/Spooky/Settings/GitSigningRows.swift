import SpookyKit
import SwiftUI

// MARK: - GitSigningRows

/// Git Config 页的签名组：SSH 签名程序、GPG 程序、全局签名密钥、allowed signers 文件、签名开关与邮箱一致的检查。
///
/// 程序无效或密钥邮箱与提交人邮箱不一致时，控件右侧出现警告按钮，点按显示说明。
struct GitSigningRows: View {
    /// 签名组里需要说明的问题。
    enum Notice: Equatable {
        /// 配置的 GPG 程序不是可用的 GnuPG。
        case invalidGPG(String)

        /// 配置的 SSH 签名程序不存在或不能执行。
        case invalidSSH(String)

        /// 签名密钥的邮箱与全局提交人邮箱不一致。
        case emailMismatch(key: String, user: String)

        /// 说明的标题。
        var title: String {
            switch self {
            case .invalidGPG: AppLocalization.text("gitConfig.invalidGPG")
            case .invalidSSH: AppLocalization.text("gitConfig.invalidSSH")
            case .emailMismatch: AppLocalization.text("gitConfig.emailMismatch")
            }
        }

        /// 说明的正文。
        var message: String {
            switch self {
            case .invalidGPG(let path): AppLocalization.text("gitConfig.invalidGPG.message", path)
            case .invalidSSH(let path): AppLocalization.text("gitConfig.invalidSSH.message", path)
            case .emailMismatch(let key, let user): AppLocalization.text("gitConfig.emailMismatch.message", key, user)
            }
        }
    }

    /// 偏好键：签名密钥的邮箱与提交人邮箱不一致时给出警告。
    static let ensureEmailMatchKey = "ensureSigningKeyEmailMatches"

    /// 全局配置的读写状态。
    let model: GlobalGitConfigModel

    /// 签名密钥的邮箱与提交人邮箱不一致时给出警告。
    @AppStorage(Self.ensureEmailMatchKey)
    private var ensuresEmailMatch = true

    /// 本机找到的 gpg。
    @State
    var gpgPrograms: [String] = []

    /// 1Password 的 SSH 签名程序。
    @State
    var onePasswordSigner: String?

    /// 配置的 GPG 程序是可用的 GnuPG；没有配置时也算可用。
    @State
    private var gpgValid = true

    /// 正在显示的说明。
    @State
    private var shownNotice: Notice?

    /// 依次排列的七行；控件列 278 pt，警告按钮挂在控件右侧。
    var body: some View {
        GridRow {
            label("gitConfig.sshProgram")

            sshProgramPicker
                .overlay(alignment: .trailing) { caution(sshNotice) }
        }

        GridRow {
            label("gitConfig.gpgProgram")

            gpgProgramPicker
                .overlay(alignment: .trailing) { caution(gpgNotice) }
        }

        GridRow {
            label("gitConfig.signingKey")

            signingKeyPicker
                .overlay(alignment: .trailing) { caution(mismatchNotice) }
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Text(AppLocalization.text("gitConfig.agentKeys"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 278, alignment: .leading)
        }

        GridRow {
            label("gitConfig.allowedSigners")
            allowedSignersPicker
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Toggle(AppLocalization.text("gitConfig.signCommits"), isOn: signsCommits)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 278, alignment: .leading)
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Toggle(AppLocalization.text("gitConfig.ensureEmailMatch"), isOn: $ensuresEmailMatch)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 278, alignment: .leading)
        }
        .alert(
            shownNotice?.title ?? "",
            isPresented: Binding(get: { shownNotice != nil }, set: { if !$0 { shownNotice = nil } }),
            presenting: shownNotice
        ) { _ in
            Button(AppLocalization.text("action.ok")) { shownNotice = nil }
        } message: { notice in
            Text(notice.message)
        }
        .task(id: model.configuration.gpgProgram) {
            gpgPrograms = SigningPrograms.gpgPrograms()
            onePasswordSigner = SigningPrograms.onePasswordSigner

            // 没有配置 GPG 程序时不检查；配置了就看它能不能当 GnuPG 运行。
            if let program = model.configuration.gpgProgram {
                gpgValid = await SigningKeys.isGnuPG(HomePath.expanded(program))
            } else {
                gpgValid = true
            }
        }
    }
}

// MARK: - Private

extension GitSigningRows {
    /// 配置的 SSH 签名程序不能执行时的说明。
    private var sshNotice: Notice? {
        guard
            let program = model.configuration.sshProgram,
            !FileManager.default.isExecutableFile(atPath: HomePath.expanded(program))
        else {
            return nil
        }

        return .invalidSSH(program)
    }

    /// 配置的 GPG 程序不可用时的说明。
    private var gpgNotice: Notice? {
        guard let program = model.configuration.gpgProgram, !gpgValid else {
            return nil
        }

        return .invalidGPG(program)
    }

    /// 打开检查时，OpenPGP 签名密钥的邮箱与全局提交人邮箱不一致的说明。
    private var mismatchNotice: Notice? {
        guard
            ensuresEmailMatch,
            let configured = model.configuration.signingKey,
            let user = model.configuration.userEmail,
            let signer = model.keys.first(where: { $0.format == .openpgp && $0.matches(configured) })?.signer,
            let open = signer.lastIndex(of: "<"),
            let close = signer.lastIndex(of: ">"),
            open < close
        else {
            return nil
        }

        let email = String(signer[signer.index(after: open) ..< close])
        return email.caseInsensitiveCompare(user) == .orderedSame ? nil : .emailMismatch(key: email, user: user)
    }

    /// 提交时签名，写 `commit.gpgsign`。
    private var signsCommits: Binding<Bool> {
        Binding(
            get: { model.configuration.signsCommits },
            set: { enabled in
                Task { await model.write([(GlobalGitConfiguration.Key.signsCommits, enabled ? "true" : "false")]) }
            }
        )
    }

    /// 右对齐的标签。
    func label(_ key: String) -> some View {
        Text(AppLocalization.text(key))
            .gridColumnAlignment(.trailing)
    }

    /// 控件右侧 8 pt 外的黄色警告按钮；没有问题时不占位置。
    @ViewBuilder
    private func caution(_ notice: Notice?) -> some View {
        if let notice {
            Button {
                shownNotice = notice
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
            .buttonStyle(.borderless)
            .help(notice.title)
            .accessibilityLabel(notice.title)
            .alignmentGuide(.trailing) { $0[.leading] - 8 }
        }
    }
}
