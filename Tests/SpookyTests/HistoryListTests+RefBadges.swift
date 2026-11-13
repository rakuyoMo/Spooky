import AppKit
import Foundation
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - RefBadges

extension HistoryListTests {
    /// 引用标记从开头起放得下的照常显示，从第一个放不下的起折叠成一个 “…”，不是整组换成 “…”；
    /// 最宽 300 pt，只占排出来的宽度：小号行里标题紧跟在标记之后，行再宽也不在中间留空。
    /// 行变窄时标记先于作者取得宽度。
    @Test("引用标记的折叠与宽度")
    func refBadges() throws {
        let short = [
            Self.reference("refs/heads/main"),
            Self.reference("refs/remotes/origin/main"),
        ]

        let long = [
            Self.reference("refs/heads/feature/" + String(repeating: "long-branch-name-", count: 4)),
            Self.reference("refs/remotes/origin/main"),
        ]

        // 宽度足够时全部显示，不比标记宽；连 HEAD 也放不下时只剩 “…”
        let all = try Self.badgesWidth(short, proposal: 1000)
        let ellipsis = try Self.badgesWidth(short, proposal: 20)

        #expect(all < HistoryRefBadges.maxWidth)
        #expect(try Self.badgesWidth(short, proposal: HistoryRefBadges.maxWidth) == all)
        #expect(ellipsis < 20)

        // 差一点放不下时，保留前面放得下的，末尾是 “…”
        let folded = try Self.badgesWidth(short, proposal: all - 1)

        #expect(folded > ellipsis)
        #expect(folded < all)

        // 全部排开超过 300 pt 时，行再宽也只到 300 pt，开头的 HEAD 仍然显示
        let capped = try Self.badgesWidth(long, proposal: 1000)

        #expect(capped > ellipsis)
        #expect(capped <= HistoryRefBadges.maxWidth)

        // 小号行里标题紧跟在标记之后，中间是 4 pt 的间距
        let plain = try Self.subjectStart(references: [], isHead: false)
        let badged = try Self.subjectStart(references: short, isHead: true)

        #expect(abs(badged - plain - (all + 4)) < 1)

        // 300 pt 宽的中号行里，作者、日期与全部标记一起放得下：最后一个标记的名字换了，画出来就不同
        let swapped = [short[0], Self.reference("refs/remotes/origin/niam")]

        let before = try Self.rowImage(references: short, subject: "a", small: false, width: 300)
        let after = try Self.rowImage(references: swapped, subject: "a", small: false, width: 300)

        #expect(before.tiffRepresentation != after.tiffRepresentation)
    }
}

// MARK: - Steps

extension HistoryListTests {
    /// 指向测试提交的引用。
    ///
    /// - Parameter id: 完整引用名。
    private static func reference(_ id: String) -> RepositoryReference {
        RepositoryReference(
            id: id,
            objectID: String(repeating: "d", count: 40),
            objectType: "commit",
            upstream: nil,
            upstreamRemote: nil,
            upstreamBranch: nil,
            symbolicTarget: nil
        )
    }

    /// HEAD 指向这个提交时，引用标记在提议宽度下排出来的宽度。
    ///
    /// - Parameters:
    ///   - references: HEAD 之后的引用。
    ///   - proposal: 行里提议的宽度。
    private static func badgesWidth(_ references: [RepositoryReference], proposal: CGFloat) throws -> CGFloat {
        let renderer = ImageRenderer(
            content: HistoryRefBadges(references: references, isHead: true, selected: false, runner: nil)
        )

        renderer.proposedSize = ProposedViewSize(width: proposal, height: nil)
        renderer.scale = 2

        return CGFloat(try #require(renderer.cgImage).width) / 2
    }

    /// 900 pt 宽的小号行里标题左缘的位置（pt）：同一行换一个标题再画一次，取左起第一列不同的像素。
    ///
    /// - Parameters:
    ///   - references: 指向这个提交的引用。
    ///   - isHead: HEAD 是否指向这个提交。
    private static func subjectStart(references: [RepositoryReference], isHead: Bool) throws -> CGFloat {
        let images = try ["a", "b"].map {
            try rowImage(references: references, isHead: isHead, subject: $0, small: true, width: 900)
        }

        let column = (0 ..< images[0].pixelsWide).first { x in
            (0 ..< images[0].pixelsHigh).contains { y in
                images[0].colorAt(x: x, y: y) != images[1].colorAt(x: x, y: y)
            }
        }

        return CGFloat(try #require(column)) / 2
    }

    /// 按 2 倍像素画出的提交行，不显示提交图。
    ///
    /// - Parameters:
    ///   - references: 指向这个提交的引用。
    ///   - isHead: HEAD 是否指向这个提交。
    ///   - subject: 提交说明。
    ///   - small: 是否是小号行。
    ///   - width: 行宽。
    private static func rowImage(
        references: [RepositoryReference],
        isHead: Bool = true,
        subject: String,
        small: Bool,
        width: CGFloat
    ) throws -> NSBitmapImageRep {
        let row = HistoryCommitRow(
            commit: commit(subject: subject),
            graph: nil,
            references: references,
            isHead: isHead,
            small: small,
            dateFormat: .absolute,
            unpushed: false,
            unpulled: false,
            isParent: false,
            selected: false,
            signatures: CommitSignatureStore(),
            runner: nil
        )

        let renderer = ImageRenderer(content: row.frame(width: width, height: small ? 24 : 46))
        renderer.scale = 2

        return NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
    }

    /// 只有标题不同的测试提交。
    ///
    /// - Parameter subject: 提交说明。
    private static func commit(subject: String) -> HistoryCommit {
        HistoryCommit(
            id: String(repeating: "d", count: 40),
            tree: String(repeating: "e", count: 40),
            parents: [],
            author: "Alice Example",
            authorEmail: "alice@example.invalid",
            authorDate: Date(timeIntervalSince1970: 1_700_000_000),
            committer: "Alice Example",
            committerEmail: "alice@example.invalid",
            commitDate: Date(timeIntervalSince1970: 1_700_000_000),
            message: subject
        )
    }
}
