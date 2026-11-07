import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

extension DiffHeaderTests {
    /// 背景实际绘制取动态系统色，浅深外观都保持不透明。
    @Test("块头绘制使用系统底色", arguments: [NSAppearance.Name.aqua, .darkAqua])
    func background(appearance name: NSAppearance.Name) throws {
        let view = DiffHeaderBackgroundView(frame: NSRect(x: 0, y: 0, width: 200, height: 32))
        let appearance = try #require(NSAppearance(named: name))
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
            if let actual, let expected {
                #expect(abs(actual.redComponent - expected.redComponent) < 0.01)
                #expect(abs(actual.greenComponent - expected.greenComponent) < 0.01)
                #expect(abs(actual.blueComponent - expected.blueComponent) < 0.01)
            } else {
                Issue.record("无法读取块头系统色")
            }
        }
    }

    /// 实际只读入口按每个文件重置首块规则，独立和内嵌模式都不显示写入按钮。
    @Test("只读文件的首块边线与按钮", arguments: [false, true])
    func readOnly(standalone: Bool) async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        let first = "diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1 +1 @@\n-old\n+new\n"
        let second = "@@ -20 +20 @@\n-old\n+new\n"
        let patch = Data((first + second + first).utf8)
        let diff = try RepositoryDiff(patch: patch)
        let source = CommitFileDiffSource(
            runner: fixture.runner,
            commit: try await fixture.head(),
            file: CommitFileChange(path: "a b.txt", originalPath: nil, status: "M", additions: 1, deletions: 1)
        )
        let root = ScrollView {
            ReadOnlyFileDiffView(
                result: CommitDiff(byteCount: patch.count, diff: diff, onlyWhitespaceChanges: false),
                source: source,
                presentation: standalone ? .standalone : .embedded
            ) { }
        }
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 600, height: 1200)
        await settle(host)
        let headers = descendants(DiffHeaderBackgroundView.self, in: host)
        #expect(headers.count == 3)
        #expect(headers.filter(\.showsTopBorder).count == 1)
        #expect(headers.allSatisfy { $0.bounds.height == 32 })
        #expect(descendants(NSButton.self, in: host).isEmpty)
        #expect(host.window == nil)
    }
}
