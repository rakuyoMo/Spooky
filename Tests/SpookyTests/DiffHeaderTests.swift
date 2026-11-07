import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - DiffHeaderTests

/// 块头测试挂实际正文与背景，不创建窗口或接管桌面滚动。
@MainActor
struct DiffHeaderTests {
    /// 三块实际文本足够覆盖第二块被下一块推挤的区间。
    struct Host: View {
        /// 滚动方式同时交给栈和各块。
        let presentation: DiffPresentation

        /// 测试的真实块模型。
        let hunks: [DiffHunk]

        /// 建立三个不同 ID 的块，避免只按 ID 为零判断首块。
        init(presentation: DiffPresentation) throws {
            self.presentation = presentation
            hunks = try [7, 9, 12].map { try DiffHeaderTests.hunk(id: $0) }
        }

        /// 与产品相同的平铺分节，每块嵌一个 AppKit 文本区。
        var body: some View {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: presentation == .standalone ? [.sectionHeaders] : []) {
                    Color.clear.frame(height: 56)
                    ForEach(hunks) { hunk in
                        DiffHunkView(
                            hunk: hunk,
                            style: TextStyle(theme: TextTheme.builtin[0], tabWidth: 4, showsInvisibles: false),
                            staged: false,
                            enabled: false,
                            readOnly: true,
                            presentation: presentation,
                            hasPrecedingHunk: hunk.id != hunks.first?.id
                        ) { _, _ in }
                    }
                    Color.clear.frame(height: 500)
                }
            }
        }
    }

    /// 原生字体和系统颜色使用已初始化的 AppKit。
    init() { _ = NSApplication.shared }

    /// 所有边线都落在固定高度内，首块和浮动块共用仅底线的背景。
    @Test("块头边线不增加高度", arguments: [false, true])
    func borders(top: Bool) {
        let view = DiffHeaderBackgroundView(frame: NSRect(x: 0, y: 0, width: 400, height: 32))
        view.showsTopBorder = top
        #expect(view.isOpaque)
        #expect(view.hitTest(.zero) == nil)
        #expect(view.borders.count == (top ? 2 : 1))
        #expect(view.borders.last == NSRect(x: 0, y: 31, width: 400, height: 1))
        #expect(view.borders.allSatisfy { view.bounds.contains($0) && $0.height == 1 })
    }

    /// 正文自然位置进入负值才浮动，后块推挤时也不恢复顶线；内嵌模式始终随内容滚动。
    @Test("实际块头吸顶与回滚", arguments: [false, true])
    func pinning(standalone: Bool) async throws {
        let root = try Host(presentation: standalone ? .standalone : .embedded)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 600, height: 500)
        await settle(host)
        let scroll = try #require(descendants(NSScrollView.self, in: host).first)
        let initialHeaders = descendants(DiffHeaderBackgroundView.self, in: host).sorted {
            $0.convert($0.bounds, to: scroll.contentView).minY < $1.convert($1.bounds, to: scroll.contentView).minY
        }
        let first = try #require(initialHeaders.first)
        let firstY = first.convert(first.bounds, to: scroll.documentView).minY
        #expect(!first.showsTopBorder)
        #expect(first.bounds.height == 32)

        for offset in [firstY, firstY + 1, firstY + 100, 0] {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: offset))
            scroll.reflectScrolledClipView(scroll.contentView)
            await settle(host)
            let rendered = first.convert(first.bounds, to: scroll.documentView).minY - offset
            #expect(abs(rendered - (standalone ? max(0, firstY - offset) : firstY - offset)) < 0.01)
            #expect(!first.showsTopBorder)
        }

        // 第二块初始有顶线，吸顶及后块推挤时去掉，滚回后恢复。
        let headers = descendants(DiffHeaderBackgroundView.self, in: host).sorted {
            $0.convert($0.bounds, to: scroll.documentView).minY < $1.convert($1.bounds, to: scroll.documentView).minY
        }
        let second = try #require(headers.dropFirst().first)
        let secondY = second.convert(second.bounds, to: scroll.documentView).minY
        #expect(second.showsTopBorder)
        let body = try #require(descendants(DiffHunkTextContainer.self, in: host).first)
        let span = body.bounds.height + 32

        for offset in [secondY, secondY + 1, secondY + span - 10, 0] {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: offset))
            scroll.reflectScrolledClipView(scroll.contentView)
            await settle(host)
            #expect(second.showsTopBorder == (!standalone || offset <= secondY))
        }
        #expect(host.window == nil)
    }

    /// 预览不创建块头或边线，非零 ID 不影响调用方传入的首块规则。
    @Test("预览隐藏块头", arguments: [false, true])
    func preview(hidden: Bool) async throws {
        let hunk = try Self.hunk(id: 9)
        let root = VStack(spacing: 0) {
            DiffHunkView(
                hunk: hunk,
                style: TextStyle(theme: TextTheme.builtin[0], tabWidth: 4, showsInvisibles: false),
                staged: false,
                enabled: true,
                showsHeader: !hidden,
                presentation: .standalone,
                hasPrecedingHunk: false
            ) { _, _ in }
        }
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 600, height: 600)
        await settle(host)
        let backgrounds = descendants(DiffHeaderBackgroundView.self, in: host)
        #expect(backgrounds.count == (hidden ? 0 : 1))
        #expect(backgrounds.allSatisfy { !$0.showsTopBorder })
        #expect(descendants(DiffHunkTextContainer.self, in: host).count == 1)
    }

    /// 查询当前宿主树，不读取桌面辅助功能层级。
    func descendants<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        view.subviews.flatMap { [$0 as? T].compactMap(\.self) + descendants(type, in: $0) }
    }

    /// 让 SwiftUI 几何观察和 AppKit 排版完成，不断言经过的时间。
    func settle(_ host: NSView) async {
        for _ in 0 ..< 8 {
            host.layoutSubtreeIfNeeded()
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

// MARK: - Private

extension DiffHeaderTests {
    /// 使用解析后的真实正文，测试仅改变块的当前寻址序号。
    private static func hunk(id: Int) throws -> DiffHunk {
        let lines = (1 ... 15).map { " line \($0)" }.joined(separator: "\n")
        let patch = "diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1,15 +1,15 @@ context\n" + lines + "\n"
        let hunk = try #require(RepositoryDiff(patch: Data(patch.utf8)).files.first?.hunks.first)
        return DiffHunk(id: id, header: hunk.header, oldStart: hunk.oldStart, newStart: hunk.newStart, lines: hunk.lines)
    }
}
