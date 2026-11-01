import AppKit

// MARK: - AboutLibrary

/// 编进 App 的一个第三方库：名称、版本、主页、许可证名称，以及 App 里附带的许可证全文。
struct AboutLibrary: Equatable {
    /// 库的名称。
    let name: String

    /// 编进 App 的版本。
    let version: String

    /// 项目主页。
    let homepage: String

    /// 许可证的名称。
    let licenseName: String

    /// 许可证全文的位置；文件不存在时只列上面几项。
    let licenseURL: URL?

    /// 编进 App 的三个库，版本与 `Package.resolved`、README 的第三方列表一致。
    ///
    /// - Parameters:
    ///   - resources: App 包的 `Contents/Resources`，放着打包时拷进来的 Sparkle 与 swift-subprocess 的许可证。
    ///   - highlightJS: 资源包里 highlight.js 的目录，许可证与脚本放在一起。
    static func bundled(resources: URL?, highlightJS: URL?) -> [Self] {
        [
            Self(
                name: "Sparkle",
                version: "2.10.0",
                homepage: "https://sparkle-project.org",
                licenseName: "MIT License",
                licenseURL: resources?.appending(path: "Sparkle-LICENSE.txt")
            ),
            Self(
                name: "highlight.js",
                version: "11.12.0",
                homepage: "https://highlightjs.org",
                licenseName: "BSD 3-Clause License",
                licenseURL: highlightJS?.appending(path: "LICENSE")
            ),
            Self(
                name: "swift-subprocess",
                version: "1.0.1",
                homepage: "https://github.com/swiftlang/swift-subprocess",
                licenseName: "Apache License 2.0",
                licenseURL: resources?.appending(path: "Subprocess-LICENSE.txt")
            ),
        ]
    }
}

// MARK: - AboutDocument

/// 关于窗口以 sheet 显示的两份文档：Acknowledgements 列出第三方库与各自的许可证，License 是 Spooky 的 GPL-3.0 许可证。
enum AboutDocument {
    /// 许可证文件按固定列宽手动折行；不短于这个字符数的行视为被折断的行，下一行接回它后面。
    private static let wrappedLineLength = 60

    /// App 包里 Spooky 的许可证；`swift run` 没有 App 包时为 nil。
    static var licenseURL: URL? {
        Bundle.main.url(forResource: "LICENSE", withExtension: "txt")
    }

    /// 这个构建里的第三方库：Sparkle 与 swift-subprocess 的许可证在 App 包里，highlight.js 的在资源包里。
    static var libraries: [AboutLibrary] {
        AboutLibrary.bundled(
            resources: Bundle.main.resourceURL,
            highlightJS: Bundle.module.url(forResource: "HighlightJS", withExtension: nil)
        )
    }

    /// Acknowledgements：标题下逐个列出库的名称与版本、主页和许可证名称，后面接许可证全文。
    ///
    /// - Parameter libraries: 要列出的库，按顺序排列。
    static func acknowledgements(_ libraries: [AboutLibrary]) -> NSAttributedString {
        let document = NSMutableAttributedString()
        document.append(paragraph(AppLocalization.text("about.acknowledgements"), font: .systemFont(ofSize: 22, weight: .bold)))

        for library in libraries {
            document.append(paragraph(""))
            document.append(paragraph(library.name + " " + library.version, font: .systemFont(ofSize: 15, weight: .bold)))
            document.append(paragraph(library.homepage, link: URL(string: library.homepage)))
            document.append(paragraph(library.licenseName))

            // 许可证全文与上面几行隔一个空行；文件读不到时只留上面几行
            if let text = library.licenseURL.flatMap({ try? String(contentsOf: $0, encoding: .utf8) }) {
                document.append(paragraph(""))
                document.append(paragraph(reflow(text)))
            }
        }

        return document
    }

