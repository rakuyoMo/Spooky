import AppKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky

// MARK: - WorkingCopyCommitViewTests

/// 提交区：标题剩余字数的计数，分支栏底边线、标题框与正文框画进材质的位置，以及正文框随动画的淡入淡出。
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
    /// 正文框内的分隔线直接落在材质上、不压在底色上，合成出的颜色才与描边相同。
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

        // 正文非空时展开：外框从正文输入区的左上角起、左右对齐，把输入区整个框在里面
        session.commitBody = "正文"
        await until { commit.subviews.count == 4 }

        let body = try #require(Self.subviews(CommitMessageTextView.self, in: hosting).last?.enclosingScrollView)
        let outline = commit.subviews[1]
        let fill = commit.subviews[2]
        let divider = commit.subviews[3]
        let outlineFrame = outline.convert(outline.bounds, to: hosting)
        let dividerFrame = divider.convert(divider.bounds, to: hosting)
        let bodyFrame = body.convert(body.bounds, to: hosting)
        let vibrant = [outline, fill, divider].allSatisfy(\.allowsVibrancy)

        #expect(vibrant)
        #expect(outlineFrame.minX == bodyFrame.minX)
        #expect(outlineFrame.maxX == bodyFrame.maxX)
        #expect(outlineFrame.minY == bodyFrame.minY)
        #expect(outlineFrame.contains(bodyFrame))

        // 输入区的底停在分隔线上；分隔线紧接输入区下沿、在 24 pt 动作栏上方，左右收在描边以内
        #expect(fill.frame.maxY == divider.frame.minY)
        #expect(dividerFrame.minY == bodyFrame.maxY)
        #expect(divider.frame.height == 1)
        #expect(divider.frame.maxY == outline.frame.maxY - 24)
        #expect(divider.frame.minX == outline.frame.minX + 1)
        #expect(divider.frame.width == outline.frame.width - 2)

        // 正文清空后收起，材质里只剩标题框
        session.commitBody = ""
        await until { commit.subviews.count == 1 }
    }

    /// 正文区展开、收起时内容在淡入淡出，材质里的正文框要跟着同一个动画走：
    /// 新框从透明开始淡入；少了的框淡出，动画结束后才从材质移除，不在动画开始时就消失。
    @Test("材质里的输入框随动画淡入淡出")
    @MainActor
    func materialFieldsFade() {
        let material = HeaderMaterialView()
        let subject = HeaderMaterialField(frame: CGRect(x: 10, y: 10, width: 200, height: 29))

        let body = HeaderMaterialField(
            frame: CGRect(x: 10, y: 49, width: 200, height: 120),
            footerHeight: 25
        )

        material.setFields([subject], animate: nil)

        // 展开：正文框的三块图层一放进材质就是透明的，在动画里变为不透明
        var alphas: (before: [CGFloat], after: [CGFloat]) = ([], [])

        material.setFields([subject, body]) { changes, completion in
            alphas.before = material.subviews.map(\.alphaValue)
            Self.runWithoutDuration(changes)
            alphas.after = material.subviews.map(\.alphaValue)
            completion()
        }

        #expect(alphas.before == [1, 0, 0, 0])
        #expect(alphas.after == [1, 1, 1, 1])

        // 收起：正文框在动画里淡出，动画结束前仍留在材质里，结束后移除
        var finish: (() -> Void)? = nil

        material.setFields([subject]) { changes, completion in
            Self.runWithoutDuration(changes)
            finish = completion
        }

        #expect(material.subviews.map(\.alphaValue) == [1, 0, 0, 0])

        finish?()
        #expect(material.subviews.count == 1)
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

    /// 在时长为 0 的动画组里执行改动，`animator()` 设下的值立即生效。
    @MainActor
    private static func runWithoutDuration(_ changes: () -> Void) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            changes()
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
