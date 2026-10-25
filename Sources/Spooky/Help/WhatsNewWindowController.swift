import AppKit
import SwiftUI

// MARK: - WhatsNewWindowController

/// Help › What's New：本版本的更新说明，按用户的语言显示，没有这种语言时用英文。
///
/// 说明随发布打包进 App 的 `ReleaseNotes` 资源目录；没有说明的构建里菜单项不可用。
@MainActor
final class WhatsNewWindowController: NSWindowController {
    /// 显示说明的窗口，同一时间只有一个。
    private static var shown: WhatsNewWindowController?

    /// App 的对外版本号。
    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// 建立可缩放的窗口，内容是渲染后的说明。
    private init(notes: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.title = AppLocalization.text("whatsNew.title", Self.version)
        window.contentViewController = NSHostingController(rootView: ReleaseNotesView(markdown: notes))
        window.setContentSize(NSSize(width: 520, height: 480))
        window.center()
        super.init(window: window)
    }

    /// 窗口只由代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    /// 本版本的更新说明；这个构建没有打包说明时为 nil。
    static func notes(in bundle: Bundle = .main) -> String? {
        guard let directory = bundle.resourceURL?.appending(path: "ReleaseNotes") else {
            return nil
        }

        let available = AppLocalization.languages.filter {
            FileManager.default.fileExists(atPath: directory.appending(path: $0 + ".md").path)
        }

        guard let language = Bundle.preferredLocalizations(from: available).first else {
            return nil
        }

        return try? String(contentsOf: directory.appending(path: language + ".md"), encoding: .utf8)
    }

    /// 显示更新说明；已经在显示时带到前面。
    static func show() {
        guard let notes = notes() else {
            return
        }

        let controller = shown ?? WhatsNewWindowController(notes: notes)
        shown = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - ReleaseNotesView

/// 更新说明的渲染：`###` 节标题、无序列表与段落，行内的粗体与链接照 Markdown 显示。
struct ReleaseNotesView: View {
    /// 说明里的一块内容。
    enum Block: Equatable {
        /// `###` 节标题。
        case heading(String)

        /// 列表的一项。
        case item(String)

        /// 一段文字。
        case paragraph(String)
    }

    /// 更新说明的 Markdown。
    let markdown: String

    /// 可滚动、可选择文字的说明。
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(Self.blocks(of: markdown).enumerated()), id: \.offset) { _, block in
                    view(for: block)
                }
            }
            .textSelection(.enabled)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 按行拆成节标题、列表项与段落；空行只分隔，不单独成块。
    static func blocks(of markdown: String) -> [Block] {
        markdown.split(whereSeparator: \.isNewline).compactMap { line in
            let text = line.trimmingCharacters(in: .whitespaces)

            if text.hasPrefix("### ") {
                return .heading(String(text.dropFirst(4)))
            }

            if text.hasPrefix("- ") || text.hasPrefix("* ") {
                return .item(String(text.dropFirst(2)))
            }

            return text.isEmpty ? nil : .paragraph(text)
        }
    }

    /// 一块内容的视图。
    @ViewBuilder
    private func view(for block: Block) -> some View {
        switch block {
        case .heading(let text):
            Text(inline(text))
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 8)

        case .item(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "•")
                    .accessibilityHidden(true)

                Text(inline(text))
            }

        case .paragraph(let text):
            Text(inline(text))
        }
    }

    /// 行内的粗体与链接；解析不了时显示原文。
    private func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
