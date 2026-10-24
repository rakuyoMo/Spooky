import AppKit
import SwiftUI

// MARK: - ThemesSettingsView

/// Themes 页：左侧主题列表，右侧编辑所选主题的字体与颜色，下方按主题绘制示例文本。
///
/// 列表里选中的主题就是当前外观使用的主题，浅色、深色外观各自记住一套。
struct ThemesSettingsView: View {
    /// 用户主题与外观选择。
    private let store = ThemeStore.shared

    /// 当前外观，决定列表的选择写入浅色还是深色。
    @Environment(\.colorScheme)
    private var colorScheme

    /// 无法加载的主题弹出框是否显示。
    @State
    private var showsInvalidFiles = false

    /// 150 pt 主题列表和右侧的字体、色板与示例文本。
    var body: some View {
        let dark = colorScheme == .dark
        let theme = TextTheme.current(dark: dark, in: store)

        HStack(alignment: .top, spacing: 20) {
            themeList(selected: theme, dark: dark)
            editor(theme, dark: dark)
        }
        .padding(20)
        .frame(width: 900, height: 450)
        .background(AppPalette.color("general_background_color"))
        .onAppear { store.reload() }
        .onDisappear { ThemeFontPicker.shared.stop() }
        .onChange(of: theme.id) { followFontPanel(to: theme) }
    }
}

// MARK: - 列表

