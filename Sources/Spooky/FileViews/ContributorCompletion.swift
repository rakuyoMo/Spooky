import AppKit
import SpookyKit
import SwiftUI

// MARK: - ContributorSuggestion

/// 文件历史搜索框的一条贡献者建议，选中后整条写进搜索框。
struct ContributorSuggestion: Identifiable, Equatable {
    /// 写进搜索框的文字：“姓名 <邮箱>”，同名有多个邮箱时另有只写姓名的一条。
    let text: String

    /// 姓名，头像按它取首字母。
    let name: String

    /// 邮箱；只写姓名的一条为 nil。
    let email: String?

    /// 搜索框文字即身份。
    var id: String { text }

    /// 按姓名匹配查询，忽略大小写与变音符号，保持贡献者按提交数排列的顺序。
    ///
    /// 同名有多个邮箱时，只写姓名的一条排在这个姓名的第一条之前，选它会匹配全部邮箱。
    static func matches(_ query: String, in contributors: [FileContributor]) -> [Self] {
        #warning("TODO: 补全目前按姓名的子串匹配、保持提交数顺序；是否改为模糊匹配并按相似度排序需实测核实；只影响文件历史搜索框补全的命中与顺序")
        let query = query.trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else {
            return []
        }

        let emailCounts = Dictionary(grouping: contributors, by: \.name).mapValues(\.count)
        var named: Set<String> = []
        var suggestions: [Self] = []

        for contributor in contributors where contributor.name.localizedStandardContains(query) {
            // 同名的第一条之前插入只写姓名的一条
            if emailCounts[contributor.name, default: 0] > 1, named.insert(contributor.name).inserted {
                suggestions.append(Self(text: contributor.name, name: contributor.name, email: nil))
            }

            suggestions.append(Self(
                text: contributor.name + " <" + contributor.email + ">",
                name: contributor.name,
                email: contributor.email
            ))
        }

        return suggestions
    }
}

// MARK: - ContributorCompletion

/// 文件历史搜索框的贡献者补全：按作者或提交人范围筛选时，输入的同时在搜索框下方列出仓库的作者。
///
/// 弹窗是挂在仓库窗口上的无边框子窗口，不抢键盘焦点；按键与提交信息的补全一致：↑ ↓ 选择、↩ 接受、⎋ 关闭。
@MainActor
final class ContributorCompletion: NSObject, NSSearchFieldDelegate {
    /// 弹窗的显示模型。
    @Observable
    final class Model {
        /// 当前建议。
        var items: [ContributorSuggestion] = []

        /// 选中的建议位置。
        var selection = 0

        /// 点击建议时接受。
        var onAccept: (ContributorSuggestion) -> Void = { _ in }
    }

    /// 弹窗的最小宽度，比搜索框窄时取这个宽度。
    private static let minimumWidth = 300.0

    /// 弹窗最大高度，超出时滚动。
    private static let maximumHeight = 600.0

    /// 列表最多保留的建议数。
    private static let limit = 100

    /// 建议与选中位置。
    private let model = Model()

    /// 按需创建的子窗口。
    private var panel: NSPanel? = nil

    /// 当前接管的搜索框。
    private weak var field: NSSearchField? = nil

    /// 提供仓库作者的文件历史。
    private weak var state: FileHistoryState? = nil

    /// 接受建议后把搜索框文字交给会话。
    private var apply: (String) -> Void = { _ in }

    /// 读取贡献者并筛选的任务，输入变化时取消。
    private var task: Task<Void, Never>? = nil

    /// 弹窗是否正在显示。
    private var isVisible: Bool { panel?.isVisible ?? false }

    /// 接管文件历史的搜索框：输入时筛选建议，按键先交给弹窗。
    ///
    /// - Parameters:
    ///   - field: 工具栏里的搜索框，工具栏重建后重新接管。
    ///   - state: 提供当前范围与仓库的作者。
    ///   - apply: 接受建议后写入会话的搜索内容。
    func attach(to field: NSSearchField, state: FileHistoryState, apply: @escaping (String) -> Void) {
        close()
        self.field = field
        self.state = state
        self.apply = apply
        field.delegate = self
    }

    /// 关闭弹窗并清空建议。
    func close() {
        task?.cancel()
        task = nil

        guard let panel else {
            return
        }

        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        model.items = []
    }

    /// 搜索框内容变化后重新筛选；修订版本范围与空输入不显示建议。
    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField, field === self.field else {
            return
        }

        update(field)
    }

    /// 弹窗显示时处理搜索框的按键：↑ ↓ 移动、↩ 接受、⎋ 关闭，删除后重新筛选，其它命令先关闭弹窗再照常执行。
    func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard isVisible, !model.items.isEmpty else {
            return false
        }

        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            model.selection = max(0, model.selection - 1)
            return true

        case #selector(NSResponder.moveDown(_:)):
            model.selection = min(model.items.count - 1, model.selection + 1)
            return true

        case #selector(NSResponder.insertNewline(_:)):
            accept(model.items[model.selection])
            return true

        case #selector(NSResponder.cancelOperation(_:)):
            close()
            return true

        // 删除字符时保留弹窗，内容变化后按新的输入重新筛选
        case #selector(NSResponder.deleteBackward(_:)), #selector(NSResponder.deleteWordBackward(_:)):
            return false

        default:
            close()
            return false
        }
    }

    /// 搜索框失去焦点时关闭弹窗。
    func controlTextDidEndEditing(_: Notification) {
        close()
    }
}

