import Foundation
import SwiftUI

// MARK: - IssueTracking

/// Issue 追踪的地址模板与编号前缀：模板里的 `{ISSUE_NUMBER}` 换成编号就是 Issue 的网页地址。
enum IssueTracking {
    /// 模板里标出编号位置的占位符。
    static let numberPlaceholder = "{ISSUE_NUMBER}"

    /// 模板里支持的占位符；所有者与仓库名由远端地址得出。
    static let placeholders = [numberPlaceholder, "{OWNER}", "{REPOSITORY}"]

    /// 编号前缀的最大长度。
    static let prefixLimit = 20

    /// 没有自定义时的编号前缀。
    static let defaultPrefix = "#"

    /// 模板与前缀不合法的原因；合法时为 nil。都为空表示不使用 Issue 追踪，也算合法。
    ///
    /// - Parameters:
    ///   - template: 地址模板。
    ///   - prefix: 编号前缀。
    static func problem(template: String, prefix: String) -> String? {
        if prefix.count > prefixLimit {
            return AppLocalization.text("issueTracking.error.prefixLength", prefixLimit)
        }

        if prefix.contains(where: \.isWhitespace) {
            return AppLocalization.text("issueTracking.error.prefixWhitespace")
        }

        guard !template.isEmpty else {
            // 自定义的前缀必须配上地址模板，默认的 # 可以单独使用
            return prefix.isEmpty || prefix == defaultPrefix
                ? nil
                : AppLocalization.text("issueTracking.error.templateRequired")
        }

        return templateProblem(template)
    }

    /// 地址模板不合法的原因：含空白、带不支持的占位符、没有编号占位符，或填入编号后不是网页地址。
    ///
    /// - Parameter template: 非空的地址模板。
    static func templateProblem(_ template: String) -> String? {
        if template.contains(where: \.isWhitespace) {
            return AppLocalization.text("issueTracking.error.templateWhitespace")
        }

        // 去掉支持的占位符后仍有花括号，说明用了不支持的占位符
        let stripped = placeholders.reduce(template) { $0.replacingOccurrences(of: $1, with: "") }

        if stripped.contains("{") || stripped.contains("}") {
            return AppLocalization.text("issueTracking.error.placeholders")
        }

        // 占位符换成示例值后必须是带主机名的 http / https 地址
        let sample = placeholders.reduce(template) { $0.replacingOccurrences(of: $1, with: "1") }
        let url = URL(string: sample)

        guard
            template.contains(numberPlaceholder),
            let scheme = url?.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = url?.host,
            !host.isEmpty
        else {
            return AppLocalization.text("issueTracking.error.template")
        }

        return nil
    }
}

// MARK: - IssueTrackingDialog

/// 编辑 Issue 追踪的地址模板与编号前缀；Integration 页编辑本机全局配置里的值。
struct IssueTrackingDialog: View {
    /// 保存回调：去掉首尾空白后的模板与前缀，空值表示删除。
    let save: (_ template: String, _ prefix: String) -> Void

    /// 关闭对话框。
    let close: () -> Void

    /// 地址模板。
    @State
    private var template: String

    /// 编号前缀。
    @State
    private var prefix: String

    /// 对话框骨架里放两行输入，各带一行说明。
    var body: some View {
        let problem = IssueTracking.problem(template: trimmedTemplate, prefix: trimmedPrefix)

        DialogLayout(
            title: AppLocalization.text("issueTracking.title"),
            message: AppLocalization.text("issueTracking.title.help"),
            submitTitle: AppLocalization.text("issueTracking.save"),
            error: problem,
            canSubmit: problem == nil,
            cancel: close,
            submit: {
                save(trimmedTemplate, trimmedPrefix)
                close()
            }
        ) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 4) {
                row("issueTracking.url", help: "issueTracking.url.help") {
                    TextField(AppLocalization.text("issueTracking.url.placeholder"), text: $template)
                }

                row("issueTracking.prefix", help: "issueTracking.prefix.help") {
                    TextField("", text: $prefix)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    /// 以现有的模板与前缀打开编辑框。
    ///
    /// - Parameters:
    ///   - template: 现有的地址模板；没有时为空字符串。
    ///   - prefix: 现有的编号前缀；没有时为空字符串。
    ///   - save: 保存回调。
    ///   - close: 关闭对话框。
    init(
        template: String,
        prefix: String,
        save: @escaping (_ template: String, _ prefix: String) -> Void,
        close: @escaping () -> Void
    ) {
        _template = State(initialValue: template)
        _prefix = State(initialValue: prefix)
        self.save = save
        self.close = close
    }
}

// MARK: - Private

extension IssueTrackingDialog {
    /// 去掉首尾空白的地址模板。
    private var trimmedTemplate: String {
        template.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 去掉首尾空白的编号前缀。
    private var trimmedPrefix: String {
        prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 右对齐的标签、输入框，以及输入框下方 11 pt 的说明。
    private func row(_ label: String, help: String, @ViewBuilder field: () -> some View) -> some View {
        GridRow {
            Text(AppLocalization.text(label))
                .fixedSize()
                .gridColumnAlignment(.trailing)

            VStack(alignment: .leading, spacing: 4) {
                field()
                    .accessibilityLabel(AppLocalization.text(label))

                Text(AppLocalization.text(help, IssueTracking.numberPlaceholder))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 8)
        }
    }
}
