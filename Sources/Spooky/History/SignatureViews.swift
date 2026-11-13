import AppKit
import SpookyKit
import SwiftUI

// MARK: - CommitSignatureButton

/// 列表行末的签名按钮：开启签名校验后，有签名的提交都有，点击弹出签名详情；没有签名或还没校验完时不出现。
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

    /// 状态图标按校验结果分三档。
    var body: some View {
        if verifies, let signature = store.signatures[commit], signature.status != .unsigned {
            Button {
                showsPopover = true
            } label: {
                SignatureStatusIcon(status: signature.status, size: small ? 10 : 12)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(AppLocalization.text("signature.show"))
            .accessibilityValue(signature.status.title)
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

// MARK: - SignatureStatusIcon

/// 签名状态的图标：有效是绿点，无效是红点，其余是黄点；系统开启 “区分时不仅依赖颜色” 时红点换成方块、黄点换成三角。
private struct SignatureStatusIcon: View {
    /// 签名的校验结果，不是没有签名。
    let status: SignatureStatus

    /// 图标边长。
    let size: CGFloat

    /// 系统的 “区分时不仅依赖颜色”。
    @Environment(\.accessibilityDifferentiateWithoutColor)
    private var differentiatesWithoutColor

    /// 绿点不换形状；红点与黄点在不依赖颜色时换成方块与三角。
    var body: some View {
        switch status {
        case .good:
            Self.statusImage(NSImage.statusAvailableName, size: size)

        case .bad:
            if differentiatesWithoutColor {
                Self.symbol("square.fill", color: .red, size: size)
            } else {
                Self.statusImage(NSImage.statusUnavailableName, size: size)
            }

        default:
            if differentiatesWithoutColor {
                Self.symbol("triangle.fill", color: .yellow, size: size)
            } else {
                Self.statusImage(NSImage.statusPartiallyAvailableName, size: size)
            }
        }
    }

    /// 系统的状态圆点。
    private static func statusImage(_ name: NSImage.Name, size: CGFloat) -> some View {
        Image(nsImage: NSImage(named: name) ?? NSImage())
            .resizable()
            .frame(width: size, height: size)
    }

    /// 填充的形状符号，与状态圆点同样大小。
    private static func symbol(_ name: String, color: Color, size: CGFloat) -> some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }
}

// MARK: - SignaturePopover

/// 签名详情：有姓名与邮箱的 OpenPGP 签名显示头像与身份，其余显示短标识与状态，没有签名时只有一行说明。
///
/// 四周留 20 pt；校验结果晚于弹窗出现时，弹窗跟着结果变大。
struct SignaturePopover: View {
    /// 校验结果；正在校验时为空。
    let signature: CommitSignature?

    /// 三种视图按签名内容选择。
    ///
    /// 弹窗只在内容报出固定的理想尺寸时跟着内容变大小；去掉 `fixedSize()`，弹窗停在打开时转圈的大小，结果被截成 “…”。
    var body: some View {
        Group {
            if let signature, signature.status != .unsigned {
                if !signature.isSSH, let name = signature.name, let email = signature.email {
                    identity(name: name, email: email, signature: signature)
                } else {
                    details(signature, keyLabel: "signature.signingKey", labelAlignment: .trailing)
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
        .fixedSize()
    }

    /// 有身份的签名：头像右边是姓名与邮箱，分隔线下方是密钥与状态。
    private func identity(name: String, email: String, signature: CommitSignature) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                InitialsAvatar(name: name, email: email, size: 35)

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 13))
                        .textSelection(.enabled)

                    Text(email)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Divider()
                .padding(.top, 8)

            details(signature, keyLabel: "signature.gpgKey", labelAlignment: .center)
                .padding(.top, 12)
        }
    }

    /// 短标识与状态两行；有身份的 OpenPGP 签名标签为 GPG Key，其余为 Signing Key；没有短标识时只有状态。
    ///
    /// - Parameter labelAlignment: 标签一列的对齐；有身份时两个标签居中对齐，只有密钥时靠右。
    private func details(
        _ signature: CommitSignature,
        keyLabel: String,
        labelAlignment: HorizontalAlignment
    ) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
            if let shortKeyID = signature.shortKeyID {
                GridRow {
                    Text(AppLocalization.text(keyLabel))
                        .gridColumnAlignment(labelAlignment)

                    Text(shortKeyID)
                }
            }

            GridRow {
                Text(AppLocalization.text("signature.status"))
                    .gridColumnAlignment(labelAlignment)

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

    /// 点击打开弹窗，弹窗每次打开都重新校验。
    var body: some View {
        Button {
            showsPopover = true
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppLocalization.text("signature.show"))
        .popover(isPresented: $showsPopover, arrowEdge: .top) {
            TagSignaturePopover(reference: reference, runner: runner)
        }
    }
}

// MARK: - TagSignaturePopover

/// 标签签名的弹窗内容，历史行的标签标记与侧边栏标签的 Show Signature 共用。
///
/// 每次打开都重新校验，密钥环的变化立即反映出来。
struct TagSignaturePopover: View {
    /// 标签的完整引用名。
    let reference: String

    /// 校验用的执行器；没有仓库时一直显示校验中。
    let runner: GitRunner?

    /// 校验结果；正在校验时为空。
    @State
    private var signature: CommitSignature? = nil

    /// 打开时开始校验。
    var body: some View {
        SignaturePopover(signature: signature)
            .task { await verify() }
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
