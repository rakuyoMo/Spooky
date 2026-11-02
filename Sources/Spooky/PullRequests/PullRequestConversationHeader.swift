import SpookyKit
import SwiftUI

// MARK: - PullRequestConversationHeader

/// 讨论的头部，高 98：标题与编号、状态徽标与合并说明、指派人，右侧是作者头像。
///
/// 位置都从单元格的左缘算；左边三行与作者头像相距 8，头像距右 20。
struct PullRequestConversationHeader: View {
    /// 显示的请求。
    let request: PullRequest

    /// 讨论读完的提交数；还没读完、需要获取或比较没打开时为 nil。
    let commitCount: Int?

    /// 标题一行上 8，徽标一行在标题下 5，指派人一行下 8；作者头像 82 × 82，上 8。
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                title

                HStack(spacing: 4) {
                    PullRequestStateBadge(request: request)

                    Text(Self.info(of: request, commitCount: commitCount))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 5)

                Spacer(minLength: 0)

                assignees
            }
            .padding(.vertical, 8)

            HostingUserAvatar(user: request.author, size: 82)
                .padding(.top, 8)
        }
        .padding(.trailing, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 合并说明：作者、提交数、目标分支与源分支四段用 13 pt 粗体；提交数未知时省掉这一段。
    ///
    /// 各段按格式串里的参数位置插入，再按插入的范围加粗，不经 Markdown 解析：分支名里的符号原样显示。
    ///
    /// - Parameters:
    ///   - request: 显示的请求。
    ///   - commitCount: 讨论读完的提交数。
    static func info(of request: PullRequest, commitCount: Int?) -> AttributedString {
        let author = request.author.username
        let target = request.target.branch
        let source = PullRequestText.source(of: request)

        guard let commitCount else {
            return emphasized(AppLocalization.format("pullRequests.header.direction"), [author, target, source])
        }

        let commits =
            commitCount == 1
                ? AppLocalization.text("pullRequests.header.commits.one")
                : AppLocalization.text("pullRequests.header.commits", commitCount)

        return emphasized(AppLocalization.format("pullRequests.header.info"), [author, commits, target, source])
    }
}

// MARK: - Layout

extension PullRequestConversationHeader {
    /// 20 pt 的标题与三级色的编号，基线对齐、相距 4；放不下时先截断编号。
    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(request.title)
                .foregroundStyle(.primary)
                .layoutPriority(1)

            Text(request.id.reference)
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 20))
        .lineLimit(1)
        .truncationMode(.tail)
        .textSelection(.enabled)
        .frame(height: 24)
    }

    /// 三级色的 “Assignees” 标签，后 8 是一排 20 × 20 的指派人头像，间距 2；没有指派人时只有标签，排不下的部分裁掉。
    private var assignees: some View {
        HStack(spacing: 8) {
            Text(AppLocalization.text("pullRequests.header.assignees"))
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .fixedSize()

            HStack(spacing: 2) {
                ForEach(request.assignees, id: \.username) {
                    HostingUserAvatar(user: $0, size: 20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 20)
        .clipped()
    }

    /// 按格式串里 `%n$@` 的位置插入参数，插入的部分用 13 pt 粗体。
    private static func emphasized(_ format: String, _ arguments: [String]) -> AttributedString {
        var result = AttributedString()
        var rest = format[...]

        while let match = rest.firstMatch(of: /%(\d+)\$@/) {
            result += AttributedString(String(rest[..<match.range.lowerBound]))

            // 位置越界的占位不插入文字
            if let position = Int(match.output.1), arguments.indices.contains(position - 1) {
                var argument = AttributedString(arguments[position - 1])
                argument.font = .system(size: 13, weight: .bold)
                result += argument
            }

            rest = rest[match.range.upperBound...]
        }

        result += AttributedString(String(rest))
        return result
    }
}

// MARK: - PullRequestStateBadge

/// 状态徽标：打开、草稿、关闭或已合并，按状态取底色，白字。
struct PullRequestStateBadge: View {
    /// 显示的请求。
    let request: PullRequest

    /// 11 pt 的状态名，左右各留 6、上下各留 1；底色是圆角 4 的矩形，向内收 0.5。
    var body: some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 4).inset(by: 0.5).fill(color))
            .fixedSize()
    }

    /// 状态名。
    private var title: String {
        switch request.state {
        case .open: AppLocalization.text(request.isDraft ? "pullRequests.state.draft" : "pullRequests.state.open")
        case .closed: AppLocalization.text("pullRequests.state.closed")
        case .merged: AppLocalization.text("pullRequests.state.merged")
        }
    }

    /// 底色。
    private var color: Color {
        switch request.state {
        case .open: request.isDraft ? .gray : .green
        case .closed: .red
        case .merged: .purple
        }
    }
}
