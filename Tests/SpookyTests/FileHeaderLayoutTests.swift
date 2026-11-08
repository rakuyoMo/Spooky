import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

/// 文件头在无窗口宿主中布局，不访问桌面或发送输入。
@MainActor
struct FileHeaderLayoutTests {
    /// 原生字体与分段控件需要初始化 AppKit。
    init() { _ = NSApplication.shared }

    /// 窄栏仍为长名称与单字名称保留中间截断宽度，宽栏动作组按原生宽度显示，比较侧与动作组不重叠。
    @Test("窄文件头保留名称与原生控件")
    func workingCopy() throws {
        let session = RepositorySession()
        defer { session.close() }

        for (width, name) in [(475.0, "目录中的很长文件名.swift"), (475, "a"), (800, "text.txt")] {
            try expectHeader(session: session, width: width, name: name)
        }
    }

    /// 长文案与汉字的动作保留完整标题与启用状态，压缩只改变显示宽度，隐藏时仍保留控件。
    @Test("动作分段接受窄栏并保持原生标题")
    func actions() throws {
        for language in ["de", "zh-Hans"] {
            let url = try #require(AppLocalization.bundle.url(forResource: language, withExtension: "lproj"))
            let bundle = try #require(Bundle(url: url))
            let keys = ["blame.title", "fileHistory.title", "externalTool.action.diffTool"]

            let actions = keys.map { key in
                FileViewAction(title: bundle.localizedString(forKey: key, value: nil, table: nil)) { }
            }

            let control = FileActionSegmentControl(actions: actions, focusChanged: { _ in })
            let intrinsic = control.intrinsicContentSize.width

            for hovering in [false, true] {
                for width in [intrinsic / 2, intrinsic + 100] {
                    try expectActionBar(actions: actions, hovering: hovering, width: width, intrinsic: intrinsic)
                }
            }
        }
    }

    /// 在给定宽度显示工作区文件头，核对名称、动作组与比较侧的位置。
    private func expectHeader(session: RepositorySession, width: Double, name: String) throws {
        let entry = StatusEntry(kind: .tracked, path: "directory/" + name, unstaged: .modified)
        let root = WorkingCopyFileHeader(session: session, path: entry.path, entry: entry, isDirectory: false)
        let host = NSHostingView(rootView: root.frame(width: width))
        host.frame.size = CGSize(width: width, height: 40)
        host.layoutSubtreeIfNeeded()

        let controls = descendants(host).compactMap { $0 as? NSSegmentedControl }
        let actions = try #require(controls.first { $0 is FileActionSegmentControl })
        let sides = try #require(controls.first { !($0 is FileActionSegmentControl) })
        let actionFrame = actions.convert(actions.bounds, to: host)
        let sideFrame = sides.convert(sides.bounds, to: host)
        let text = try #require(descendants(host).first { $0.accessibilityValue() as? String == name })
        let nameFrame = text.convert(text.bounds, to: host)

        // 名称至少保留首尾各一字加省略号
        let shortened = name.count > 2 ? "\(name.prefix(1))…\(name.suffix(1))" : name
        let font = NSFont.boldSystemFont(ofSize: 13)
        let minimum = NSAttributedString(string: shortened, attributes: [.font: font]).size().width
        let visible = NSAttributedString(string: name.count > 2 ? "…" : name, attributes: [.font: font]).size().width

        #expect(host.window == nil)
        #expect(host.bounds.height == 40)
        #expect(nameFrame.minX == CGFloat(52))
        #expect(nameFrame.width >= visible - 1)
        #expect(actionFrame.minX >= nameFrame.minX + minimum + 8 - 1)
        #expect(nameFrame.maxX <= actionFrame.minX - 8)
        #expect(actionFrame.maxX <= sideFrame.minX - 8)
        #expect(sideFrame.maxX <= width - 20)
        #expect(abs(sideFrame.width - sides.intrinsicContentSize.width) <= 1)
        #expect(actionFrame.width > 0)

        if width == 800 {
            #expect(abs(actionFrame.width - actions.intrinsicContentSize.width) <= 1)
        }
    }

    /// 在给定宽度与悬停状态下显示动作组，核对宽度、截断方式与各段标题。
    private func expectActionBar(actions: [FileViewAction], hovering: Bool, width: CGFloat, intrinsic: CGFloat) throws {
        let host = NSHostingView(rootView: FileActionBar(actions: actions, hovering: hovering).frame(width: width))
        host.frame.size = CGSize(width: width, height: 25)
        host.layoutSubtreeIfNeeded()

        let control = try #require(descendants(host).compactMap { $0 as? FileActionSegmentControl }.first)
        let frame = control.convert(control.bounds, to: host)
        let segments = 0 ..< control.segmentCount

        #expect(host.window == nil)
        #expect(abs(frame.width - min(width, intrinsic)) <= 1)
        #expect(frame.minX >= -1 && frame.maxX <= width + 1)
        #expect(control.segmentDistribution == .fillProportionally)
        #expect(control.cell?.lineBreakMode == .byTruncatingMiddle)
        #expect(segments.map { control.label(forSegment: $0) } == actions.map(\.title))
        #expect(segments.allSatisfy { control.isEnabled(forSegment: $0) })
        #expect(segments.allSatisfy { control.width(forSegment: $0) == 0 })
    }

    /// 递归只遍历当前测试拥有的原生视图。
    private func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}
