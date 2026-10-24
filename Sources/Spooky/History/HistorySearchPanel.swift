import AppKit
import SpookyKit
import SwiftUI

// MARK: - HistorySearchPanel

/// 列表头下方的搜索过滤面板。
///
/// 只有一个条件时是一条 30 pt 的说明，写出条件与内容，右侧 − 结束搜索、+ 再加一个条件；
/// 两个以上时每个条件一行 38 pt：种类菜单、输入区与 − / +。
struct HistorySearchPanel: View {
    /// 当前窗口的历史。
    let history: RepositoryHistoryState

    /// 刚加入、需要获得键盘焦点的条件。
    @State
    private var focused: UUID? = nil

    /// 按条件数量显示说明条或条件行，底部一条分隔线。
    var body: some View {
        VStack(spacing: 0) {
            if history.searchConditions.count == 1, let condition = history.searchConditions.first {
                infoBar(condition)
            } else {
                ForEach(history.searchConditions) { condition in
                    HistorySearchConditionRow(
                        history: history,
                        condition: condition,
                        focused: $focused
                    )
                }
            }

            Divider()
        }
        .background(.bar)
    }

    /// 说明条里条件的内容：文字条件是输入的文字，日期条件是关系与日期。
    static func summary(of condition: HistorySearchCondition) -> String {
        guard condition.kind == .date else {
            return condition.text
        }

        let date = condition.date.formatted(date: .abbreviated, time: .omitted)

        guard condition.relation == .range else {
            return condition.relation.title + " " + date
        }

        let end = condition.endDate.formatted(date: .abbreviated, time: .omitted)
        return condition.relation.title + " " + date + " – " + end
    }

    /// 一个条件时的说明条：“种类: '内容'” 与 − / +。
    private func infoBar(_ condition: HistorySearchCondition) -> some View {
        HStack(spacing: 8) {
            Text(AppLocalization.text("history.search.info", condition.kind.title, Self.summary(of: condition)))
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            AddRemoveControl { add in
                if add {
                    focused = history.addSearchCondition()
                } else {
                    history.clearSearch()
                }
            }
            .frame(width: 48, height: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 30)
    }
}

// MARK: - HistorySearchConditionRow

/// 过滤面板里的一个条件：种类菜单、文字输入或日期选择，以及 − / +。
private struct HistorySearchConditionRow: View {
    /// 当前窗口的历史。
    let history: RepositoryHistoryState

    /// 这一行的条件。
    let condition: HistorySearchCondition

    /// 刚加入、需要获得键盘焦点的条件。
    @Binding
    var focused: UUID?

    /// 种类菜单宽 108 pt，放得下最长的 “Commit Hash”；输入区占满中间，− / + 在最右；上下各留 7 pt。
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Picker("", selection: binding(\.kind)) {
                ForEach(HistorySearchCondition.Kind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 108)
            .accessibilityLabel(AppLocalization.text("history.search.kind"))

            // 输入区占满中间的宽度，内容放不下时不把两侧的控件挤出去
            Group {
                if condition.kind == .date {
                    dateInput
                } else {
                    textInput
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AddRemoveControl { add in
                if add {
                    focused = history.addSearchCondition(after: condition.id)
                } else {
                    history.removeSearchCondition(condition.id)
                }
            }
            .frame(width: 48, height: 24)
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
    }

    /// 文字条件的输入框，作者、提交人与文件条件补全。
    private var textInput: some View {
        HistorySearchField(
            text: condition.text,
            placeholder: condition.kind.placeholder,
            focused: focused == condition.id,
            suggestions: { [history, kind = condition.kind] query in
                guard let runner = history.runner, let head = history.branch?.oid else {
                    return []
                }

                return await history.suggestions.suggestions(
                    for: kind,
                    matching: query,
                    runner: runner,
                    head: head
                )
            },
            onChange: { text in
                var updated = condition
                updated.text = text
                history.updateSearchCondition(updated)
            },
            onFocus: { focused = nil }
        )
        .frame(height: 24)
    }

    /// 日期条件：关系菜单、日期，区间时另有 “to” 与结束日；列表窄时逐个换行排列。
    private var dateInput: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                relationPicker
                datePicker(\.date)

                if condition.relation == .range {
                    Text(AppLocalization.text("history.search.to"))
                        .fixedSize()

                    datePicker(\.endDate)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                relationPicker
                datePicker(\.date)

                if condition.relation == .range {
                    HStack(spacing: 8) {
                        Text(AppLocalization.text("history.search.to"))
                            .fixedSize()

                        datePicker(\.endDate)
                    }
                }
            }
        }
    }

