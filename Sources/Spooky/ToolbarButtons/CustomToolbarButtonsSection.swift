import AppKit
import SwiftUI

// MARK: - CustomToolbarButtonsSection

/// Integration 页的工具栏按钮：一行标题、按钮表与底部的添加、删除、编辑，最后是说明；左右与分组的分隔线对齐。
///
/// 双击一行，或选中后点编辑，打开编辑对话框；删除前确认。
struct CustomToolbarButtonsSection: View {
    /// 按钮的存取。
    let store: CustomToolbarButtonStore

    /// 表格里选中的按钮。
    @State
    private var selection: CustomToolbarButton.ID?

    /// 等待确认删除的按钮。
    @State
    private var deleting: CustomToolbarButton?

    /// 标题、高 160 的按钮表与说明，间距 8。
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.text("toolbarButtons.title"))

            VStack(spacing: 0) {
                table

                Divider()

                actions
            }
            .frame(height: 160)
            .overlay {
                Rectangle()
                    .stroke(AppPalette.color("general_border_color"))
            }

            Text(
                AppLocalization.text(
                    "toolbarButtons.help",
                    AppLocalization.text("menu.view"),
                    AppLocalization.text("menu.customizeToolbar")
                )
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, SettingsFormLayout.separatorInset)
        .alert(
            AppLocalization.text("toolbarButtons.delete.title"),
            isPresented: Binding(
                get: { deleting != nil },
                set: { if !$0 { deleting = nil } }
            ),
            presenting: deleting
        ) { button in
            Button(AppLocalization.text("toolbarButtons.delete.submit"), role: .destructive) {
                delete(button)
            }

            Button(AppLocalization.text("action.cancel"), role: .cancel) {
                deleting = nil
            }
        } message: { button in
            Text(AppLocalization.text("toolbarButtons.delete.message", button.name))
        }
    }
}

// MARK: - Private

extension CustomToolbarButtonsSection {
    /// 选中的按钮。
    private var selected: CustomToolbarButton? {
        store.buttons.first { $0.id == selection }
    }

    /// 名称与脚本两列：名称前是按钮的图标，脚本一列写第一行内容。
    private var table: some View {
        Table(store.buttons, selection: $selection) {
            TableColumn(AppLocalization.text("toolbarButtons.name")) { button in
                Label {
                    Text(button.name)
                } icon: {
                    Image(systemName: button.symbol)
                }
                .lineLimit(1)
                .help(button.name)
            }

            TableColumn(AppLocalization.text("toolbarButtons.script")) { button in
                Text(Self.summary(of: button.script))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .alternatingRowBackgrounds(.disabled)
        .contextMenu(forSelectionType: CustomToolbarButton.ID.self) { _ in
        } primaryAction: { ids in
            guard let button = store.buttons.first(where: { ids.contains($0.id) }) else {
                return
            }

            edit(button)
        }
        .overlay {
            if store.buttons.isEmpty {
                Text(AppLocalization.text("toolbarButtons.empty"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 底部 22 pt 的操作条：添加、删除与编辑；没有选中按钮时后两项不可用。
    private var actions: some View {
        HStack(spacing: 0) {
            Button {
                edit(nil)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 20)
            }
            .accessibilityLabel(AppLocalization.text("toolbarButtons.add"))

            Button {
                deleting = selected
            } label: {
                Image(systemName: "minus")
                    .frame(width: 24, height: 20)
            }
            .disabled(selected == nil)
            .accessibilityLabel(AppLocalization.text("toolbarButtons.delete.title"))

            Spacer(minLength: 0)

            Button(AppLocalization.text("toolbarButtons.edit")) {
                edit(selected)
            }
            .disabled(selected == nil)
            .padding(.trailing, 8)
        }
        .buttonStyle(.borderless)
        .frame(height: 22)
    }

    /// 表格里脚本一列的内容：第一行既不是空白也不是 `#!` 的文字。
    ///
    /// - Parameter script: 按钮的脚本。
    private static func summary(of script: String) -> String {
        script
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("#!") } ?? ""
    }

    /// 在设置窗口上打开对话框：给了按钮时编辑它，没有时添加新按钮；保存后选中它。
    ///
    /// - Parameter button: 要编辑的按钮；为 nil 时添加新按钮。
    private func edit(_ button: CustomToolbarButton?) {
        CustomToolbarButtonDialog.present(button, on: NSApp.keyWindow) { saved in
            store.save(saved)
            selection = saved.id
        }
    }

    /// 确认后删除按钮，放在工具栏里的一份随之移除。
    ///
    /// - Parameter button: 要删除的按钮。
    private func delete(_ button: CustomToolbarButton) {
        deleting = nil
        store.remove(button.id)

        if selection == button.id {
            selection = nil
        }
    }
}
