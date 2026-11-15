import AppKit
import SpookyKit
import SwiftUI

// MARK: - ConflictVersionSummary

/// 一个版本的摘要：左边 64 × 64 的缩略图，右边从上到下是文件名、改动徽标与时间；版本卡片与结果框共用。
struct ConflictVersionSummary: View {
    /// 文件在仓库内的路径。
    let path: String

    /// 缩略图显示的原文：一侧时一份，两侧合并时两份叠放；删除了文件的一侧为 nil。
    let contents: [Data?]

    /// 改动徽标；为 nil 时不显示。
    let badge: ConflictBadge?

    /// 时间；为 nil 时不显示。
    let date: Date?

    /// 缩略图在左；文件名 13 pt 半粗、放不下时中间截断，徽标在下一行，时间放不下时尾部截断，悬停提示写完整时间。
    var body: some View {
        HStack(spacing: 12) {
            ConflictThumbnail(path: path, contents: contents)

            VStack(alignment: .leading, spacing: 4) {
                Text(RepositorySession.fileName(path))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                badge

                if let date {
                    Text(Self.text(of: date))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(AppLocalization.text("conflict.lastEdited", Self.text(of: date, relative: false)))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
    }

    /// 长日期加时间，如 “October 3, 2026 at 10:00 AM”；相对写法时今天、昨天写成 “Today at 8:04 PM”。
    ///
    /// - Parameters:
    ///   - date: 要写出的时间。
    ///   - relative: 是否用今天、昨天的相对写法。
    static func text(of date: Date, relative: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = relative

        return formatter.string(from: date)
    }
}

// MARK: - ConflictThumbnail

/// 版本摘要左边 64 × 64 的缩略图：图片按比例缩小，文字画成一页开头的几行，其余内容与删除了文件的一侧显示文件类型图标；
/// 两份内容时错开叠放。
private struct ConflictThumbnail: View {
    /// 文件在仓库内的路径，取文件类型图标用。
    let path: String

    /// 每一张缩略图的原文。
    let contents: [Data?]

    /// 一张时占满 64 × 64；两张时各 54 pt，后一张向右下错开 10 pt。
    var body: some View {
        let side: CGFloat = contents.count > 1 ? 54 : 64

        ZStack(alignment: .topLeading) {
            ForEach(Array(contents.enumerated()), id: \.offset) { index, data in
                page(data)
                    .frame(width: side, height: side)
                    .offset(x: CGFloat(index) * 10, y: CGFloat(index) * 10)
            }
        }
        .frame(width: 64, height: 64, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    /// 一张缩略图。
    @ViewBuilder
    private func page(_ data: Data?) -> some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else if let data, !data.contains(0), let text = String(data: data.prefix(2048), encoding: .utf8) {
            // 只画开头的几行：字号很小，只为看出内容的轮廓
            Text(text)
                .font(.system(size: 4, design: .monospaced))
                .lineLimit(14)
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color(nsColor: .separatorColor)))
        } else {
            Image(nsImage: WorkingCopyFileHeader.icon(path: path, isFolder: false))
                .resizable()
                .scaledToFit()
        }
    }
}

// MARK: - ConflictBadge

/// 版本的改动类型徽标：实心色块配白色的大写短词，按改动类型着色。
struct ConflictBadge: View {
    /// 合并两侧的徽标。
    static let merge = Self(key: "conflict.change.merge", color: .yellow)

    /// 手动编辑或合并工具得到的结果的徽标。
    static let edited = Self(key: "conflict.change.edited", color: .yellow)

    /// 徽标文字的资源键。
    let key: String

    /// 徽标底色。
    let color: Color

    /// 圆角色块里的小号粗体白字。
    var body: some View {
        Text(AppLocalization.text(key))
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color, in: RoundedRectangle(cornerRadius: 3))
            .fixedSize()
    }

    /// 按改动取文字与颜色。
    init(change: ConflictChange) {
        switch change {
        case .added: self.init(key: "conflict.change.added", color: .green)
        case .modified: self.init(key: "conflict.change.modified", color: .blue)
        case .deleted: self.init(key: "conflict.change.deleted", color: .red)
        }
    }

    /// 指定文字与颜色。
    private init(key: String, color: Color) {
        self.key = key
        self.color = color
    }
}
