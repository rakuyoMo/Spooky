import AppKit
import SpookyKit
import SwiftUI

// MARK: - DialogLayout

/// 对话框骨架：自上而下是头部、内容区、错误区、Options 开关与选项区、底栏，段与段之间不留间距，默认宽 480。
/// 底栏的按钮组在这个宽度里放不下时，对话框随之加宽。
///
/// 头部是 64 pt 图标与单行标题、自动折行的说明，服务器仓库在标题下多一行带主机前缀的位置。
/// 头部文字、错误文字与备选底栏的按钮组对齐内容区的输入列，图标挂在头部文字左侧；输入列由 `DialogFormRow` 报上来，
/// 标签长时随之右移，内容区没有输入列时对齐 `DialogMetrics.alignment`。
/// 内容区与选项区的边距由内容自己决定，里面要按输入列定宽或缩进的部分用 `DialogInputColumnReader` 读到它。
///
/// 几种版本由参数组合出来：
/// - 表单版：内容区是表单
/// - 确认版：没有内容区，只有头部与底栏
/// - 提示版：没有取消动作，底栏只有主按钮，↩ 与 ⎋ 都按它
/// - 备选底栏：给了备选按钮时，取消贴按钮组左端，备选按钮与主按钮贴右端
/// - 可以拉大：内容随窗口变宽变高，多出的高度交给选项区里能伸展的部分
struct DialogLayout<Content: View, Options: View>: View {
    /// 对话框标题，也是 VoiceOver 读出的名称。
    let title: String

    /// 标题下方的说明。
    let message: String

    /// 头部图标；为 nil 时是应用图标。
    let icon: NSImage?

    /// 对话框所属的仓库；服务器仓库在标题下写出带主机前缀的位置。
    let repository: RepositoryLocation?

    /// 对话框的宽度。
    let width: CGFloat

    /// 主按钮的标题。
    let submitTitle: String

    /// 取消按钮的标题。
    let cancelTitle: String

    /// 备选按钮的标题与动作；为 nil 时用普通底栏。
    let alternate: (title: String, action: () -> Void)?

    /// 输入校验或加载失败的说明；为 nil 时错误区收起。
    let error: String?

    /// 对话框自己加载数据时的步骤，如 “Loading commits…”；为 nil 时底栏左侧是空的。
    let progress: String?

    /// 内容是否合法。
    let canSubmit: Bool

    /// 是否正在提交：主按钮与取消按钮都不可用。
    let submitting: Bool

    /// 对话框所在的窗口能否拉大；能拉大时内容占满窗口的宽度。
    let resizable: Bool

    /// Options 开关的文字。
    let optionsTitle: String

    /// 取消按钮与 ⎋ 的动作；为 nil 时没有取消按钮，⎋ 按主按钮。
    let cancel: (() -> Void)?

    /// 主按钮的动作。
    let submit: () -> Void

    /// 内容区。
    let content: () -> Content

    /// 选项区；为 nil 时没有 Options 开关。
    let options: (() -> Options)?

    /// 选项区是否展开，只在本次对话框里有效。
    @State
    private var optionsExpanded: Bool

    /// 内容区输入列的左缘；内容区没有输入列时为 nil。
    @State
    private var inputColumn: CGFloat?

    /// 头部、内容区、错误区、Options 与底栏依次排列；错误出现与消失时带动画。
    var body: some View {
        DialogStack(width: width, fillsProposedWidth: resizable) {
            VStack(alignment: .leading, spacing: 0) {
                header

                content()
                    .font(.system(size: 13))
                    .environment(\.dialogInputColumn, alignment)

                if let error {
                    errorRow(error)
                        .transition(.opacity)
                }

                if let options {
                    optionsToggle

                    optionsArea(options)
                }
            }

            footer
        }
        .coordinateSpace(.named(DialogMetrics.coordinateSpace))
        .onPreferenceChange(DialogInputColumnKey.self) { inputColumn = $0 }
        .animation(.easeOut(duration: 0.2), value: error == nil)
    }