    /// License：许可证全文；文件读不到时为 nil。
    ///
    /// - Parameter url: 许可证文件。
    static func license(at url: URL) -> NSAttributedString? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        return paragraph(reflow(text))
    }

    /// 把许可证里手动折断的行接回段落，交给文本视图按 sheet 的宽度折行。
    ///
    /// 空行分段，行首的缩进去掉；一行不短于 ``wrappedLineLength`` 个字符、下一行又不是列表项时，下一行接在它后面。
    /// 版权行、标题与分隔线这些短行，以及列表项，各自成行。
    ///
    /// - Parameter text: 许可证文件的原文。
    static func reflow(_ text: String) -> String {
        var lines: [String] = []
        var continues = false

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if continues, !line.isEmpty, line.prefixMatch(of: /(\d+\.|\(\w+\)|[-*•])\s/) == nil {
                lines[lines.count - 1] += " " + line
            } else {
                lines.append(line)
            }

            // 按原文这一行的长度判断它是不是被折断的，接上去之后的长度不算
            continues = raw.count >= wrappedLineLength
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
    }

    /// 一段 13 pt 的正文或指定字体的标题，以换行结尾；行距 1.5 pt。
    ///
    /// - Parameters:
    ///   - text: 这一段的文字，可以含有换行。
    ///   - font: 字体。
    ///   - link: 整段链接到的地址。
    private static func paragraph(
        _ text: String,
        font: NSFont = .systemFont(ofSize: 13),
        link: URL? = nil
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 1.5

        let paragraph = NSMutableAttributedString(
            string: text + "\n",
            attributes: [.font: font, .foregroundColor: NSColor.textColor, .paragraphStyle: style]
        )

        // 链接只覆盖文字，不带上结尾的换行
        if let link {
            paragraph.addAttribute(.link, value: link, range: NSRange(text.startIndex..., in: text))
        }

        return paragraph
    }
}

// MARK: - AboutDocumentViewController

/// 关于窗口上以 sheet 显示的文档：360 × 460 的白底只读文本，可以选中、查找与滚动；左上角的按钮或 Esc 关闭。
final class AboutDocumentViewController: NSViewController {
    /// sheet 的尺寸。
    static let size = NSSize(width: 360, height: 460)

    /// 显示的文档。
    private let document: NSAttributedString

    /// 建立显示指定文档的 sheet。
    ///
    /// - Parameter document: 要显示的文档。
    init(document: NSAttributedString) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    /// sheet 只由代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    /// 文本铺满整个 sheet，四周留 24 pt；关闭按钮浮在左上角，不随文本滚动。
    override func loadView() {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.scrollerInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)

        if let textView = scrollView.documentView as? NSTextView {
            configure(textView)
        }

        let closeButton = NSButton(
            image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil) ?? NSImage(),
            target: self,
            action: #selector(dismiss(_:) as (Any?) -> Void)
        )
        closeButton.isBordered = false
        closeButton.imageScaling = .scaleProportionallyUpOrDown
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.setAccessibilityLabel(AppLocalization.text("action.close"))

        let root = NSView(frame: NSRect(origin: .zero, size: Self.size))

        // 文档是白底的页面，深色外观下也按浅色外观取色
        root.appearance = NSAppearance(named: .aqua)

        for subview in [scrollView, closeButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            scrollView.widthAnchor.constraint(equalToConstant: Self.size.width),
            scrollView.heightAnchor.constraint(equalToConstant: Self.size.height),

            closeButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            closeButton.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            closeButton.widthAnchor.constraint(equalToConstant: 13),
            closeButton.heightAnchor.constraint(equalToConstant: 13),
        ])

        view = root
    }

    /// Esc 关闭 sheet。
    override func cancelOperation(_: Any?) {
        dismiss(nil)
    }

    /// 只读、可选中与查找的文本，不提供撤销、字体面板与格式栏。
    private func configure(_ textView: NSTextView) {
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.isEditable = false
        textView.allowsUndo = false
        textView.isSelectable = true
        textView.usesFontPanel = false
        textView.usesInspectorBar = false
        textView.usesFindPanel = true
        textView.textStorage?.setAttributedString(document)
    }
}
