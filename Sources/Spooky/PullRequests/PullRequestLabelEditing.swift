import AppKit
import SpookyKit
import SwiftUI

// MARK: - PullRequestLabelPicker

/// 添加标签的选择：顶部按名称筛选，中间列出项目里还没加到请求上的标签，底部是新建标签。
///
/// 打开时读取项目的标签；点一个标签把它加到请求上并关闭。
struct PullRequestLabelPicker: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 要加标签的请求。
    let request: PullRequest

    /// 关闭选择。
    let close: () -> Void

    /// 项目里的全部标签；还没读到时为 nil。
    @State
    private var labels: [PullRequestLabel]? = nil

    /// 读取标签的失败；没有失败时为空。
    @State
    private var failure = ""

    /// 筛选的文字。
    @State
    private var filter = ""

    /// 宽 240：筛选框、高 200 的标签列表与新建标签。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("", text: $filter, prompt: Text(AppLocalization.text("pullRequests.labels.filter")))
                .textFieldStyle(.roundedBorder)
                .padding(8)

            Divider()

            content
                .frame(height: 200)

            Divider()

            Button(AppLocalization.text("pullRequests.labels.new")) {
                close()
                session.requestPullRequest(.createLabel(request))
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
        .font(.system(size: 13))
        .frame(width: 240)
        .task { await load() }
    }

    /// 可以加到请求上的标签：项目里的标签去掉请求已有的，再按名称不分大小写地筛选。
    ///
    /// - Parameters:
    ///   - labels: 项目里的全部标签。
    ///   - request: 要加标签的请求。
    ///   - filter: 筛选的文字，首尾的空白不算。
    static func candidates(in labels: [PullRequestLabel], for request: PullRequest, filter: String) -> [PullRequestLabel] {
        let existing = Set(request.labels.map(\.name))
        let text = filter.trimmingCharacters(in: .whitespaces)

        return labels.filter {
            !existing.contains($0.name) && (text.isEmpty || $0.name.localizedCaseInsensitiveContains(text))
        }
    }
}

// MARK: - Layout

extension PullRequestLabelPicker {
    /// 读到之前是转圈，读取失败时写出原因，没有可加的标签时写明，否则是标签列表。
    @ViewBuilder
    private var content: some View {
        if let labels {
            let candidates = Self.candidates(in: labels, for: request, filter: filter)

            if candidates.isEmpty {
                notice(AppLocalization.text("pullRequests.labels.none"))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(candidates, id: \.name) { row($0) }
                    }
                    .padding(.vertical, 4)
                }
            }
        } else if failure.isEmpty {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            notice(failure)
        }
    }

    /// 一个标签：底色的圆点与名称，提示是标签的说明；点了加到请求上。
    private func row(_ label: PullRequestLabel) -> some View {
        Button {
            close()
            session.addLabel(label.name, to: request)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(label.color.map { PaletteColor(hex: "#" + $0, alpha: 1).color } ?? .secondary)
                    .frame(width: 10, height: 10)

                Text(label.name)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label.description)
    }

    /// 居中的次级色说明。
    private func notice(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 读取项目里的标签。
    private func load() async {
        do {
            labels = try await session.pullRequests.loadLabels()
        } catch {
            failure = AppFailure(error: error, opening: false, location: nil).details
        }
    }
}

// MARK: - PullRequestLabelDialog

/// 新建标签：填名称、选底色，新建后加到请求上。
struct PullRequestLabelDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 要加上新标签的请求。
    let request: PullRequest

    /// 关闭 sheet。
    let close: () -> Void

    /// 标签的名称。
    @State
    private var name = ""

    /// 标签的底色，一开始是浅灰。
    @State
    private var color = AppPalette.color("repository_pullrequests_label_initial_color")

    /// 名称与底色两行；名称不全是空白时主按钮可用。
    var body: some View {
        let texts = Self.texts(for: request, in: session)

        DialogLayout(
            title: texts.title,
            message: texts.message,
            submitTitle: texts.title,
            error: nil,
            canSubmit: !trimmedName.isEmpty,
            cancel: close,
            submit: submit
        ) {
            DialogForm {
                DialogFormRow(label: AppLocalization.text("pullRequests.labelName")) {
                    TextField("", text: $name)
                }

                DialogFormRow(label: AppLocalization.text("pullRequests.labelColor"), alignment: .center) {
                    ColorPicker("", selection: $color, supportsOpacity: false)
                        .labelsHidden()
                }
            }
        }
    }

    /// 标题与说明：说明写出账号所在的服务、项目与请求的编号；主按钮与标题同文。
    ///
    /// - Parameters:
    ///   - request: 要加上新标签的请求。
    ///   - session: 窗口会话，按选中远端的服务决定叫 Pull Request 还是 Merge Request。
    static func texts(for request: PullRequest, in session: RepositorySession) -> (title: String, message: String) {
        (
            AppLocalization.text("pullRequests.createLabel.title"),
            session.pullRequestText(
                "createLabel.message",
                AccountsSettingsView.serviceTitle(request.id.instance),
                request.id.project,
                request.id.reference
            )
        )
    }

    /// 颜色写成托管服务要的 6 位小写十六进制，不带 “#”；取不出 RGB 分量的颜色返回 nil。
    static func hex(of color: Color) -> String? {
        PaletteColor(nsColor: NSColor(color)).map { String($0.hex.dropFirst()).lowercased() }
    }
}

// MARK: - Private

extension PullRequestLabelDialog {
    /// 去掉首尾空白的名称。
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    /// 开始后关闭。
    private func submit() {
        guard
            let hex = Self.hex(of: color),
            session.createLabel(trimmedName, color: hex, for: request)
        else {
            return
        }

        close()
    }
}
