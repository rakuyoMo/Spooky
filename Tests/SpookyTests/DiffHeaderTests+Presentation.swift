import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

extension DiffHeaderTests {
    /// 所有边线都落在固定高度内，首块和浮动块共用仅底线的背景；实际绘制取动态系统色，浅深外观都保持不透明。
    @Test("块头背景的边线与系统底色")
    func background() throws {
        // 边线不增加高度
        for top in [false, true] {
            let view = DiffHeaderBackgroundView(frame: NSRect(x: 0, y: 0, width: 400, height: 32))
            view.showsTopBorder = top
            #expect(view.isOpaque)
            #expect(view.hitTest(.zero) == nil)
            #expect(view.borders.count == (top ? 2 : 1))
            #expect(view.borders.last == NSRect(x: 0, y: 31, width: 400, height: 1))
            #expect(view.borders.allSatisfy { view.bounds.contains($0) && $0.height == 1 })
        }

        // 浅深两种外观的实际绘制
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            try expectSystemBackground(try #require(NSAppearance(named: name)))
        }
    }

    /// 预览不创建块头或边线，非零 ID 不影响调用方传入的首块规则；实际只读入口按每个文件重置首块规则，独立和内嵌模式都不显示写入按钮。
    @Test("预览与只读文件的块头")
    func preview() async throws {
        let hunk = try Self.hunk(id: 9)

        for hidden in [false, true] {
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

        // 两个文件共三块，只有第一个文件的第二块有顶线
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        let source = CommitFileDiffSource(
            runner: fixture.runner,
            commit: try await fixture.head(),
            file: CommitFileChange(path: "a b.txt", originalPath: nil, status: "M", additions: 1, deletions: 1)
        )

        for presentation in [DiffPresentation.standalone, .embedded] {
            let host = try readOnlyHost(source: source, presentation: presentation)
            await settle(host)

            let headers = descendants(DiffHeaderBackgroundView.self, in: host)
            #expect(headers.count == 3)
            #expect(headers.filter(\.showsTopBorder).count == 1)
            #expect(headers.allSatisfy { $0.bounds.height == 32 })
            #expect(descendants(NSButton.self, in: host).isEmpty)
            #expect(host.window == nil)
        }
    }

    /// 在离屏位图上按外观绘制块头背景，中心像素是不透明的控件底色。
    private func expectSystemBackground(_ appearance: NSAppearance) throws {
        let view = DiffHeaderBackgroundView(frame: NSRect(x: 0, y: 0, width: 200, height: 32))

        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 200,
            pixelsHigh: 32,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))

        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))

        appearance.performAsCurrentDrawingAppearance {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            view.draw(view.bounds)
            NSGraphicsContext.restoreGraphicsState()

            let actual = bitmap.colorAt(x: 100, y: 16)?.usingColorSpace(.deviceRGB)
            let expected = NSColor.controlBackgroundColor.usingColorSpace(.deviceRGB)
            #expect(actual?.alphaComponent == 1)

            guard let actual, let expected else {
                Issue.record("无法读取块头系统色")
                return
            }

            #expect(abs(actual.redComponent - expected.redComponent) < 0.01)
            #expect(abs(actual.greenComponent - expected.greenComponent) < 0.01)
            #expect(abs(actual.blueComponent - expected.blueComponent) < 0.01)
        }
    }

    /// 两个文件的只读补丁，第一个文件有两块。
    private func readOnlyHost(source: CommitFileDiffSource, presentation: DiffPresentation) throws -> NSView {
        let first = "diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1 +1 @@\n-old\n+new\n"
        let second = "@@ -20 +20 @@\n-old\n+new\n"
        let patch = Data((first + second + first).utf8)
        let diff = try RepositoryDiff(patch: patch)

        let root = ScrollView {
            ReadOnlyFileDiffView(
                result: CommitDiff(byteCount: patch.count, diff: diff, onlyWhitespaceChanges: false),
                source: source,
                presentation: presentation
            ) { }
        }

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 600, height: 1200)
        return host
    }
}
