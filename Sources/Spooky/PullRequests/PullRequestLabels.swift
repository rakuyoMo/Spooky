import SpookyKit
import SwiftUI

// MARK: - PullRequestLabelChip

/// 一个标签：胶囊里 11 pt 的名称，底色是标签的颜色，文字按底色的明暗取黑或白；提示是标签的说明。
///
/// 托管服务没有给出颜色时，底色是中性的灰，文字是正文色。可以删除的标签在名称后面多一个叉号。
struct PullRequestLabelChip: View {
    /// 显示的标签。
    let label: PullRequestLabel

    /// 点叉号时删除这个标签；不能删除的标签为 nil，没有叉号。
    var remove: (() -> Void)? = nil

    /// 名称左右各留 6、上下各留 1，放不下时截断；胶囊描一圈细边，底色与背景相近时也看得出形状。
    var body: some View {
        HStack(spacing: 3) {
            Text(label.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .help(label.description)

            if let remove {
                let title = AppLocalization.text("pullRequests.removeLabel.title", label.name)

                Button(action: remove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .help(title)
                .accessibilityLabel(title)
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(Capsule().fill(background))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
    }

    /// 底色上的文字用深色：底色的相对亮度不低于 0.453。
    ///
    /// - Parameter color: 6 位十六进制的底色，不带 “#”。
    static func usesDarkText(on color: String) -> Bool {
        let rgb = UInt32(color, radix: 16) ?? 0
        let red = Double((rgb >> 16) & 255) / 255
        let green = Double((rgb >> 8) & 255) / 255
        let blue = Double(rgb & 255) / 255

        return 0.2126 * red + 0.7152 * green + 0.0722 * blue >= 0.453
    }
}

// MARK: - Colors

extension PullRequestLabelChip {
    /// 底色。
    private var background: AnyShapeStyle {
        guard let color = label.color else {
            return AnyShapeStyle(.quaternary)
        }

        return AnyShapeStyle(PaletteColor(hex: "#" + color, alpha: 1).color)
    }

    /// 文字的颜色。
    private var foreground: Color {
        guard let color = label.color else {
            return .primary
        }

        return Self.usesDarkText(on: color) ? .black : .white
    }
}

// MARK: - PullRequestLabelsRow

/// 讨论里头部下面的一行标签：三级色的 “Labels” 标签，后 8 是换行排开的各个标签；距右 20，下留 8。
///
/// 可以增删标签时，每个标签带叉号，最后是打开标签选择的添加按钮；正在增删或重新读取详情时都不可用。
struct PullRequestLabelsRow: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 显示的请求。
    let request: PullRequest

    /// 标签选择是否打开。
    @State
    private var picking = false

    /// 标签一行放不下时换行，行高随行数变化。
    var body: some View {
        let state = session.pullRequests
        let canEdit = session.canEditLabels

        HStack(alignment: .top, spacing: 8) {
            Text(AppLocalization.text("pullRequests.header.labels"))
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .fixedSize()

            PullRequestLabelFlow {
                ForEach(request.labels, id: \.name) { label in
                    PullRequestLabelChip(
                        label: label,
                        remove: canEdit ? { session.removeLabel(label.name, from: request) } : nil
                    )
                }

                if canEdit {
                    addButton
                }
            }
            .disabled(state.isEditingLabels || state.isLoadingDetail)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// 与标签同高的添加按钮：加号与 “Add”，点开标签选择。
    private var addButton: some View {
        Button {
            picking = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))

                Text(AppLocalization.text("pullRequests.labels.add"))
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $picking, arrowEdge: .bottom) {
            PullRequestLabelPicker(session: session, request: request) { picking = false }
        }
    }
}

// MARK: - PullRequestLabelFlow

/// 标签从左到右排，一行放不下时换到下一行；标签之间与行之间都相隔 4。
///
/// 限了行数时只占这几行的高度，排不下的标签落在下面；调用处裁掉超出的部分，看得见的标签都是完整的。
struct PullRequestLabelFlow: Layout {
    /// 标签之间与行之间的间距。
    private static let spacing: CGFloat = 4

    /// 最多排几行；为 nil 时不限。
    var lineLimit: Int? = nil

    /// 宽度取给出的宽度，高度是各行的高度加行间距，限了行数时只算这几行；没有给出宽度时排成一行。
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let placements = placements(of: subviews, in: width)
        let visible = placements.filter { $0.row < lineLimit ?? .max }.map(\.frame)

        return CGSize(
            width: width.isFinite ? width : visible.map(\.maxX).max() ?? 0,
            height: visible.map(\.maxY).max() ?? 0
        )
    }

    /// 按算出的位置摆放各个标签。
    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        for (subview, placement) in zip(subviews, placements(of: subviews, in: bounds.width)) {
            subview.place(
                at: CGPoint(x: bounds.minX + placement.frame.minX, y: bounds.minY + placement.frame.minY),
                proposal: ProposedViewSize(placement.frame.size)
            )
        }
    }

    /// 各个标签在给定宽度里的位置与所在的行；比一行还宽的标签占满一行，名称在里面截断。
    private func placements(of subviews: Subviews, in width: CGFloat) -> [(frame: CGRect, row: Int)] {
        var placements: [(frame: CGRect, row: Int)] = []
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        var row = 0

        for subview in subviews {
            let ideal = subview.sizeThatFits(.unspecified)
            let size = CGSize(width: min(ideal.width, width), height: ideal.height)

            // 这一行已有标签、再放就超出宽度时换行
            if origin.x > 0, origin.x + size.width > width {
                origin = CGPoint(x: 0, y: origin.y + rowHeight + Self.spacing)
                rowHeight = 0
                row += 1
            }

            placements.append((CGRect(origin: origin, size: size), row))
            origin.x += size.width + Self.spacing
            rowHeight = max(rowHeight, size.height)
        }

        return placements
    }
}