extension ThemesSettingsView {
    /// 有无法加载的主题文件时显示的警告按钮，点开列出这些文件。
    private var invalidFilesButton: some View {
        Button { showsInvalidFiles.toggle() } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.borderless)
        .help(AppLocalization.text("themes.invalidTitle"))
        .accessibilityLabel(AppLocalization.text("themes.invalidTitle"))
        .popover(isPresented: $showsInvalidFiles, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text("themes.invalid"))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(store.invalidFiles, id: \.self) { url in
                    Text(url.lastPathComponent)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .frame(width: 300, alignment: .leading)
        }
    }

    /// 主题列表与底部 22 pt 的操作条。
    private func themeList(selected theme: TextTheme, dark: Bool) -> some View {
        VStack(spacing: 0) {
            ThemeListView(store: store, themes: store.themes, selectedID: theme.id, dark: dark)

            Divider()

            actionBar(theme, dark: dark)
        }
        .frame(width: 150)
        .overlay(Rectangle().stroke(AppPalette.color("general_border_color")))
    }

    /// 新建、删除、无法加载的提示，以及导入导出菜单。
    private func actionBar(_ theme: TextTheme, dark: Bool) -> some View {
        HStack(spacing: 0) {
            barButton("plus", label: "themes.add") {
                perform("themes.error.save") {
                    _ = try store.create(named: AppLocalization.text("themes.newName"), dark: dark)
                }
            }

            barButton("minus", label: "themes.remove") {
                perform("themes.error.delete") { try store.delete(theme.id) }
            }
            .disabled(!isStored(theme))

            if !store.invalidFiles.isEmpty {
                invalidFilesButton
            }

            Spacer(minLength: 0)

            transferMenu(theme)
        }
        .padding(.horizontal, 3)
        .frame(height: 22)
    }

    /// 操作条上 16 pt 的图标按钮。
    private func barButton(_ symbol: String, label key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(AppLocalization.text(key))
        .accessibilityLabel(AppLocalization.text(key))
    }

    /// 拖放之外的导入、导出入口，键盘与读屏同样可以使用。
    private func transferMenu(_ theme: TextTheme) -> some View {
        Menu {
            Button(AppLocalization.text("themes.import")) {
                let window = NSApp.keyWindow
                Task { await ThemeTransfer.chooseImport(into: store, window: window) }
            }

            Button(AppLocalization.text("themes.export")) {
                let window = NSApp.keyWindow
                Task { await ThemeTransfer.export(theme, window: window) }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(AppLocalization.text("themes.actions"))
        .accessibilityLabel(AppLocalization.text("themes.actions"))
    }
}

// MARK: - 编辑

extension ThemesSettingsView {
    /// 字体、正文色、三个色板与示例文本；用的是资源里的版本时没有文件可写，控件全部禁用。
    private func editor(_ theme: TextTheme, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            fontRow(theme)

            colorWells(theme)

            Text(AppLocalization.text(dark ? "themes.usedInDark" : "themes.usedInLight"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            preview(theme)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 只读的字体名称与字号、打开字体面板的按钮和 25 pt 宽的正文色板。
    private func fontRow(_ theme: TextTheme) -> some View {
        let fontName = theme.font.displayName ?? theme.fontName
        let description = AppLocalization.text("themes.font", fontName, theme.fontSize.formatted())

        return HStack(spacing: 4) {
            Text(description)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(minWidth: 200, minHeight: 22, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(Rectangle().stroke(AppPalette.color("general_border_color")))
                .accessibilityLabel(AppLocalization.text("themes.fontLabel"))
                .accessibilityValue(description)

            Button(AppLocalization.text("themes.change")) { showFontPanel(theme) }
                .disabled(!isStored(theme))

            ThemeColorWell(
                color: theme.colors["text"],
                isEnabled: isStored(theme),
                label: AppLocalization.text("themes.text")
            ) { setColor($0, for: "text", of: theme) }
                .frame(width: 25, height: 22)
        }
    }

    /// 背景、新增、删除三个 50 × 30 pt 的色板，标签在色板下方 4 pt。
    private func colorWells(_ theme: TextTheme) -> some View {
        HStack(spacing: 30) {
            ForEach(["background", "added", "deleted"], id: \.self) { key in
                VStack(spacing: 4) {
                    ThemeColorWell(
                        color: theme.colors[key],
                        isEnabled: isStored(theme),
                        label: AppLocalization.text("themes." + key)
                    ) { setColor($0, for: key, of: theme) }
                        .frame(width: 50, height: 30)

                    Text(AppLocalization.text("themes." + key))
                        .font(.system(size: 11))
                }
            }
        }
    }

    /// 按主题的字体、正文色和增删底色绘制的示例文本，便于直接核对配色。
    private func preview(_ theme: TextTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            previewLine(AppLocalization.text("themes.preview.context"), theme: theme, kind: "background")
            previewLine(AppLocalization.text("themes.preview.deleted"), theme: theme, kind: "deleted")
            previewLine(AppLocalization.text("themes.preview.added"), theme: theme, kind: "added")
        }
        .padding(12)
        .background(theme.colors["background"]?.color ?? .clear)
        .overlay(Rectangle().stroke(AppPalette.color("general_border_color")))
    }

    /// 示例里的一行：主题字体与正文色，铺上对应的底色。
    private func previewLine(_ text: String, theme: TextTheme, kind: String) -> some View {
        Text(text)
            .font(.custom(theme.fontName, size: theme.fontSize))
            .foregroundStyle(theme.colors["text"]?.color ?? .primary)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors[kind]?.color ?? .clear)
    }
}

// MARK: - Private

extension ThemesSettingsView {
    /// 打开字体面板编辑主题的字体，面板里的每次改动都写回主题文件。
    private func showFontPanel(_ theme: TextTheme) {
        let identifier = theme.id

        ThemeFontPicker.shared.show(theme.font) { font in
            perform("themes.error.save") {
                try store.update(identifier) {
                    $0.fontName = font.fontName
                    $0.fontSize = Double(font.pointSize)
                }
            }
        }
    }

    /// 选中别的主题时，打开着的字体面板改为编辑新主题；新主题没有文件可写就关闭面板。
    private func followFontPanel(to theme: TextTheme) {
        guard ThemeFontPicker.shared.isEditing else {
            return
        }

        if isStored(theme) {
            showFontPanel(theme)
        } else {
            ThemeFontPicker.shared.stop()
        }
    }

    /// 主题是否在 Themes 目录里；所选主题与 Default 的文件都无法加载时，页面显示的是资源里的版本。
    private func isStored(_ theme: TextTheme) -> Bool {
        store.themes.contains { $0.id == theme.id }
    }

    /// 把色板选出的颜色写回主题文件。
    private func setColor(_ color: PaletteColor, for key: String, of theme: TextTheme) {
        perform("themes.error.save") {
            try store.update(theme.id) { $0.colors[key] = color }
        }
    }

    /// 执行一次主题文件操作，失败时在设置窗口上提示。
    private func perform(_ titleKey: String, _ action: () throws -> Void) {
        do {
            try action()
        } catch {
            let window = NSApp.keyWindow
            Task {
                await ThemeTransfer.report(error, titleKey: titleKey, file: nil, window: window)
            }
        }
    }
}
