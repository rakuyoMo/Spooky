import AppKit
import SpookyKit
import SwiftUI

// MARK: - ThemesSettingsView

/// Themes 页：左侧主题列表，右侧编辑所选主题的字体与颜色，下方按主题绘制一段 Diff 预览。
///
/// 列表里选中的主题就是当前外观使用的主题，浅色、深色外观各自记住一套。
struct ThemesSettingsView: View {
    /// 色块行里 Font Color 之后的四个色块编辑的颜色，从左到右。
    nonisolated static let colorWellKeys = ["background", "selection", "added", "deleted"]

    /// 主题与外观选择。
    private let store: ThemeStore

    /// 当前外观，决定列表的选择写入浅色还是深色。
    @Environment(\.colorScheme)
    private var colorScheme

    /// 刚新建、要立即进入改名的主题。
    @State
    private var renameRequest: String?

    /// 记号类别列表里选中行的颜色键，Font Color 色块编辑这种颜色；打开页面时是 Plain Text，换主题时不变。
    @State
    private var selectedToken = "text"

    /// 宽 900 pt、高按右栏内容的页面：200 pt 的主题列表，相隔 8 pt 是 652 pt 的右栏，四周留 20 pt。
    var body: some View {
        let dark = colorScheme == .dark
        let theme = TextTheme.current(dark: dark, in: store)

        // 列表与右栏等高：右栏的各段都是固定高度，列表撑满同样的高度。
        HStack(alignment: .top, spacing: 8) {
            themeList(selected: theme, dark: dark)

            editor(theme)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(20)
        .frame(width: 900)
        .onAppear { store.reload() }
        .onDisappear {
            ThemeFontPicker.shared.stop()

            // 关闭颜色面板会让正在编辑的色块退出激活。
            if NSColorPanel.sharedColorPanelExists {
                NSColorPanel.shared.close()
            }
        }
        .onChange(of: isStored(theme) ? theme.id : nil) {
            followFontPanel(to: theme)
        }
    }

    /// 使用给定的主题存储；App 用共享的存储，进程内检查界面时传入使用临时目录的实例。
    init(store: ThemeStore = .shared) {
        self.store = store
    }
}

// MARK: - 列表

extension ThemesSettingsView {
    /// 200 pt 宽的主题列表：+ 与 − 在外框里的左下角，与滚动区之间不画分隔线；导入、导出经列表的拖放完成。
    private func themeList(selected theme: TextTheme, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ThemeListView(
                store: store,
                themes: store.themes,
                selectedID: theme.id,
                dark: dark,
                renameRequest: $renameRequest
            )

            // + 贴着外框左边，− 在它右边 2 pt；两者顶边在滚动区底边下 10 pt，底边在外框底边上 1 pt。
            HStack(spacing: 2) {
                listButton("plus", label: "themes.add", width: 24) {
                    create(dark: dark)
                }

                // 内置主题不能删除；没有文件可删时页面显示的资源里的版本同样是内置主题。
                listButton("minus", label: "themes.remove", width: 20) {
                    delete(theme, dark: dark)
                }
                .disabled(ThemeStore.isBuiltin(theme))
            }
            .padding(.top, 10)
            .padding(.bottom, 1)
        }
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .overlay(Rectangle().strokeBorder(AppPalette.color("general_border_color")))
    }

    /// 列表外框里 20 pt 高的无边框图标按钮。
    private func listButton(
        _ symbol: String,
        label key: String,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: width, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(AppLocalization.text(key))
        .accessibilityLabel(AppLocalization.text(key))
    }

    /// 按当前外观的内置配色新建 “New Theme” 并选中，随即进入改名、名称全选。
    private func create(dark: Bool) {
        perform("themes.error.save") {
            let theme = try store.create(named: AppLocalization.text("themes.newName"), dark: dark)
            renameRequest = theme.id
        }
    }

    /// 先在设置窗口上询问，确认后删除所选主题；所在外观改选列表的第一行。
    private func delete(_ theme: TextTheme, dark: Bool) {
        let identifier = theme.id
        let window = NSApp.keyWindow

        Task {
            guard await ThemeTransfer.confirmDelete(window: window) else {
                return
            }

            do {
                try store.delete(identifier, dark: dark)
            } catch {
                await ThemeTransfer.report(
                    error,
                    titleKey: "themes.error.delete",
                    file: nil,
                    window: window
                )
            }
        }
    }
}

// MARK: - 编辑

