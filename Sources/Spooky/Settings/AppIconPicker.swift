import AppKit
import SwiftUI

// MARK: - AppIconPicker

/// 应用图标的选择区：按系列分节，系列名在上，下面每行四枚图标；内容高过选择区时竖向滚动，还有内容的一边渐隐。
///
/// 所选的图标描一圈强调色，指针或键盘所指的图标放大一点，正在写入的图标变淡并转圈。
/// 有键盘焦点时四周不画焦点环，← → ↑ ↓ 移动所指的图标，空格换成它；所指的图标不在可见范围内时滚到它，出现时滚到所选的图标。
/// VoiceOver 把选择区读成 “App Icon”，每枚图标读出组名，所选的一枚带选中状态。
struct AppIconPicker: View {
    /// 每行的图标数。
    private static let columnCount = 4

    /// 图标之间的间距。
    private static let tileSpacing: CGFloat = 6

    /// 系列之间的间距。
    private static let seriesSpacing: CGFloat = 16

    /// 渐隐的最大长度；滚出去的内容不到这么长时，渐隐的长度与它相同。
    private static let fadeLength: CGFloat = 18

    /// App 图标的控制器。
    let controller: AppIconController

    /// 指针或键盘所指的组；为 nil 时没有所指的图标。
    @Binding
    var previewed: AppIconGroup?

    /// 正在写入的组；写入期间不能再换。
    let pending: AppIconGroup?

    /// 换成一组。
    let select: (AppIconGroup) -> Void

    /// 上下两边渐隐的长度。
    @State
    private var fade = AppIconPickerFade()

    /// 各系列自上而下排开，整体可以竖向滚动。
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Self.seriesSpacing) {
                    ForEach(AppIconSeries.allCases) { series in
                        section(series)
                    }
                }
            }
            .onScrollGeometryChange(for: AppIconPickerFade.self) {
                AppIconPickerFade(geometry: $0, length: Self.fadeLength)
            } action: { _, fade in
                self.fade = fade
            }
            .mask { fadeMask }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) {
                movePreview(with: $0.key, proxy: proxy)
            }
            .onKeyPress(.space) {
                select(previewed ?? controller.group)
                return .handled
            }
            .onAppear {
                proxy.scrollTo(controller.group)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppLocalization.text("settings.appIcon.label"))
    }
}

// MARK: - Private

extension AppIconPicker {
    /// 自上而下的每一行图标：各系列的组依次每 `columnCount` 枚一行。
    private static var rows: [[AppIconGroup]] {
        AppIconSeries.allCases.flatMap(rows(of:))
    }

    /// 上下两边渐隐的蒙版：渐隐的长度内由透明过渡到不透明。
    private var fadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: fade.top)

            Color.black

            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: fade.bottom)
        }
    }

    /// 一个系列的每一行图标：这一系列的组每 `columnCount` 枚一行。
    /// - Parameter series: 图标所属的系列
    private static func rows(of series: AppIconSeries) -> [[AppIconGroup]] {
        let groups = series.groups

        return stride(from: 0, to: groups.count, by: columnCount).map {
            Array(groups[$0 ..< min($0 + columnCount, groups.count)])
        }
    }

    /// 一个系列：11 pt 的系列名，右侧一条细线拉到右缘，下面是这一系列的图标。
    /// - Parameter series: 这一节的系列
    private func section(_ series: AppIconSeries) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(series.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)
            }

            Grid(horizontalSpacing: Self.tileSpacing, verticalSpacing: Self.tileSpacing) {
                ForEach(Self.rows(of: series), id: \.self) { row in
                    GridRow {
                        ForEach(row) { group in
                            tile(group)
                        }
                    }
                }
            }
        }
    }

    /// 一枚图标：占满所在的格子。所选的一枚描一圈 3 pt 的强调色，所指的一枚放大到 1.1 倍，正在写入的一枚变淡、正中转圈。
    /// - Parameter group: 这一枚图标的组
    private func tile(_ group: AppIconGroup) -> some View {
        let isSelected = group == controller.group

        return Button {
            select(group)
        } label: {
            Image(nsImage: controller.bundledIcon(of: group) ?? NSImage())
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .scaleEffect(group == previewed ? 1.1 : 1)
                .opacity(group == pending ? 0.4 : 1)
                .animation(.easeOut(duration: 0.14), value: previewed)
                .overlay {
                    if group == pending {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(AppIconTileStyle())
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
        .background {
            // 滚到这一枚时上下各多露出渐隐的长度，图标不落在渐隐里。
            Color.clear
                .padding(.vertical, -Self.fadeLength)
                .id(group)
                .accessibilityHidden(true)
        }
    }

    /// 按方向键移动所指的图标并滚到它：← → 按顺序挪一枚，↑ ↓ 挪到相邻一行里同一列的那枚，那一行没有这一列时取最后一枚；
    /// 到头不动。还没有所指的图标时从所选的图标起。
    /// - Parameters:
    ///   - key: 按下的方向键
    ///   - proxy: 选择区的滚动代理
    private func movePreview(
        with key: KeyEquivalent,
        proxy: ScrollViewProxy
    ) -> KeyPress.Result {
        let rows = Self.rows
        let groups = rows.flatMap(\.self)
        let current = previewed ?? controller.group

        guard
            let index = groups.firstIndex(of: current),
            let row = rows.firstIndex(where: { $0.contains(current) }),
            let column = rows[row].firstIndex(of: current)
        else {
            return .handled
        }

        let target: AppIconGroup? =
            switch key {
            case .leftArrow: index > 0 ? groups[index - 1] : nil
            case .rightArrow: index + 1 < groups.count ? groups[index + 1] : nil
            case .upArrow: row > 0 ? rows[row - 1][min(column, rows[row - 1].count - 1)] : nil
            default: row + 1 < rows.count ? rows[row + 1][min(column, rows[row + 1].count - 1)] : nil
            }

        if let target {
            previewed = target
            proxy.scrollTo(target)
        }

        return .handled
    }
}

// MARK: - AppIconTileStyle

/// 一枚图标的按钮样式：只画图标本身，按下与不可点时都不变样。
private struct AppIconTileStyle: ButtonStyle {
    /// 原样画出按钮的内容。
    /// - Parameter configuration: 按钮的内容与状态
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

// MARK: - AppIconPickerFade

/// 选择区上下两边渐隐的长度：那一边没有滚出去的内容时为 0。
private struct AppIconPickerFade: Equatable {
    /// 上边渐隐的长度。
    var top: CGFloat = 0

    /// 下边渐隐的长度。
    var bottom: CGFloat = 0

    /// 两边都不渐隐。
    init() { }

    /// 按滚动的位置算出两边渐隐的长度：等于那一边滚出去的内容的长度，不超过 length。
    /// - Parameters:
    ///   - geometry: 选择区的滚动位置与内容尺寸
    ///   - length: 渐隐的最大长度
    init(geometry: ScrollGeometry, length: CGFloat) {
        let above = geometry.contentOffset.y + geometry.contentInsets.top
        let below = geometry.contentSize.height + geometry.contentInsets.bottom - geometry.visibleRect.maxY

        top = min(max(above, 0), length)
        bottom = min(max(below, 0), length)
    }
}
