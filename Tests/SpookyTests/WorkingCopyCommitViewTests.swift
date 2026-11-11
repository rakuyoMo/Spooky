import AppKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky

// MARK: - WorkingCopyCommitViewTests

/// 提交区：标题剩余字数的计数，以及分支栏底边线、标题框与正文框画进材质的位置。
///
/// 剩余字数在信息为空时不占位置，计数按 UTF-16 码元，组合字符与 emoji 不能按字符数代替。
struct WorkingCopyCommitViewTests {
    /// 整条信息为空或关闭计数时不显示，标题为空但正文非空时显示上限；
    /// 去掉首尾空白后按 UTF-16 码元计：emoji 占 2，组合重音单独占 1；超出上限为负数，上限至少为 1。
    @Test("剩余字数的显隐与计数")
    func remainingCharacters() {
        // 空信息与关闭计数时不显示，只有正文时显示上限。
        #expect(remaining("", "") == nil)
        #expect(remaining("", "正文") == 50)
        #expect(remaining("标题", "", isEnabled: false) == nil)
        #expect(remaining("", "正文", isEnabled: false) == nil)

        // 按 UTF-16 码元计数。
        #expect(remaining("  标题  ", "") == 48)
        #expect(remaining(" A😀e\u{301} ", "") == 45)
        #expect(remaining(String(repeating: "x", count: 52), "") == -2)
        #expect(remaining("x", "", limit: 0) == 0)
    }

    /// 线与框画在材质视图里面、允许 vibrancy，系统才会随材质合成它们的颜色；
    /// 框要与输入框重合，位置由 SwiftUI 量出后交给材质；正文框随正文区展开出现、收起移除。
    @Test("分支栏底边线、标题框与正文框画在材质里")
    @MainActor
    func materialDecorations() async throws {
        let session = RepositorySession(loadStatus: { _ in throw CancellationError() })
        let list = WorkingCopyListView(session: session).frame(width: 400, height: 260)
        let hosting = NSHostingView(rootView: list)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 260),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }

        hosting.layoutSubtreeIfNeeded()

        let materials = Self.subviews(HeaderMaterialView.self, in: hosting)
        try #require(materials.count == 2)

        // 分支栏：唯一的装饰是贴住底边、横贯全宽的 1 pt 线
        let branch = materials[0]
        try #require(branch.subviews.count == 1)

        let line = branch.subviews[0]
        let bottom = NSRect(x: 0, y: branch.bounds.height - 1, width: branch.bounds.width, height: 1)
        #expect(line.frame == bottom)
        #expect(line.allowsVibrancy)

        // 提交区：标题框在标题的位置量出后才放进材质，与标题输入框左右对齐、顶边相同，高 29 pt
        let commit = materials[1]
        await until { commit.subviews.count == 1 }

        let subject = try #require(Self.subviews(CommitMessageTextView.self, in: hosting).first)
        let field = commit.subviews[0]
        let fieldFrame = field.convert(field.bounds, to: hosting)
        let subjectFrame = subject.convert(subject.bounds, to: hosting)

        #expect(field.allowsVibrancy)
        #expect(field.frame.height == 29)
        #expect(fieldFrame.minX == subjectFrame.minX)
        #expect(fieldFrame.maxX == subjectFrame.maxX)
        #expect(fieldFrame.minY == subjectFrame.minY)

        // 正文非空时展开：正文框从正文输入区的左上角起、左右对齐，把输入区整个框在里面
        session.commitBody = "正文"
        await until { commit.subviews.count == 2 }

        let body = try #require(Self.subviews(CommitMessageTextView.self, in: hosting).last?.enclosingScrollView)
        let bodyField = commit.subviews[1]
        let bodyFieldFrame = bodyField.convert(bodyField.bounds, to: hosting)
        let bodyFrame = body.convert(body.bounds, to: hosting)

        #expect(bodyField.allowsVibrancy)
        #expect(bodyFieldFrame.minX == bodyFrame.minX)
        #expect(bodyFieldFrame.maxX == bodyFrame.maxX)
        #expect(bodyFieldFrame.minY == bodyFrame.minY)
        #expect(bodyFieldFrame.contains(bodyFrame))

        // 正文清空后收起，材质里只剩标题框
        session.commitBody = ""
        await until { commit.subviews.count == 1 }
    }
}

// MARK: - Helpers

extension WorkingCopyCommitViewTests {
    /// 视图层级里给定类型的全部视图，按深度优先的顺序。
    @MainActor
    private static func subviews<Element: NSView>(_: Element.Type, in root: NSView) -> [Element] {
        root.subviews.flatMap { child in
            [child as? Element].compactMap(\.self) + subviews(Element.self, in: child)
        }
    }

    /// 以默认的 50 字上限计算剩余字数。
    private func remaining(
        _ subject: String,
        _ body: String,
        limit: Int = 50,
        isEnabled: Bool = true
    ) -> Int? {
        WorkingCopyCommitView.remainingCharacters(
            subject: subject,
            body: body,
            limit: limit,
            isEnabled: isEnabled
        )
    }
}
