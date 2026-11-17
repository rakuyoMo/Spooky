import AppKit
import SwiftUI

// MARK: - AppIconSettingsRow

/// Appearance 页的 “App Icon:” 一行：左侧预览一组图标的大图与它在 Dock 里的样子，右侧是每组一行的列表，点一行立即换成那一组。
///
/// 预览的是指针或键盘所指的一行，没有时是所选的组；换组时先写入或清除 App 包的自定义图标，写完选中才落到那一行，
/// 写不进去时下方写出原因，所选的组不变。
struct AppIconSettingsRow: View {
    /// 列表的宽度。
    private static let listWidth: CGFloat = 250

    /// 列表一行的高度。
    private static let rowHeight: CGFloat = 34

    /// 列表四周的内边距。
    private static let listPadding: CGFloat = 4

    /// 预览与列表的间距。
    private static let spacing: CGFloat = 12

    /// 标签的基线到这一行顶边的距离：与列表第一行的组名排齐。
    private static let labelBaseline: CGFloat = 26

    /// App 图标的控制器；App 不是经 `SpookyApplicationController` 启动时为 nil，这一行不显示。
    let controller: AppIconController?

    /// 所在页的控件列宽：预览占去列表与间距之外的部分。
    @Environment(\.settingsFormLayout)
    private var layout

    /// 指针或键盘所指的组；为 nil 时预览所选的组。
    @State
    private var previewed: AppIconGroup? = nil

    /// 所指的组的预览图标；为 nil 时用所选的组的。
    @State
    private var previewIcon: NSImage? = nil

    /// 正在写入的组；写入期间不能再换。
    @State
    private var pending: AppIconGroup? = nil

    /// 写入失败的说明；为 nil 时不显示。
    @State
    private var error: String? = nil

    /// 右对齐的标签与列表第一行的组名排齐，控件列里是预览与列表，失败说明在它们下方 8 pt；与上方的外观一行相距 8 pt。
    var body: some View {
        if let controller {
            SettingsRow(AppLocalization.text("settings.appIcon.label")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: Self.spacing) {
                        preview(controller)

                        list(controller)
                    }

                    if let error {
                        failure(error)
                    }
                }
                .alignmentGuide(.firstTextBaseline) { $0[.top] + Self.labelBaseline }
            }
            .padding(.top, SettingsFormLayout.rowSpacing)
            .onChange(of: previewed) { _, group in
                previewIcon = group.flatMap(controller.unlitIcon(of:))
            }
        }
    }

    /// 创建这一行。
    /// - Parameter controller: App 图标的控制器，默认取 App 自己的；测试传入指向临时 App 的控制器
    init(
        controller: AppIconController? = (NSApp.delegate as? SpookyApplicationController)?.appIconController
    ) {
        self.controller = controller
    }
}

// MARK: - Private

extension AppIconSettingsRow {
    /// 预览与列表的高度：列表刚好露出全部的组。
    private static var height: CGFloat {
        CGFloat(AppIconGroup.allCases.count) * rowHeight + listPadding * 2
    }

    /// 预览：160 pt 的大图，下方是它在 Dock 里的样子；画法与 Dock 相同，指示灯灭着。
    /// - Parameter controller: App 图标的控制器
    private func preview(_ controller: AppIconController) -> some View {
        let icon = previewIcon ?? controller.unlitIcon ?? NSImage()

        return VStack(spacing: 0) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 160, height: 160)

            Spacer(minLength: 0)

