import AppKit
import Testing
import TestSupport

@testable import Spooky

// MARK: - AboutTests

/// 关于窗口：固定尺寸的面板只建一个；图标随换组更新；说明在全部语言下与图标底板的顶边对齐；
/// Acknowledgements 按顺序列出三个库并接上各自的许可证；许可证的折行接回段落；文档 sheet 按 Esc 关闭。
@MainActor
struct AboutTests {
    /// 面板内容 470 × 277、只能关闭，标题栏透明且不显示标题；Release Notes 与 Help 菜单是同一个动作；关掉后再打开仍是同一个窗口；
    /// 文档 sheet 360 × 460，文本只读、可以选中，在关于窗口上打开后按 Esc 关闭。
    @Test("关于窗口与文档 sheet")
    func panel() async throws {
        AboutWindowController.show()

        let window = try #require(AboutWindowController.shared?.window)
        defer { window.close() }

        #expect(window.contentRect(forFrameRect: window.frame).size == AboutWindowController.size)
        #expect(window.styleMask == [.titled, .closable, .fullSizeContentView])
        #expect(window.titlebarAppearsTransparent)
        #expect(window.titleVisibility == .hidden)
        #expect(!window.isMovableByWindowBackground)

        let releaseNotes = try #require(Self.buttons(in: window.contentView).first {
            $0.title == AppLocalization.text("help.releaseNotes")
        })

        #expect(releaseNotes.action == #selector(SpookyApplicationController.openReleaseNotes))
        #expect(releaseNotes.target == nil)

        // 再次打开只带到前面；关掉之后再打开沿用同一个窗口
        AboutWindowController.show()

        #expect(AboutWindowController.shared?.window === window)

        window.close()
        AboutWindowController.show()

        #expect(AboutWindowController.shared?.window === window)
        #expect(window.isVisible)

        // 文档 sheet
        let about = try #require(window.contentViewController)
        let sheet = AboutDocumentViewController(document: NSAttributedString(string: "Document"))

        about.presentAsSheet(sheet)

        #expect(sheet.view.frame.size == AboutDocumentViewController.size)

        let textView = try #require(Self.textView(in: sheet.view))

        #expect(!textView.isEditable)
        #expect(textView.isSelectable)
        #expect(textView.string == "Document")

        sheet.cancelOperation(nil)

        await until { about.presentedViewControllers?.isEmpty ?? true }

        #expect(window.attachedSheet == nil)
    }

    /// 关于窗口显示 `AppIconController` 记下的图标，换组后窗口不用重新打开就跟着换；交还包里的默认图标时是系统给出的包图标。
    @Test("关于窗口的图标随换组更新")
    func iconFollowsAppIcon() async throws {
        let directory = AppIconControllerTests.makeDirectory()

        defer { try? FileManager.default.removeItem(at: directory) }

        let app = try AppIconControllerTests.makeApp(in: directory)
        let resources = app.appending(path: "Contents/Resources", directoryHint: .isDirectory)

        try AppIconControllerTests.addMidnightIcons(to: app)

        // 包里有默认图标的资源时，交还默认图标才取系统给出的包图标
        try FileManager.default.copyItem(
            at: resources.appending(path: AppIconGroup.midnight.iconName(for: .standard) + ".icns"),
            to: resources.appending(path: AppIconGroup.serverGhost.iconName(for: .standard) + ".icns")
        )

        _ = NSApplication.shared

        let controller = try AppIconController(
            defaults: MemoryDefaults(),
            bundle: #require(Bundle(url: app)),
            restartDock: { }
        )

        controller.reload()
        await until { controller.pendingRequests == 0 }

        // 订阅图标变化的是内容控制器；关于窗口由窗口持有它，这里留到测试结束
        let about = AboutViewController(appIconController: controller)
        let icon = try #require(about.view.subviews.lazy.compactMap { $0 as? NSImageView }.first)

        defer { withExtendedLifetime(about) { } }

        // 服务器幽灵：系统给出的包图标
        let defaultIcon = try #require(controller.applicationIcon)

        #expect(icon.image === defaultIcon)

        // 换到午夜：窗口不用重新打开，图标换成午夜的一版
        try await controller.select(.midnight)
        await until { icon.image === controller.applicationIcon }

        let midnightIcon = icon.image

        #expect(midnightIcon !== defaultIcon)

        // 换回服务器幽灵：图标又换成系统给出的包图标
        try await controller.select(.serverGhost)
        await until { icon.image === controller.applicationIcon }

        #expect(icon.image !== midnightIcon)
    }

    /// 全部支持语言的说明换上之后：说明第一行大写字母的顶边与图标底板的顶边对齐，与版权之间至少 20；
    /// 两个按钮与 Release Notes 基线对齐，版权在按钮上方 20，位置不随说明的长短变化。
    @Test("关于窗口的说明在全部语言下与图标底板的顶边对齐")
    func creditsLayout() throws {
        // 关于窗口的内容读 App 的代理与图标
        _ = NSApplication.shared

        let content = AboutViewController().view
        content.layoutSubtreeIfNeeded()

        let texts = Self.textFields(in: content)
        let buttons = Self.buttons(in: content)

        let icon = try #require(content.subviews.first { $0 is NSImageView })
        let credits = try #require(texts.first { $0.stringValue == AppLocalization.text("about.credits") })
        let copyright = try #require(texts.first { $0.textColor == .secondaryLabelColor })

        let releaseNotes = try #require(buttons.first { $0.title == AppLocalization.text("help.releaseNotes") })
        let acknowledgements = try #require(buttons.first { $0.title == AppLocalization.text("about.acknowledgements") })

        var copyrightFrames: [NSRect] = []

        for language in AppLocalization.languages {
            let url = try #require(AppLocalization.bundle.url(forResource: language, withExtension: "lproj"))
            let bundle = try #require(Bundle(url: url))

            credits.stringValue = bundle.localizedString(forKey: "about.credits", value: nil, table: nil)
            content.layoutSubtreeIfNeeded()

            // 说明从上往下排：第一行大写字母的顶边与图标底板的顶边平齐，下面与版权至少隔 20
            let capTop = Self.baseline(of: credits) + (credits.font?.capHeight ?? 0)
            let plateTop = icon.frame.maxY - icon.frame.height * AppIconGroup.plateInset

            #expect(abs(capTop - plateTop) < 1, "\(language)")
            #expect(credits.frame.minY - copyright.frame.maxY >= 20, "\(language)")

            // 版权与按钮从下往上排：按钮与 Release Notes 基线对齐，版权在按钮上方 20
            #expect(Self.baseline(of: acknowledgements) == Self.baseline(of: releaseNotes), "\(language)")
            #expect(copyright.frame.minY - acknowledgements.frame.maxY == 20, "\(language)")

            copyrightFrames.append(copyright.frame)
        }

        #expect(copyrightFrames.allSatisfy { $0 == copyrightFrames.first })
    }

    /// 许可证文件都在时，三个库按顺序出现，每个库的名称与版本、主页、许可证名称后面接着它的许可证全文，主页可以点开；
    /// 许可证文件不在时（`swift run` 没有 App 包），每个库只列名称与版本、主页与许可证名称。
    @Test("Acknowledgements 接上各库的许可证")
    func acknowledgements() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-about-" + UUID().uuidString)
        let highlightJS = directory.appending(path: "HighlightJS")

        try FileManager.default.createDirectory(at: highlightJS, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data("Sparkle license text".utf8).write(to: directory.appending(path: "Sparkle-LICENSE.txt"))
        try Data("highlight.js license text".utf8).write(to: highlightJS.appending(path: "LICENSE"))
        try Data("Subprocess license text".utf8).write(to: directory.appending(path: "Subprocess-LICENSE.txt"))

        let document = AboutDocument.acknowledgements(
            AboutLibrary.bundled(resources: directory, highlightJS: highlightJS)
        )

        let text = document.string

        let order = try [
            "Sparkle 2.10.0\nhttps://sparkle-project.org\nMIT License\n\nSparkle license text\n",
            "highlight.js 11.12.0\nhttps://highlightjs.org\nBSD 3-Clause License\n\nhighlight.js license text\n",
            "swift-subprocess 1.0.1\nhttps://github.com/swiftlang/swift-subprocess\nApache License 2.0\n\n"
                + "Subprocess license text\n",
        ].map { try #require(text.range(of: $0)).lowerBound }

        #expect(text.hasPrefix(AppLocalization.text("about.acknowledgements") + "\n"))
        #expect(order == order.sorted())

        let homepage = try #require(text.range(of: "https://highlightjs.org"))
        let link = document.attribute(.link, at: NSRange(homepage, in: text).location, effectiveRange: nil) as? URL

        #expect(link == URL(string: "https://highlightjs.org"))

        // 缺少许可证文件
        let missing = directory.appending(path: "missing")
        let bare = AboutDocument.acknowledgements(AboutLibrary.bundled(resources: missing, highlightJS: nil))

        #expect(bare.string == """
            \(AppLocalization.text("about.acknowledgements"))

            Sparkle 2.10.0
            https://sparkle-project.org
            MIT License

            highlight.js 11.12.0
            https://highlightjs.org
            BSD 3-Clause License

            swift-subprocess 1.0.1
            https://github.com/swiftlang/swift-subprocess
            Apache License 2.0

            """)
    }

    /// 手动折断的长行接回段落，缩进去掉；标题、版权行这些短行与列表项各自成行，空行仍然分段；
    /// License 显示重排后的许可证全文，文件读不到时没有文档。
    @Test("许可证的折行接回段落")
    func reflow() throws {
        let text = """
                                GNU GENERAL PUBLIC LICENSE
                               Version 3, 29 June 2007

            Copyright (c) 2006 Example Author.
            All rights reserved.

            Redistribution and use in source and binary forms, with or without
            modification, are permitted provided that the following conditions
            are met:
            1. Redistributions of source code must retain the above copyright
               notice, this list of conditions and the following disclaimer.
            2. Redistributions in binary form must reproduce the above copyright
               notice, this list of conditions and the following disclaimer.

            """

        #expect(AboutDocument.reflow(text) == """
            GNU GENERAL PUBLIC LICENSE
            Version 3, 29 June 2007

            Copyright (c) 2006 Example Author.
            All rights reserved.

            Redistribution and use in source and binary forms, with or without \
            modification, are permitted provided that the following conditions are met:
            1. Redistributions of source code must retain the above copyright \
            notice, this list of conditions and the following disclaimer.
            2. Redistributions in binary form must reproduce the above copyright \
            notice, this list of conditions and the following disclaimer.
            """)

        // License 的文档
        let file = FileManager.default.temporaryDirectory
            .appending(path: "spooky-license-" + UUID().uuidString + ".txt")

        try Data("GNU GENERAL PUBLIC LICENSE\n   Version 3\n".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(AboutDocument.license(at: file)?.string == "GNU GENERAL PUBLIC LICENSE\nVersion 3\n")
        #expect(AboutDocument.license(at: file.appending(path: "missing")) == nil)
    }
}

// MARK: - Helpers

extension AboutTests {
    /// 视图层级里的全部按钮。
    private static func buttons(in view: NSView?) -> [NSButton] {
        guard let view else {
            return []
        }

        return (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
    }

    /// 视图层级里的全部文本框。
    private static func textFields(in view: NSView) -> [NSTextField] {
        (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap { textFields(in: $0) }
    }

    /// 控件第一行文字的基线在父视图里的纵坐标；基线从对齐矩形的顶边量起。
    private static func baseline(of view: NSView) -> CGFloat {
        view.alignmentRect(forFrame: view.frame).maxY - view.firstBaselineOffsetFromTop
    }

    /// 视图层级里的第一个文本视图。
    private static func textView(in view: NSView) -> NSTextView? {
        (view as? NSTextView) ?? view.subviews.lazy.compactMap { textView(in: $0) }.first
    }
}
