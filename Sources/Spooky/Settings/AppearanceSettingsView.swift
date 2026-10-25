import SwiftUI

// MARK: - AppearanceSettingsView

/// Appearance 页：跟随系统、浅色、深色三张缩略图，点一张即切换整个 App 的外观。
struct AppearanceSettingsView: View {
    /// 当前外观的 `rawValue`；与快捷操作的外观项读写同一个偏好。
    @AppStorage(AppAppearance.key)
    private var selection = AppAppearance.system.rawValue

    /// 右对齐的标签与 278 pt 宽的缩略图选择器。
    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow(alignment: .top) {
                Text(AppLocalization.text("settings.appearance.label"))
                    .gridColumnAlignment(.trailing)

                HStack(spacing: 6) {
                    ForEach(AppAppearance.allCases) { appearance in
                        option(appearance)
                    }
                }
                .frame(width: 278, alignment: .leading)
            }
        }
        .padding(40)
        .frame(width: 900, alignment: .top)
    }
}

// MARK: - Private

extension AppearanceSettingsView {
    /// 一个外观：85 pt 宽的缩略图与下方的名称；选中的缩略图描一圈强调色。
    private func option(_ appearance: AppAppearance) -> some View {
        let selected = selection == appearance.rawValue

        return Button {
            appearance.select()
        } label: {
            VStack(spacing: 6) {
                AppearanceThumbnail(appearance: appearance)
                    .frame(width: 85, height: 53)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    }
                    .padding(3)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3)
                    }

                Text(appearance.title)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appearance.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - AppearanceThumbnail

/// 自绘的外观缩略图：桌面上的一扇窗口；跟随系统的一张左半浅色、右半深色。
private struct AppearanceThumbnail: View {
    /// 要画的外观。
    let appearance: AppAppearance

    /// 跟随系统时把深色的一半盖在右侧。
    var body: some View {
        switch appearance {
        case .light:
            WindowSketch(dark: false)

        case .dark:
            WindowSketch(dark: true)

        case .system:
            ZStack {
                WindowSketch(dark: false)

                WindowSketch(dark: true)
                    .mask(alignment: .trailing) {
                        GeometryReader { proxy in
                            Rectangle()
                                .frame(width: proxy.size.width / 2)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
            }
        }
    }
}

// MARK: - WindowSketch

/// 缩略图里的一个场景：渐变的桌面，左上方露出一扇带红绿灯、侧边栏与几行内容的窗口。
///
/// 各部分都用系统的语义色，按这张缩略图自己的外观解析，与 App 当前的外观无关。
private struct WindowSketch: View {
    /// 画深色外观。
    let dark: Bool

    /// 窗口从左上方伸出画面，右下角被裁掉。
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: desktop, startPoint: .topLeading, endPoint: .bottomTrailing)

            window
                .frame(width: 90, height: 56)
                .offset(x: 12, y: 10)
        }
        .environment(\.colorScheme, dark ? .dark : .light)
    }

    /// 桌面渐变的两端。
    private var desktop: [Color] {
        dark ? [.indigo, .black] : [.blue, .cyan]
    }

    /// 标题栏与红绿灯、侧边栏和内容区的几行文字。
    private var window: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                ForEach([Color.red, .yellow, .green], id: \.self) { color in
                    Circle()
                        .fill(color.opacity(0.85))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.leading, 4)
            .frame(height: 9)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach([40.0, 28, 34, 22], id: \.self) { width in
                        Capsule()
                            .fill(Color(nsColor: .tertiaryLabelColor))
                            .frame(width: width, height: 3)
                    }
                }
                .padding(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}