            dock(icon)
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
        .frame(width: layout.controlWidth - Self.spacing - Self.listWidth, height: Self.height)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    /// Dock 的示意：一条圆角底板上五个 44 pt 的格子，正中是图标与它下方的运行指示点，两侧各两个占位的色块。
    /// - Parameter icon: 正中的图标
    private func dock(_ icon: NSImage) -> some View {
        HStack(spacing: 0) {
            ForEach(0 ..< 5) { index in
                if index == 2 {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 44, height: 44)
                        .overlay(alignment: .bottom) {
                            Circle()
                                .fill(.secondary)
                                .frame(width: 3, height: 3)
                                .offset(y: 5)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 8.5)
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 36, height: 36)
                        .padding(4)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 7)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    /// 列表：每组一行；有键盘焦点时 ↑ ↓ 移动所指的一行，空格换成它。VoiceOver 把列表读成 “App Icon”，所选的一行带选中状态。
    /// - Parameter controller: App 图标的控制器
    private func list(_ controller: AppIconController) -> some View {
        VStack(spacing: 0) {
            ForEach(AppIconGroup.allCases) { group in
                row(group, controller: controller)
            }
        }
        .padding(Self.listPadding)
        .frame(width: Self.listWidth)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color(nsColor: .separatorColor))
        }
        .focusable()
        .onKeyPress(.upArrow) { movePreview(by: -1, from: controller.group) }
        .onKeyPress(.downArrow) { movePreview(by: 1, from: controller.group) }
        .onKeyPress(.space) {
            select(previewed ?? controller.group, with: controller)
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppLocalization.text("settings.appIcon.label"))
    }

    /// 一行：30 pt 的小图标与组名。所选的一行是选中色，正在写入的一行灰底、右端转圈，所指的一行浅灰底。
    /// - Parameters:
    ///   - group: 这一行的组
    ///   - controller: App 图标的控制器
    private func row(_ group: AppIconGroup, controller: AppIconController) -> some View {
        let isSelected = group == controller.group

        return Button {
            select(group, with: controller)
        } label: {
            HStack(spacing: 6) {
                Image(nsImage: controller.bundledIcon(of: group) ?? NSImage())
                    .resizable()
                    .frame(width: 30, height: 30)

                Text(group.title)
                    .foregroundStyle(isSelected ? Color.white : .primary)

                Spacer(minLength: 0)

                if group == pending {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 6)
            .frame(height: Self.rowHeight)
            .background(rowBackground(group, isSelected: isSelected), in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(pending != nil)
        .onHover { isHovering in
            if isHovering {
                previewed = group
            } else if previewed == group {
                previewed = nil
            }
        }
        .accessibilityLabel(group.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 一行的底色。
    /// - Parameters:
    ///   - group: 这一行的组
    ///   - isSelected: 是否所选的组
    private func rowBackground(_ group: AppIconGroup, isSelected: Bool) -> Color {
        if isSelected {
            return Color(nsColor: .selectedContentBackgroundColor)
        }

        if group == pending {
            return Color.primary.opacity(0.09)
        }

        return group == previewed ? Color.primary.opacity(0.055) : .clear
    }

    /// 失败说明：黄色警告图标与原因。
    /// - Parameter error: 写入失败的原因
    private func failure(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
        }
    }

    /// 把所指的一行上移或下移一行，到头不动；还没有所指的行时从所选的组起。
    /// - Parameters:
    ///   - offset: 移动的行数
    ///   - selected: 所选的组
    private func movePreview(by offset: Int, from selected: AppIconGroup) -> KeyPress.Result {
        let groups = AppIconGroup.allCases
        let index = groups.firstIndex(of: previewed ?? selected).map { $0 + offset }

        if let index, groups.indices.contains(index) {
            previewed = groups[index]
        }

        return .handled
    }

    /// 换成这一组：写入期间与已是所选的组时不动；写不进去时在下方写出原因，所选的组不变。
    /// - Parameters:
    ///   - group: 要换成的组
    ///   - controller: App 图标的控制器
    private func select(_ group: AppIconGroup, with controller: AppIconController) {
        guard pending == nil, group != controller.group else {
            return
        }

        pending = group
        error = nil

        Task {
            do {
                try await controller.select(group)
            } catch {
                self.error = error.localizedDescription
            }

            pending = nil
        }
    }
}