extension ThemesSettingsView {
    /// 右栏从上到下：字体框、记号类别列表、色块行、横线与 Diff 预览；用的是资源里的版本时没有文件可写，控件全部禁用。
    private func editor(_ theme: TextTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            fontField(theme)

            // 652 × 222 的记号类别列表，一次显示 9 行，其余滚动。
            ThemeTokenList(theme: theme, selection: $selectedToken)
                .frame(height: 222)
                .overlay(Rectangle().strokeBorder(AppPalette.color("general_border_color")))
                .padding(.top, 8)

            colorWells(theme)
                .padding(.top, 8)

            // 横线贴满右栏，两端不缩进。
            Color(nsColor: .separatorColor)
                .frame(height: 1)
                .padding(.top, 7)

            preview(theme)
                .padding(.top, 8)
        }
        .frame(width: 652, alignment: .leading)
    }

    /// 250 × 20 的字体框，不填底色：字体名与字号，右端 4 pt 处是字体面板的图标；点框里任意处都打开字体面板。
    private func fontField(_ theme: TextTheme) -> some View {
        let description = Self.fontDescription(theme)

        return Button {
            showFontPanel(theme)
        } label: {
            HStack(spacing: 4) {
                Text(description)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .padding(.leading, 2)

                Spacer(minLength: 0)

                Image(systemName: "t.square")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .padding(.trailing, 4)
            }
            .frame(width: 250, height: 20)
            .overlay(Rectangle().strokeBorder(AppPalette.color("general_border_color")))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isStored(theme))
        .accessibilityLabel(AppLocalization.text("themes.fontLabel"))
        .accessibilityValue(description)
    }

    /// 色块行：Font Color ｜ Background、Selection、Added、Deleted，列与列相隔 8 pt；Font Color 编辑记号类别列表里选中的那种颜色。
    private func colorWells(_ theme: TextTheme) -> some View {
        HStack(alignment: .top, spacing: 8) {
            colorColumn(selectedToken, label: AppLocalization.text("themes.text"), theme: theme)

            // Font Color 后面的竖线，两侧各 8 pt，上下从色块顶边到标签底边。
            Color(nsColor: .separatorColor)
                .frame(width: 1)

            ForEach(Self.colorWellKeys, id: \.self) { key in
                colorColumn(key, label: AppLocalization.text("themes." + key), theme: theme)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 一列：48 × 24 的色块与下面 4 pt 处 10 pt 的标签，都水平居中；列宽取 48 pt 与标签宽的较大值。
    private func colorColumn(_ key: String, label: String, theme: TextTheme) -> some View {
        VStack(spacing: 4) {
            ThemeColorWell(
                color: theme.colors[key],
                isEnabled: isStored(theme),
                label: label
            ) {
                setColor($0, for: key, of: theme)
            }
            .frame(width: 48, height: 24)

            Text(label)
                .font(.system(size: 10))
                .fixedSize()
        }
        .frame(minWidth: 48)
    }

    /// 652 × 222 的 Diff 预览：按 Diff 区的画法与正在编辑的主题显示一段固定补丁，改色后立即重画。
    private func preview(_ theme: TextTheme) -> some View {
        let style = TextStyle(
            theme: theme,
            tabWidth: TextPreferences.defaultTabWidth,
            showsInvisibles: false
        )

        return LazyVStack(alignment: .leading, spacing: 0) {
            if let hunk = Self.previewHunk() {
                DiffHunkView(
                    hunk: hunk,
                    style: style,
                    highlights: InlineDiff.ranges(in: hunk),
                    staged: false,
                    enabled: false,
                    readOnly: true,
                    showsHeader: false
                ) { _, _ in }
            }
        }
        .frame(width: 652, height: 222, alignment: .top)
        .background(style.color("background"))
        .clipped()
        .overlay(Rectangle().strokeBorder(AppPalette.color("general_border_color")))
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

    /// 选中别的主题时，打开着的字体面板改为编辑新主题；新主题没有文件可写（包括刚删掉了文件）就关闭面板。
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

    /// 主题是否在 Themes 目录里；所选主题与 Default 或 Default (Dark) 的文件都不可用时，页面显示的是资源里的版本。
    private func isStored(_ theme: TextTheme) -> Bool {
        store.themes.contains { $0.id == theme.id }
    }

    /// 把颜色面板调出的颜色写回主题文件。
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

// MARK: - Helpers

extension ThemesSettingsView {
    /// 字体框里的文字：PostScript 名、空格与一位小数的字号，如 “Menlo-Regular 11.0”。
    static func fontDescription(_ theme: TextTheme) -> String {
        theme.fontName + " " + String(format: "%.1f", theme.fontSize)
    }

    /// Diff 预览的补丁里唯一的一块：上下文、删除、新增、上下文四行，文字取当前语言。
    static func previewHunk() -> DiffHunk? {
        let context = AppLocalization.text("themes.preview.context")

        let lines = [
            "diff --git a/preview b/preview",
            "--- a/preview",
            "+++ b/preview",
            "@@ -1,3 +1,3 @@",
            " " + context,
            "-" + AppLocalization.text("themes.preview.deleted"),
            "+" + AppLocalization.text("themes.preview.added"),
            " " + context,
        ]

        let patch = Data((lines.joined(separator: "\n") + "\n").utf8)
        return (try? RepositoryDiff(patch: patch))?.files.first?.hunks.first
    }
}
