import AppKit
import SpookyKit
import SwiftUI

// MARK: - SigningKeyPopUp

/// 签名密钥的弹出菜单：本机的密钥、本机找不到的已配置密钥，最后是不带密钥；身份档案、Git Config 页与仓库设置共用。
///
/// 找不到的已配置密钥只用来显示当前的配置，不是可以换用的密钥，所以不可选。带提示时，密钥的菜单项提示它的完整写法，
/// 找不到的已配置密钥提示配置的值，弹出按钮提示选中的一项。宽度取提议的宽度，没有提议时按菜单里最宽的一项。
struct SigningKeyPopUp: NSViewRepresentable {
    /// 本机的签名密钥。
    let keys: [SigningKey]

    /// 本机找不到的已配置密钥；没有时为 nil。
    let unknown: String?

    /// 选中的值：密钥写入配置的值、找不到的已配置密钥，或表示不带密钥的 nil。
    @Binding
    var selection: String?

    /// 是否给菜单项与弹出按钮加提示。
    var showsToolTips = true

    /// 选择动作的目标。
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 系统样式的弹出按钮，菜单项的可用性由各项自己决定。
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.autoenablesItems = false
        button.target = context.coordinator
        button.action = #selector(Coordinator.choose(_:))

        return button
    }

    /// 各项变了才重建菜单，再选中选中的值，弹出按钮的提示随之更换；外面禁用时按钮随之不可用。
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let coordinator = context.coordinator
        let items = Self.items(keys: keys, unknown: unknown, showsToolTips: showsToolTips)

        coordinator.selection = $selection
        button.isEnabled = context.environment.isEnabled

        if coordinator.items != items {
            coordinator.items = items
            button.removeAllItems()

            for item in items {
                let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
                menuItem.toolTip = item.toolTip
                menuItem.isEnabled = item.isEnabled
                button.menu?.addItem(menuItem)
            }

            button.invalidateIntrinsicContentSize()
        }

        // 选中的值对不上任何一项时不选中，按钮不显示标题
        let index = items.firstIndex { $0.value == selection }

        button.selectItem(at: index ?? -1)
        button.toolTip = index.flatMap { items[$0].toolTip }
    }

    /// 宽度取提议的宽度，没有提议时按菜单里最宽的一项；高度是弹出按钮自己的高度。
    func sizeThatFits(_ proposal: ProposedViewSize, nsView button: NSPopUpButton, context _: Context) -> CGSize? {
        let intrinsic = button.intrinsicContentSize
        return CGSize(width: proposal.width ?? intrinsic.width, height: intrinsic.height)
    }
}

// MARK: - Items

extension SigningKeyPopUp {
    /// 菜单里的一项。
    struct Item: Equatable {
        /// 菜单项的标题。
        let title: String

        /// 选中后交出的值；No Signing Key 为 nil。
        let value: String?

        /// 菜单项的提示；不带提示时为 nil。
        let toolTip: String?

        /// 是否可选。
        var isEnabled = true
    }

    /// 菜单的各项：本机的密钥、找不到的已配置密钥与 No Signing Key。
    ///
    /// 密钥的完整写法：SSH 是 `ssh-add -L` 列出的那一行，OpenPGP 是完整指纹。
    ///
    /// - Parameters:
    ///   - keys: 本机的签名密钥。
    ///   - unknown: 本机找不到的已配置密钥。
    ///   - showsToolTips: 是否带提示。
    static func items(keys: [SigningKey], unknown: String?, showsToolTips: Bool) -> [Item] {
        let keyItems = keys.map { key in
            Item(
                title: UserProfiles.title(of: key),
                value: key.value,
                toolTip: showsToolTips ? key.publicKeyLine ?? key.value : nil
            )
        }

        let unknownItems = unknown.map { value in
            [
                Item(
                    title: UserProfiles.unknownKeyTitle(value),
                    value: value,
                    toolTip: showsToolTips ? value : nil,
                    isEnabled: false
                ),
            ]
        } ?? []

        let none = Item(title: AppLocalization.text("signing.none"), value: nil, toolTip: nil)

        return keyItems + unknownItems + [none]
    }
}

// MARK: SigningKeyPopUp.Coordinator

extension SigningKeyPopUp {
    /// 弹出按钮选择动作的目标。
    @MainActor
    final class Coordinator: NSObject {
        /// 菜单现在的各项，与菜单项一一对应。
        var items: [Item] = []

        /// 选中的值。
        var selection = Binding<String?>.constant(nil)

        /// 按下的菜单项换成它的值。
        @objc
        func choose(_ sender: NSPopUpButton) {
            let index = sender.indexOfSelectedItem

            guard items.indices.contains(index) else {
                return
            }

            selection.wrappedValue = items[index].value
        }
    }
}