    /// 创建对话框；不给内容区时是确认版，不给选项区时没有 Options 开关。
    ///
    /// - Parameters:
    ///   - title: 标题。
    ///   - message: 标题下方的说明。
    ///   - icon: 头部图标；为 nil 时是应用图标。
    ///   - repository: 对话框所属的仓库。
    ///   - width: 对话框的宽度。
    ///   - submitTitle: 主按钮的标题。
    ///   - cancelTitle: 取消按钮的标题。
    ///   - alternate: 备选按钮的标题与动作。
    ///   - error: 输入校验或加载失败的说明。
    ///   - progress: 对话框自己加载数据时的步骤。
    ///   - canSubmit: 内容是否合法。
    ///   - submitting: 是否正在提交。
    ///   - optionsTitle: Options 开关的文字。
    ///   - optionsExpanded: 选项区一开始是否展开。
    ///   - resizable: 对话框所在的窗口能否拉大。
    ///   - cancel: 取消按钮与 ⎋ 的动作；为 nil 时没有取消按钮。
    ///   - submit: 主按钮的动作。
    ///   - content: 内容区。
    ///   - options: 选项区。
    init(
        title: String,
        message: String,
        icon: NSImage? = nil,
        repository: RepositoryLocation? = nil,
        width: CGFloat = 480,
        submitTitle: String,
        cancelTitle: String = AppLocalization.text("action.cancel"),
        alternate: (title: String, action: () -> Void)? = nil,
        error: String? = nil,
        progress: String? = nil,
        canSubmit: Bool = true,
        submitting: Bool = false,
        optionsTitle: String = AppLocalization.text("dialog.options"),
        optionsExpanded: Bool = false,
        resizable: Bool = false,
        cancel: (() -> Void)?,
        submit: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content = { EmptyView() },
        options: (() -> Options)? = (() -> EmptyView)?.none
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.repository = repository
        self.width = width
        self.submitTitle = submitTitle
        self.cancelTitle = cancelTitle
        self.alternate = alternate
        self.error = error
        self.progress = progress
        self.canSubmit = canSubmit
        self.submitting = submitting
        self.resizable = resizable
        self.optionsTitle = optionsTitle
        self.cancel = cancel
        self.submit = submit
        self.content = content
        self.options = options
        _optionsExpanded = State(initialValue: optionsExpanded)
    }
}

// MARK: - Sections

extension DialogLayout {
    /// 头部文字、错误文字与备选底栏按钮组的左缘。
    private var alignment: CGFloat {
        DialogMetrics.textLeading(for: inputColumn)
    }

    /// 图标距顶 20，右侧 16 pt 是标题、服务器仓库的位置与说明；说明距头部底边 12，右边距 20。
    ///
    /// 图标下方不留这 12，头部至少高 84：距顶 20 加上图标的 64。
    private var header: some View {
        HStack(alignment: .top, spacing: DialogMetrics.iconSpacing) {
            Image(nsImage: icon ?? NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)

                // 服务器仓库在标题下写出带主机前缀的位置，本机仓库没有这一行
                if let repository, repository.host != nil {
                    Text(repository.displayPath)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(message)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
        }
        .padding(.leading, alignment - DialogMetrics.iconSpacing - 64)
        .padding(.trailing, 20)
        .padding(.top, 20)
    }

    /// 高 34 的开关行：17 pt 的披露三角距左 20，右侧 4 pt 是文字，点文字也能切换。
    private var optionsToggle: some View {
        Toggle(optionsTitle, isOn: animatedOptionsExpanded)
            .toggleStyle(DialogDisclosureStyle())
            .padding(.leading, 20)
            .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34, alignment: .leading)
    }

    /// 切换选项区时做 0.2 s 的 ease-out 动画；应用级模态窗口里不做动画。
    private var animatedOptionsExpanded: Binding<Bool> {
        Binding(
            get: { optionsExpanded },
            set: { expanded in
                let animation: Animation? = NSApp.modalWindow == nil ? .easeOut(duration: 0.2) : nil

                withAnimation(animation) {
                    optionsExpanded = expanded
                }
            }
        )
    }

    /// 左侧是加载中的步骤，右侧是取消与主按钮；给了备选按钮时换成备选底栏。高 53，按钮距顶 12。
    private var footer: some View {
        HStack(spacing: 8) {
            if alternate == nil, let progress {
                ProgressView()
                    .controlSize(.small)

                Text(progress)
                    .font(.system(size: 13))
            }

            if alternate == nil || cancel == nil {
                Spacer(minLength: 0)
            }

            if let cancel {
                footerButton(cancelTitle, action: cancel)
                    .keyboardShortcut(.cancelAction)
                    .disabled(submitting)
            }

            if let alternate {
                if cancel != nil {
                    Spacer(minLength: 0)
                }

                footerButton(alternate.title, action: alternate.action)
                    .disabled(submitting)
            }

            footerButton(submitTitle, action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit || submitting)
        }
        .padding(.leading, alternate == nil ? 20 : alignment)
        .padding(.trailing, 20)
        .padding(.top, 12)
        .frame(height: 53, alignment: .top)
        .background {
            // 没有取消按钮时 ⎋ 也按主按钮
            if cancel == nil {
                Button(action: submit) {
                    EmptyView()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(!canSubmit || submitting)
                .opacity(0)
                .accessibilityHidden(true)
            }
        }
    }

    /// 选项区的边线：`general_border_color`，带黑色、25% 不透明度、模糊半径 4 的阴影。
    private var optionsBorder: some View {
        Rectangle()
            .fill(AppPalette.color("general_border_color"))
            .frame(height: 1)
            .shadow(color: .black.opacity(0.25), radius: 4)
    }

    /// 黄色警告图标挂在对齐线左侧 4 pt，原因文字从对齐线开始，右边距 20，至少高 51。
    private func errorRow(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.yellow)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            Text(Self.linkingURLs(in: error))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 51, alignment: .topLeading)
                .padding(.top, 1)
        }
        .padding(.leading, alignment - 4 - 18)
        .padding(.trailing, 20)
    }

    /// 选项区上下各留 8 pt；展开时整块填次要背景色，上下各一条带阴影的 1 pt 边线。
    private func optionsArea(_ options: () -> Options) -> some View {
        VStack(spacing: 0) {
            if optionsExpanded {
                options()
                    .font(.system(size: 13))
                    .environment(\.dialogInputColumn, alignment)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.color("general_secondary_background_color"))
                    .overlay(alignment: .top) { optionsBorder }
                    .overlay(alignment: .bottom) { optionsBorder }
            }
        }
        .padding(.vertical, 8)
    }

    /// 最小 70 pt 宽的按钮：文字至少 56 pt，加上按钮自己的边距正好 70；文字长时随之加宽。
    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(minWidth: 56)
        }
        .fixedSize()
    }
}

