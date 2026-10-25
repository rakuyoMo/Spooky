import AppKit
import SpookyKit
import SwiftUI

// MARK: - Pickers

extension GitSigningRows {
    /// 弹出菜单里 “选择文件” 一项的标记，不是任何路径。
    private static let chooseTag = "\u{0}choose"

    /// SSH 签名程序：系统的 ssh-keygen（不写配置）、装了 1Password 时它的签名程序，以及配置里的其它程序。
    var sshProgramPicker: some View {
        let configured = model.configuration.sshProgram
        let programs = [onePasswordSigner, configured].compactMap(\.self).reduce(into: [String]()) { result, path in
            if !result.contains(path) {
                result.append(path)
            }
        }

        return Picker("", selection: configBinding(GlobalGitConfiguration.Key.sshProgram, value: configured)) {
            Text(AppLocalization.text("gitConfig.sshProgram.system"))
                .tag("")

            ForEach(programs, id: \.self) { path in
                Text(
                    path == onePasswordSigner
                        ? AppLocalization.text("gitConfig.sshProgram.onePassword")
                        : HomePath.abbreviated(path)
                )
                .tag(path)
            }
        }
        .labelsHidden()
        .frame(width: 278)
        .help(configured ?? "")
        .accessibilityLabel(AppLocalization.text("gitConfig.sshProgram"))
    }

    /// GPG 程序：没有配置时的说明、本机找到的 gpg、配置里的其它程序，最后是选择其它程序。
    var gpgProgramPicker: some View {
        let configured = model.configuration.gpgProgram
        let programs = gpgPrograms + (configured.map { gpgPrograms.contains($0) ? [] : [$0] } ?? [])

        return Picker("", selection: choosingBinding(GlobalGitConfiguration.Key.gpgProgram, value: configured)) {
            Text(AppLocalization.text(gpgPrograms.isEmpty ? "gitConfig.gpgProgram.notFound" : "gitConfig.gpgProgram.none"))
                .tag("")

            ForEach(programs, id: \.self) { path in
                Text(HomePath.abbreviated(path))
                    .tag(path)
            }

            Divider()

            Text(AppLocalization.text("gitConfig.gpgProgram.select"))
                .tag(Self.chooseTag)
        }
        .labelsHidden()
        .frame(width: 278)
        .help(configured ?? "")
        .accessibilityLabel(AppLocalization.text("gitConfig.gpgProgram"))
    }

    /// 全局签名密钥：本机的 OpenPGP 与 SSH 密钥、本机找不到的已配置密钥，最后是不带密钥；选中后同时写入签名格式。
    var signingKeyPicker: some View {
        let configured = model.configuration.signingKey
        let unknown = configured.flatMap { value in model.keys.contains { $0.matches(value) } ? nil : value }

        let selection = Binding<String?>(
            get: { configured.map { value in model.keys.first { $0.matches(value) }?.value ?? value } },
            set: { key in
                let entries: [(key: String, value: String?)] =
                    if let key {
                        [
                            (GlobalGitConfiguration.Key.signingKey, key),
                            (GlobalGitConfiguration.Key.signingFormat, SigningFormat(key: key).rawValue),
                        ]
                    } else {
                        [(GlobalGitConfiguration.Key.signingKey, nil)]
                    }

                Task { await model.write(entries) }
            }
        )

        return Picker("", selection: selection) {
            ForEach(model.keys, id: \.value) { key in
                Text(UserProfiles.title(of: key))
                    .tag(Optional(key.value))
            }

            if let unknown {
                Text(UserProfiles.keyDescription(unknown))
                    .tag(Optional(unknown))
                    .disabled(true)
            }

            Text(AppLocalization.text("signing.none"))
                .tag(String?.none)
        }
        .labelsHidden()
        .frame(width: 278)
        .disabled(model.keys.isEmpty && configured == nil)
        .accessibilityLabel(AppLocalization.text("gitConfig.signingKey"))
    }

    /// allowed signers 文件：不使用、`~/.ssh/allowed_signers`、配置里的其它文件，最后是选择文件。
    var allowedSignersPicker: some View {
        let configured = model.configuration.allowedSignersFile
        let files = [SigningPrograms.defaultAllowedSigners, configured].compactMap(\.self)
            .reduce(into: [String]()) { result, path in
                let known = result.contains { HomePath.expanded($0) == HomePath.expanded(path) }

                if !known {
                    result.append(path)
                }
            }

        return Picker("", selection: choosingBinding(GlobalGitConfiguration.Key.allowedSignersFile, value: configured)) {
            Text(AppLocalization.text("gitConfig.allowedSigners.none"))
                .tag("")

            ForEach(files, id: \.self) { path in
                Text(HomePath.abbreviated(HomePath.expanded(path)))
                    .tag(path)
            }

            Divider()

            Text(AppLocalization.text("gitConfig.allowedSigners.select"))
                .tag(Self.chooseTag)
        }
        .labelsHidden()
        .frame(width: 278)
        .help(configured ?? "")
        .accessibilityLabel(AppLocalization.text("gitConfig.allowedSigners"))
    }

    /// 选中即写入的绑定：空字符串删除这个键。
    ///
    /// - Parameters:
    ///   - key: 配置键。
    ///   - value: 当前的值。
    private func configBinding(_ key: String, value: String?) -> Binding<String> {
        Binding(
            get: { value ?? "" },
            set: { selected in
                Task { await model.write([(key, selected.isEmpty ? nil : selected)]) }
            }
        )
    }

    /// 带 “选择文件” 一项的绑定：选中它时打开面板，选好的文件写进配置，菜单仍显示原来的值。
    ///
    /// - Parameters:
    ///   - key: 配置键。
    ///   - value: 当前的值。
    private func choosingBinding(_ key: String, value: String?) -> Binding<String> {
        let binding = configBinding(key, value: value)

        return Binding(
            get: { binding.wrappedValue },
            set: { selected in
                guard selected == Self.chooseTag else {
                    binding.wrappedValue = selected
                    return
                }

                chooseFile { binding.wrappedValue = $0 }
            }
        )
    }

    /// 在设置窗口上以 sheet 打开文件选择面板，只能选文件。
    ///
    /// - Parameter choose: 选好后以文件路径回调。
    private func chooseFile(_ choose: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else {
                return
            }

            choose(url.path)
        }

        guard let window = NSApp.keyWindow else {
            finish(panel.runModal())
            return
        }

        panel.beginSheetModal(for: window, completionHandler: finish)
    }
}
