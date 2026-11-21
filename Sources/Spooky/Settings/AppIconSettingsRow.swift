import AppKit
import SwiftUI

// MARK: - AppIconSettingsRow

/// Appearance 页的 “App Icon:” 一行：左侧预览一组图标的大图与它的四版在 Dock 里的样子，右侧是按系列分节的图标选择区，点一枚立即换成那一组。
///
/// 预览的是指针或键盘所指的图标，没有时是所选的组；换组时先写入或清除 App 包的自定义图标，写完选中才落到那一枚，
/// 写不进去时下方写出原因，所选的组不变。
struct AppIconSettingsRow: View {
    /// 图标选择区的宽度。
    private static let pickerWidth: CGFloat = 250

    /// 预览与图标选择区的高度。
    private static let height: CGFloat = 246

    /// 预览与图标选择区的间距。
    private static let spacing: CGFloat = 12

    /// 标签的基线到这一行顶边的距离：与第一个系列名的基线排齐。
    private nonisolated static let labelBaseline: CGFloat = 11

    /// App 图标的控制器；App 不是经 `SpookyApplicationController` 启动时为 nil，这一行不显示。
    let controller: AppIconController?

    /// 所在页的控件列宽：预览占去图标选择区与间距之外的部分。
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

    /// 右对齐的标签与第一个系列名排齐，控件列里是预览与图标选择区，失败说明在它们下方 8 pt；与上方的外观一行相距 8 pt。
    var body: some View {
        if let controller {
            SettingsRow(AppLocalization.text("settings.appIcon.label")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: Self.spacing) {
                        preview(controller)

                        AppIconPicker(controller: controller, previewed: $previewed, pending: pending) {
                            select($0, with: controller)
                        }
                        .frame(width: Self.pickerWidth, height: Self.height)
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
    /// 预览：160 pt 的大图，画法与 Dock 相同、指示灯灭着；下方是这一组的四版在 Dock 里的样子。
    /// - Parameter controller: App 图标的控制器
    private func preview(_ controller: AppIconController) -> some View {
        VStack(spacing: 0) {
            Image(nsImage: previewIcon ?? controller.unlitIcon ?? NSImage())
                .resizable()
                .frame(width: 160, height: 160)

            Spacer(minLength: 0)

            dock(previewed ?? controller.group, controller: controller)
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
        .frame(width: layout.controlWidth - Self.spacing - Self.pickerWidth, height: Self.height)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    /// Dock 的示意：一条圆角底板上这一组的四版图标。默认图标在最左，下方是运行指示点；
    /// 一条竖线之后依次是连着服务器的一版、深色图标与深色图标连着服务器的一版。
    /// - Parameters:
    ///   - group: 图标所属的组
    ///   - controller: App 图标的控制器
    private func dock(_ group: AppIconGroup, controller: AppIconController) -> some View {
        let icon = { (variant: AppIconVariant) in
            Image(nsImage: controller.bundledIcon(of: group, variant: variant) ?? NSImage())
                .resizable()
                .frame(width: 44, height: 44)
        }

        return HStack(spacing: 0) {
            icon(.standard)
                .overlay(alignment: .bottom) {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 3, height: 3)
                        .offset(y: 5)
                }

            Rectangle()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 1, height: 34)
                .padding(.horizontal, 9)

            icon(AppIconVariant(isDark: false, isConnected: true))

            icon(AppIconVariant(isDark: true, isConnected: false))

            icon(AppIconVariant(isDark: true, isConnected: true))
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 7)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
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
