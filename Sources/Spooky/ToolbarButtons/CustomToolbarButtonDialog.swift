import AppKit
import SwiftUI

// MARK: - CustomToolbarButtonDialog

/// 添加或编辑自定义按钮的对话框：图标、名称与脚本三行。
///
/// 名称去掉首尾的空白后不能为空，脚本不能只有空白，图标要是这台 Mac 上有的符号；不满足时不能保存。
struct CustomToolbarButtonDialog: View {
    /// 编辑中的副本。
    @State
    private var button: CustomToolbarButton

    /// 是否在添加新按钮。
    let isNew: Bool

    /// 保存回调。
    let onSave: (CustomToolbarButton) -> Void

    /// 关闭对话框。
    let close: () -> Void

    /// 560 宽的对话框骨架：图标按钮、名称输入框，以及占满输入列、高 160 的脚本框。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text(isNew ? "toolbarButtons.add" : "toolbarButtons.edit.title"),
            message: AppLocalization.text("toolbarButtons.message"),
            width: 560,
            submitTitle: AppLocalization.text(isNew ? "toolbarButtons.add.submit" : "toolbarButtons.edit.submit"),
            helpArticle: .toolbarButtons,
            canSubmit: Self.canSave(button),
            cancel: close,
            submit: {
                onSave(Self.trimmed(button))
                close()
            }
        ) {
            DialogForm {
                DialogFormRow(label: AppLocalization.text("toolbarButtons.icon"), alignment: .center) {
                    SymbolPickerButton(symbol: $button.symbol)
                }

                DialogFormRow(label: AppLocalization.text("toolbarButtons.nameField")) {
                    TextField("", text: $button.name)
                }

                DialogFormRow(label: AppLocalization.text("toolbarButtons.scriptField"), alignment: .top) {
                    scriptEditor
                }
            }
        }
    }

    /// 以按钮的副本创建对话框。
    ///
    /// - Parameters:
    ///   - button: 要编辑的按钮；添加时是各项为默认值的新按钮。
    ///   - isNew: 是否在添加新按钮。
    ///   - onSave: 保存回调。
    ///   - close: 关闭对话框。
    init(
        button: CustomToolbarButton,
        isNew: Bool,
        onSave: @escaping (CustomToolbarButton) -> Void,
        close: @escaping () -> Void
    ) {
        _button = State(initialValue: button)
        self.isNew = isNew
        self.onSave = onSave
        self.close = close
    }
}

// MARK: - Rules

extension CustomToolbarButtonDialog {
    /// 按钮能否保存：名称去掉首尾空白后不为空，脚本不只有空白，图标是这台 Mac 上有的符号。
    ///
    /// - Parameter button: 编辑中的按钮。
    static func canSave(_ button: CustomToolbarButton) -> Bool {
        !button.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !button.script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && NSImage(systemSymbolName: button.symbol, accessibilityDescription: nil) != nil
    }

    /// 保存的按钮：名称去掉首尾的空白，脚本原样保留，第一行的 `#!` 才认得出。
    ///
    /// - Parameter button: 编辑中的按钮。
    static func trimmed(_ button: CustomToolbarButton) -> CustomToolbarButton {
        var trimmed = button
        trimmed.name = button.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }
}

// MARK: - Presenting

extension CustomToolbarButtonDialog {
    /// 在设置窗口上以 sheet 打开对话框；没有窗口时不打开。
    ///
    /// - Parameters:
    ///   - button: 要编辑的按钮；为 nil 时添加新按钮。
    ///   - window: 设置窗口。
    ///   - save: 保存回调。
    @MainActor
    static func present(
        _ button: CustomToolbarButton?,
        on window: NSWindow?,
        save: @escaping (CustomToolbarButton) -> Void
    ) {
        guard let window else {
            return
        }

        DialogWindow.present(on: window) { close in
            CustomToolbarButtonDialog(
                button: button ?? CustomToolbarButton(),
                isNew: button == nil,
                onSave: save,
                close: close
            )
        }
    }
}

// MARK: - Private

extension CustomToolbarButtonDialog {
    /// 占满输入列、高 160 的脚本框，带边框。
    private var scriptEditor: some View {
        ScriptTextEditor(
            text: $button.script,
            label: AppLocalization.text("toolbarButtons.scriptField")
        )
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(AppPalette.color("general_border_color"))
        }
    }
}