// MARK: - Helpers

extension DialogLayout {
    /// 文字里的网址写成可点的链接。
    private static func linkingURLs(in text: String) -> AttributedString {
        var attributed = AttributedString(text)

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attributed
        }

        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard
                let url = match.url,
                let range = Range(match.range, in: text),
                let linkRange = Range(range, in: attributed)
            else {
                continue
            }

            attributed[linkRange].link = url
        }

        return attributed
    }
}

// MARK: - DialogDisclosureStyle

/// Options 开关：系统的披露三角加文字，整行都能点。
///
/// 辅助功能里是一个以文字为名称的勾选框，勾上表示展开。
private struct DialogDisclosureStyle: ToggleStyle {
    /// 17 × 17 的披露三角，右侧 4 pt 是 13 pt 的文字。
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                DisclosureTriangle(isExpanded: configuration.isOn)
                    .frame(width: 17, height: 17)

                configuration.label
                    .font(.system(size: 13))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DisclosureTriangle

/// 只用来显示的系统披露三角；点击交给外层的开关。
private struct DisclosureTriangle: NSViewRepresentable {
    /// 是否画成展开的样子。
    let isExpanded: Bool

    /// 不接收点击、不进入辅助功能的披露按钮。
    func makeNSView(context _: Context) -> NSButton {
        let button = PassthroughButton(title: "", target: nil, action: nil)
        button.bezelStyle = .disclosure
        button.setButtonType(.pushOnPushOff)
        button.setAccessibilityElement(false)
        return button
    }

    /// 同步展开状态。
    func updateNSView(_ button: NSButton, context _: Context) {
        button.state = isExpanded ? .on : .off
    }
}

// MARK: - PassthroughButton

/// 不接收点击的按钮，点击落到下面的视图上。
private final class PassthroughButton: NSButton {
    /// 永远不命中。
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}

// MARK: - DialogStack

/// 骨架的两段：上面是头部到选项区，下面是底栏，宽度取指定宽度与底栏理想宽度中较大的一个。
///
/// 按钮文字较长的语言里，底栏的按钮组可能在指定宽度里放不下，对话框随之加宽，上面一段按同一宽度排版；
/// 可以拉大的对话框再占满窗口给的宽度，高度有富余时都交给上面一段。
private struct DialogStack: Layout {
    /// 指定的宽度。
    let width: CGFloat

    /// 是否占满提议的宽度：可以拉大的对话框拉宽后，内容随窗口变宽。
    let fillsProposedWidth: Bool

    /// 宽度取指定宽度与底栏理想宽度中较大的一个，高度是两段之和。
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = resolvedWidth(subviews, proposed: proposal.width)
        let footer = footerHeight(subviews, width: width)

        let body = subviews[0].sizeThatFits(ProposedViewSize(
            width: width,
            height: proposal.height.map { max($0 - footer, 0) }
        ))

        return CGSize(width: width, height: body.height + footer)
    }

    /// 上面一段从顶边开始，底栏紧接在它下面。
    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let width = resolvedWidth(subviews, proposed: bounds.width)
        let footer = footerHeight(subviews, width: width)

        let proposal = ProposedViewSize(width: width, height: max(bounds.height - footer, 0))
        let body = subviews[0].sizeThatFits(proposal)

        subviews[0].place(at: bounds.origin, proposal: proposal)

        subviews[1].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + body.height),
            proposal: ProposedViewSize(width: width, height: footer)
        )
    }

    /// 指定宽度与底栏理想宽度中较大的一个；占满提议的宽度时，提议的宽度更大就取它。
    private func resolvedWidth(_ subviews: Subviews, proposed: CGFloat?) -> CGFloat {
        let fitting = max(width, subviews[1].sizeThatFits(.unspecified).width)

        guard fillsProposedWidth, let proposed, proposed.isFinite else {
            return fitting
        }

        return max(fitting, proposed)
    }

    /// 底栏在这个宽度下的高度。
    private func footerHeight(_ subviews: Subviews, width: CGFloat) -> CGFloat {
        subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
    }
}