// MARK: - Private

extension ContributorCompletion {
    /// 两个范围都取仓库的作者并筛选；读取期间输入又变了，结果作废。
    private func update(_ field: NSSearchField) {
        task?.cancel()

        let query = field.stringValue

        guard let state, state.scope != .revision, !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            close()
            return
        }

        task = Task { [weak self, weak field] in
            let contributors = (try? await state.authors()) ?? []

            guard let self, let field, !Task.isCancelled, field.stringValue == query else {
                return
            }

            show(ContributorSuggestion.matches(query, in: contributors), below: field)
        }
    }

    /// 显示或更新建议；没有建议时关闭。
    private func show(_ items: [ContributorSuggestion], below field: NSSearchField) {
        guard !items.isEmpty, let window = field.window else {
            close()
            return
        }

        let items = Array(items.prefix(Self.limit))

        if model.items.map(\.id) != items.map(\.id) {
            model.selection = 0
        }

        model.items = items
        model.onAccept = { [weak self] in self?.accept($0) }

        let panel = panel ?? makePanel()
        self.panel = panel
        panel.setFrame(frame(below: field), display: true)

        if panel.parent == nil {
            window.addChildWindow(panel, ordered: .above)
        }

        panel.orderFront(nil)
    }

    /// 把建议写进搜索框并交给会话筛选。
    private func accept(_ suggestion: ContributorSuggestion) {
        close()
        field?.stringValue = suggestion.text
        apply(suggestion.text)
    }

    /// 无边框、不激活的子窗口，内容是菜单材质的圆角背景与建议列表。
    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.minimumWidth, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true

        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true

        let content = ContributorHostingView(rootView: ContributorCompletionList(model: model))
        content.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            content.topAnchor.constraint(equalTo: background.topAnchor),
            content.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])

        panel.contentView = background
        return panel
    }

    /// 弹窗与搜索框右缘对齐、放在它的下方，至少与搜索框同宽；下方空间不够时放到上方。
    private func frame(below field: NSSearchField) -> NSRect {
        let anchor = field.window?.convertToScreen(field.convert(field.bounds, to: nil)) ?? .zero
        let width = max(anchor.width, Self.minimumWidth)
        let height = min(
            CGFloat(model.items.count) * ContributorCompletionList.rowHeight + ContributorCompletionList.padding * 2,
            Self.maximumHeight
        )
        let below = NSRect(x: anchor.maxX - width, y: anchor.minY - height - 4, width: width, height: height)
        let visible = field.window?.screen?.visibleFrame ?? .infinite

        guard below.minY < visible.minY else {
            return below
        }

        return NSRect(x: below.minX, y: anchor.maxY + 4, width: width, height: height)
    }
}

// MARK: - ContributorHostingView

/// 弹窗不成为主窗口，第一次点击也要直接选中建议。
private final class ContributorHostingView: NSHostingView<ContributorCompletionList> {
    /// 接受不激活窗口的首次点击。
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
}

// MARK: - ContributorCompletionList

/// 建议列表：每行 18 pt 的首字母头像与 12 pt 的姓名，邮箱用次要色。
private struct ContributorCompletionList: View {
    /// 每行的高度。
    static let rowHeight: CGFloat = 20

    /// 列表四周的内边距。
    static let padding: CGFloat = 6

    /// 弹窗模型。
    let model: ContributorCompletion.Model

    /// 选中行跟随键盘滚动到可见位置。
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        row(item, selected: index == model.selection)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture { model.onAccept(item) }
                    }
                }
                .padding(Self.padding)
            }
            .onChange(of: model.selection) {
                guard model.items.indices.contains(model.selection) else { return }

                proxy.scrollTo(model.items[model.selection].id)
            }
        }
    }

    /// 一行：头像距左 8 pt，与姓名相隔 4 pt；选中行使用强调色底与白字。
    private func row(_ item: ContributorSuggestion, selected: Bool) -> some View {
        HStack(spacing: 4) {
            InitialsAvatar(name: item.name, size: 18)

            Text(label(item, selected: selected))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .font(.system(size: 12))
        .foregroundStyle(selected ? Color.white : Color.primary)
        .padding(.leading, 8)
        .padding(.trailing, 3)
        .frame(height: Self.rowHeight)
        .background(selected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5))
        .accessibilityElement(children: .combine)
    }

    /// 姓名之后的邮箱用次要色；选中时与姓名一样是白字。
    private func label(_ item: ContributorSuggestion, selected: Bool) -> AttributedString {
        var label = AttributedString(item.name)

        guard let email = item.email else {
            return label
        }

        var detail = AttributedString(" <" + email + ">")
        detail.foregroundColor = selected ? .white : .secondary
        label += detail

        return label
    }
}
