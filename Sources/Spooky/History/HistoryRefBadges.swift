import SpookyKit
import SwiftUI

// MARK: - HistoryRefBadges

/// 提交行里的引用标记：HEAD 指向这个提交时最前面是一个蓝色的 HEAD，其后是指向它的各个引用，排成一行，默认最宽 300 pt。
///
/// 从开头起放得下的标记照常显示，从第一个放不下的起折叠成一个 “…”；只占排出来的宽度，不在行里留空。
struct HistoryRefBadges: View {
    /// 提交行里一行标记的默认最大宽度。
    static let defaultMaxWidth: CGFloat = 300

    /// 指向这个提交的完整引用。
    let references: [RepositoryReference]

    /// HEAD 是否指向这个提交。
    let isHead: Bool

    /// 选中行里的标记一律用选中配色。
    let selected: Bool

    /// 校验标签签名用的执行器。
    let runner: GitRunner?

    /// 一行标记的最大宽度：提交行 300 pt，详情头部的 Refs 行 100 pt。
    var maxWidth = Self.defaultMaxWidth

    /// 标记的个数，HEAD 也算一个。
    private var count: Int {
        (isHead ? 1 : 0) + references.count
    }

    /// 从显示全部标记起，每次少显示一个、末尾补 “…”，取第一种放得下的。
    var body: some View {
        RefBadgeRowWidth(limit: maxWidth) {
            ViewThatFits(in: .horizontal) {
                ForEach((0 ... count).reversed(), id: \.self) { shown in
                    row(showing: shown)
                }
            }
        }
    }

    /// 前 `shown` 个标记，没有全部显示时以 “…” 结尾；只有标签标记可点，点击显示标签的签名。
    ///
    /// - Parameter shown: 显示的标记个数，HEAD 也算一个。
    private func row(showing shown: Int) -> some View {
        HStack(spacing: 4) {
            if isHead, shown > 0 {
                badge("HEAD", color: "blue")
            }

            ForEach(references.prefix(max(0, shown - (isHead ? 1 : 0)))) { ref in
                if ref.isLocal || ref.isRemote {
                    badge(ref.name, color: ref.isLocal ? "blue" : "gray")
                } else {
                    TagBadgeButton(reference: ref.id, runner: runner) { badge(ref.name, color: "yellow") }
                }
            }

            if shown < count {
                badge("…", color: "gray")
            }
        }
    }

    /// 一个标记：11 pt 文字，左右留 4 pt、上下留 1 pt，4 pt 圆角的底色。
    private func badge(_ title: String, color: String) -> some View {
        Text(title)
            .font(.system(size: 11))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .foregroundStyle(AppPalette.color((selected ? "selected" : color) + "_badge_text_color"))
            .background(
                AppPalette.color((selected ? "selected" : color) + "_badge_background_color"),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }
}

// MARK: - RefBadgeRowWidth

/// 把提议的宽度压到上限以内再交给标记，自身只取标记排出来的尺寸，在行里不比标记宽。
private struct RefBadgeRowWidth: Layout {
    /// 宽度上限。
    let limit: CGFloat

    /// 标记在压过的提议下排出来的尺寸。
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        subviews.first?.sizeThatFits(limited(proposal)) ?? .zero
    }

    /// 标记靠左、纵向居中。
    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        subviews.first?.place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: limited(proposal)
        )
    }

    /// 宽度不超过上限的提议；没有提议宽度时按上限。
    ///
    /// - Parameter proposal: 行里给的提议。
    private func limited(_ proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(width: min(proposal.width ?? limit, limit), height: proposal.height)
    }
}

// MARK: - RepositoryHistoryState

extension RepositoryHistoryState {
    /// 指向这个提交的引用，取自最新的引用快照：HEAD 所在分支在前，其余按完整引用名倒序。
    ///
    /// - Parameter commitID: 提交的完整哈希。
    func decorations(of commitID: String) -> [RepositoryReference] {
        snapshot?.decorations(
            of: commitID,
            headBranch: branch?.head.map { "refs/heads/" + $0 }
        ) ?? []
    }

    /// HEAD 是否指向这个提交。
    ///
    /// - Parameter commitID: 提交的完整哈希。
    func isHead(_ commitID: String) -> Bool {
        branch?.oid == commitID
    }
}
