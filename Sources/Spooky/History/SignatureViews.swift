import AppKit
import SpookyKit
import SwiftUI

// MARK: - CommitSignatureButton

/// 列表行末的签名按钮：开启签名校验且签名有效时才出现，点击弹出签名详情。
struct CommitSignatureButton: View {
    /// 窗口的签名结果。
    let store: CommitSignatureStore

    /// 这一行的提交。
    let commit: String

    /// 校验用的执行器；没有仓库时为空。
    let runner: GitRunner?

    /// 小号行用 10 pt 图标，中号行用 12 pt。
    let small: Bool

    /// 列表是否校验签名。
    @AppStorage(CommitSignatureStore.verifiesKey)
    private var verifies = false

    /// 签名弹窗是否打开。
    @State
    private var showsPopover = false

    #warning("TODO: 按钮只在签名有效时出现；“有效” 是否包括可信度未知（U）是推断。核实方式：在列表里看一个签名有效但密钥不受信任的提交是否有签名按钮；只影响列表行的签名按钮。")

    /// 有效与可信度未知的签名用不同的状态点。
    var body: some View {
        if verifies, let signature = store.signatures[commit], [.good, .unknownValidity].contains(signature.status) {
            let image = signature.status == .good
                ? NSImage.statusAvailableName
                : NSImage.statusPartiallyAvailableName

            Button {
                showsPopover = true
            } label: {
                Image(nsImage: NSImage(named: image) ?? NSImage())
                    .resizable()
                    .frame(width: small ? 10 : 12, height: small ? 10 : 12)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(AppLocalization.text("signature.show"))
            .popover(isPresented: $showsPopover, arrowEdge: .bottom) {
                SignaturePopover(signature: signature)
            }
        } else if verifies, let runner {
            // 还没有结果时登记请求，结果到达后按钮随之出现
            Color.clear
                .frame(width: 0, height: 0)
                .task(id: commit) { store.request(commit, runner: runner) }
        }
    }
}

// MARK: - SignaturePopover

/// 签名详情：有签名者姓名与邮箱时显示头像与身份，只有密钥时显示密钥与状态，没有签名时只有一行说明。
struct SignaturePopover: View {
    /// 校验结果；正在校验时为空。
    let signature: CommitSignature?

    /// 三种视图按签名内容选择。
    var body: some View {
        Group {
            if let signature, signature.status != .unsigned {
                if let name = signature.name, let email = signature.email {
                    identity(name: name, email: email, signature: signature)
                } else {
                    details(signature, keyLabel: "signature.signingKey")
                }
            } else if signature == nil {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(AppLocalization.text("signature.unsigned"))
                    .font(.system(size: 13))
            }
        }
        .padding(20)
    }

    /// 有身份的签名：头像、姓名、邮箱，以及密钥与状态。
    private func identity(name: String, email: String, signature: CommitSignature) -> some View {
        HStack(alignment: .top, spacing: 12) {
            InitialsAvatar(name: name, size: 35)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 13))
                    .textSelection(.enabled)

                Text(email)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                details(signature, keyLabel: "signature.gpgKey")
                    .padding(.top, 4)
            }
        }
    }

    /// 密钥与状态两行；OpenPGP 的密钥标签为 GPG Key，其余为 Signing Key。
    private func details(_ signature: CommitSignature, keyLabel: String) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
            if !signature.key.isEmpty {
                GridRow {
                    Text(AppLocalization.text(keyLabel))
                        .gridColumnAlignment(.trailing)

                    Text(signature.key)
                        .textSelection(.enabled)
                }
            }

            GridRow {
                Text(AppLocalization.text("signature.status"))
                    .gridColumnAlignment(.trailing)

                Text(signature.status.title)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}

// MARK: - TagBadgeButton

/// 历史行里可点击的标签标记：点击后校验标签签名并在弹窗里显示。
struct TagBadgeButton<Label: View>: View {
    /// 标签的完整引用名。
    let reference: String

    /// 校验用的执行器；没有仓库时点击无效。
    let runner: GitRunner?

    /// 标记本身的外观。
    @ViewBuilder
    let label: () -> Label

    /// 弹窗是否打开。
    @State
    private var showsPopover = false

    /// 校验结果；正在校验时为空。
    @State
    private var signature: CommitSignature? = nil

    /// 每次打开弹窗都重新校验，密钥环的变化立即反映出来。
    var body: some View {
        Button {
            signature = nil
            showsPopover = true
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppLocalization.text("signature.show"))
        .popover(isPresented: $showsPopover, arrowEdge: .top) {
            SignaturePopover(signature: signature)
                .task { await verify() }
        }
    }

    /// 校验标签签名；校验失败按无法校验显示。
    private func verify() async {
        guard let runner else {
            return
        }

        let result = try? await RepositoryReferences(runner: runner).signature(ofTag: reference)

        guard !Task.isCancelled else {
            return
        }

        signature = result ?? CommitSignature(status: .cannotCheck)
    }
}