    /// 日期关系菜单：之后、之前与区间。
    private var relationPicker: some View {
        Picker("", selection: binding(\.relation)) {
            ForEach(HistorySearchCondition.DateRelation.allCases, id: \.self) { relation in
                Text(relation.title).tag(relation)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    /// 只选年月日的日期框。
    private func datePicker(_ keyPath: WritableKeyPath<HistorySearchCondition, Date>) -> some View {
        DatePicker("", selection: binding(keyPath), displayedComponents: .date)
            .labelsHidden()
            .fixedSize()
    }

    /// 改动条件的一个属性后交给历史重读。
    private func binding<Value>(_ keyPath: WritableKeyPath<HistorySearchCondition, Value>) -> Binding<Value> {
        Binding(
            get: { condition[keyPath: keyPath] },
            set: { value in
                var updated = condition
                updated[keyPath: keyPath] = value
                history.updateSearchCondition(updated)
            }
        )
    }
}

// MARK: - HistorySearchField

/// 条件行的文字输入框：输入即写回条件，作者、提交人与文件条件弹出补全。
private struct HistorySearchField: NSViewRepresentable {
    /// 输入框的协调者：接收输入并持有补全。
    @MainActor
    final class Coordinator: NSObject {
        /// 补全弹窗；它同时是输入框的代理。
        let completion = ContributorCompletion()

        /// 写回条件的动作。
        var onChange: (String) -> Void = { _ in }

        /// 按输入给出补全建议，随条件种类更新。
        var suggestions: @MainActor (String) async -> [ContributorSuggestion] = { _ in [] }

        /// 每次输入都写回条件。
        @objc
        func textChanged(_ sender: NSTextField) {
            onChange(sender.stringValue)
        }
    }

    /// 条件当前的文字。
    let text: String

    /// 占位文字。
    let placeholder: String

    /// 是否需要获得键盘焦点。
    let focused: Bool

    /// 按输入给出补全建议。
    let suggestions: @MainActor (String) async -> [ContributorSuggestion]

    /// 文字改变后写回条件。
    let onChange: (String) -> Void

    /// 获得焦点后清除焦点请求。
    let onFocus: () -> Void

    /// 建立协调者。
    func makeCoordinator() -> Coordinator { Coordinator() }

    /// 13 pt 的单行输入框，每次输入都发出动作。
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.font = .systemFont(ofSize: 13)
        field.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        field.isContinuous = true
        field.target = context.coordinator
        field.action = #selector(Coordinator.textChanged(_:))

        // 补全只接管一次，接管时会关闭弹窗；建议的来源与写回动作经协调者随时更新
        let coordinator = context.coordinator
        coordinator.completion.attach(
            to: field,
            suggestions: { [weak coordinator] query in
                await coordinator?.suggestions(query) ?? []
            },
            apply: { [weak coordinator] in coordinator?.onChange($0) }
        )

        return field
    }

    /// 同步文字、占位、补全来源与焦点；接受补全后与键入一样写回条件。
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.suggestions = suggestions

        if field.stringValue != text, field.currentEditor() == nil {
            field.stringValue = text
        }

        field.placeholderString = placeholder

        guard focused else { return }

        Task { @MainActor in
            field.window?.makeFirstResponder(field)
            onFocus()
        }
    }
}

// MARK: - AddRemoveControl

/// − / + 两段的瞬时分段控件：− 在左、+ 在右。
private struct AddRemoveControl: NSViewRepresentable {
    /// 转发分段点击。
    @MainActor
    final class Coordinator: NSObject {
        /// 点击动作，参数为是否点了 +。
        var action: (Bool) -> Void = { _ in }

        /// 第 1 段是 +。
        @objc
        func clicked(_ sender: NSSegmentedControl) {
            action(sender.selectedSegment == 1)
        }
    }

    /// 点击动作，参数为是否点了 +。
    let action: (Bool) -> Void

    /// 建立协调者。
    func makeCoordinator() -> Coordinator { Coordinator() }

    /// 系统的减号与加号模板图，两段宽 20 与 19 pt。
    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            images: [
                NSImage(named: NSImage.removeTemplateName) ?? NSImage(),
                NSImage(named: NSImage.addTemplateName) ?? NSImage(),
            ],
            trackingMode: .momentary,
            target: context.coordinator,
            action: #selector(Coordinator.clicked(_:))
        )
        control.segmentStyle = .texturedRounded
        control.setWidth(20, forSegment: 0)
        control.setWidth(19, forSegment: 1)
        control.setToolTip(AppLocalization.text("history.search.remove"), forSegment: 0)
        control.setToolTip(AppLocalization.text("history.search.add"), forSegment: 1)
        return control
    }

    /// 更新点击动作。
    func updateNSView(_: NSSegmentedControl, context: Context) {
        context.coordinator.action = action
    }
}

// MARK: - Titles

extension HistorySearchCondition.Kind {
    /// 种类菜单与说明条里的名称。
    var title: String {
        switch self {
        case .message: AppLocalization.text("history.search.message")
        case .author: AppLocalization.text("history.search.author")
        case .committer: AppLocalization.text("history.search.committer")
        case .file: AppLocalization.text("history.search.file")
        case .hash: AppLocalization.text("history.search.hash")
        case .date: AppLocalization.text("history.search.date")
        }
    }

    /// 输入框的占位文字。
    var placeholder: String {
        switch self {
        case .message: AppLocalization.text("history.search.forMessage")
        case .author: AppLocalization.text("history.search.forAuthor")
        case .committer: AppLocalization.text("history.search.forCommitter")
        case .file: AppLocalization.text("history.search.forFile")
        case .hash: AppLocalization.text("history.search.forHash")
        case .date: ""
        }
    }
}

extension HistorySearchCondition.DateRelation {
    /// 关系菜单里的名称。
    var title: String {
        switch self {
        case .after: AppLocalization.text("history.search.after")
        case .before: AppLocalization.text("history.search.before")
        case .range: AppLocalization.text("history.search.range")
        }
    }
}
