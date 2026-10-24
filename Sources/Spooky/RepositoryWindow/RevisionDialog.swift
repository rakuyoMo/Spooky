import SpookyKit
import SwiftUI

// MARK: - RevisionRequest

/// 历史里导出、保存补丁与比较版本的对话框请求。
enum RevisionRequest {
    /// 导出一个版本；有路径时只导出这些路径，归档时预先勾上 Create Archive。
    case export(revision: String?, paths: [String], archive: Bool)

    /// 把所选提交存成补丁，按列表顺序排列。
    case savePatch([HistoryCommit])

    /// 比较两个版本，可以预先填好第一个。
    case compare(base: String?)
}

// MARK: - RevisionDialog

/// 导出、保存补丁与比较版本共用的 sheet：只收集参数，点主按钮后关闭，导出与补丁在 Activity 里执行。
struct RevisionDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 对话框种类与预填项。
    let request: RevisionRequest

    /// 打开对话框时的仓库；提交时仓库已切换则不执行。
    let repository: RepositoryLocation?

    /// 关闭 sheet。
    let close: () -> Void

    /// 导出的版本，或比较的第一个版本。
    @State
    private var revision = ""

    /// 比较的第二个版本。
    @State
    private var other = ""

    /// 导出成 zip 归档。
    @State
    private var createsArchive = false

    /// 补丁里的路径不带前缀，跨仓库记忆。
    @AppStorage(RepositorySession.omitsPatchPrefixesKey)
    private var omitsPrefixes = false

    /// 补丁选项区是否展开；默认收起，不记忆。
    @State
    private var optionsExpanded = false

    /// 版本解析失败的说明。
    @State
    private var error = ""

    /// 正在解析版本时禁用主按钮。
    @State
    private var isResolving = false

    /// 头部、内容、错误、选项与底栏依次排列。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                form
            }
            .font(.system(size: 13))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            if case .savePatch = request {
                options
            }

            footer
        }
        .frame(width: 540)
        .onAppear(perform: prepare)
        .onChange(of: revision) { error = "" }
        .onChange(of: other) { error = "" }
    }
}

// MARK: - Layout

extension RevisionDialog {
    /// 头部：图标、标题、仓库路径与说明。
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 42))
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))

                Text(session.repository?.displayPath ?? "")
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 导出：版本与是否归档；比较：两个版本；保存补丁没有内容区。
    @ViewBuilder
    private var form: some View {
        switch request {
        case .export:
            revisionRow("export.revision", text: $revision)

            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                option("export.createArchive", value: $createsArchive)
            }

        case .compare:
            revisionRow("compare.base", text: $revision)
            revisionRow("compare.target", text: $other)

        case .savePatch:
            EmptyView()
        }
    }

    /// 保存补丁的选项区：去掉路径前缀。
    private var options: some View {
        DisclosureGroup(AppLocalization.text("dialog.options"), isExpanded: $optionsExpanded) {
            option("patch.omitPrefixes", value: $omitsPrefixes)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(AppPalette.color("general_secondary_background_color"))
    }

    /// 底栏：取消与主按钮。
    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(AppLocalization.text("action.cancel"), action: close)
                .keyboardShortcut(.cancelAction)

            Button(AppLocalization.text(submitKey), action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
        }
        .padding(.horizontal, 20)
        .frame(height: 53)
    }

    /// 一行可输入的版本组合框，列表是仓库里的引用。
    private func revisionRow(_ key: String, text: Binding<String>) -> some View {
        GridRow {
            Text(AppLocalization.text(key))
                .gridColumnAlignment(.trailing)

            RevisionComboBox(text: text, items: references, label: AppLocalization.text(key))
                .frame(maxWidth: 350, alignment: .leading)
        }
    }

    /// 勾选项与下面一行 11 pt 说明，说明对齐勾选框的标题。
    private func option(_ key: String, value: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(AppLocalization.text(key), isOn: value)

            Text(AppLocalization.text(key + ".help"))
                .font(.system(size: 11))
                .padding(.leading, 19)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Actions

extension RevisionDialog {
    /// 标题：按种类与条目数选择。
    private var title: String {
        switch request {
        case .export(_, let paths, _) where !paths.isEmpty:
            AppLocalization.text("export.itemsTitle", paths.count, String(revision.prefix(8)))

        case .export:
            AppLocalization.text("export.title")

        case .savePatch:
            AppLocalization.text("patch.title")

        case .compare:
            AppLocalization.text("compare.title")
        }
    }

    /// 标题下的一句说明。
    private var message: String {
        switch request {
        case .export(_, let paths, _):
            AppLocalization.text(paths.isEmpty ? "export.message" : "export.itemsMessage")

        case .savePatch(let commits):
            AppLocalization.text(commits.count == 1 ? "patch.message" : "patch.messageMany")

        case .compare:
            AppLocalization.text("compare.message")
        }
    }

    /// 主按钮的资源键。
    private var submitKey: String {
        switch request {
        case .export: "export.submit"
        case .savePatch: "patch.save"
        case .compare: "compare.submit"
        }
    }

    /// 组合框列出的引用：本地分支、远端分支与标签，HEAD 在最前。
    private var references: [String] {
        ["HEAD"] + (session.history.snapshot?.references ?? [])
            .filter { $0.symbolicTarget == nil }
            .map(\.name)
    }

    /// 版本不能为空；仓库已切换时不提交。
    private var canSubmit: Bool {
        guard !isResolving, session.repository == repository else {
            return false
        }

        switch request {
        case .export:
            return !revision.trimmingCharacters(in: .whitespaces).isEmpty

        case .compare:
            return !revision.trimmingCharacters(in: .whitespaces).isEmpty
                && !other.trimmingCharacters(in: .whitespaces).isEmpty

        case .savePatch:
            return true
        }
    }

    /// 预填入口指定的版本；导出没有指定时预选 HEAD。
    private func prepare() {
        switch request {
        case .export(let revision, _, let archive):
            self.revision = revision ?? "HEAD"
            createsArchive = archive

        case .compare(let base):
            revision = base ?? ""

        case .savePatch:
            break
        }
    }

    /// 解析输入的版本，成功后关闭对话框并执行。
    private func submit() {
        guard canSubmit, let runner = session.runner else {
            return
        }

        switch request {
        case .savePatch(let commits):
            close()
            session.savePatches(commits, omitsPrefixes: omitsPrefixes)

        case .export(_, let paths, _):
            resolve([revision], runner: runner) { ids in
                session.export(ids[0], paths: paths, archive: createsArchive)
            }

        case .compare:
            resolve([revision, other], runner: runner) { ids in
                session.compare(
                    base: RevisionComparisonState.Side(id: ids[0], title: revision),
                    target: RevisionComparisonState.Side(id: ids[1], title: other)
                )
            }
        }
    }

    /// 把输入解析成提交；任一个解析不了时在错误区说明，对话框保持打开。
    private func resolve(_ inputs: [String], runner: GitRunner, then action: @escaping ([String]) -> Void) {
        isResolving = true

        Task {
            var ids: [String] = []

            for input in inputs {
                let value = input.trimmingCharacters(in: .whitespaces)

                guard let id = try? await RepositoryReferences(runner: runner).resolve(value) else {
                    error = AppLocalization.text("revision.invalid", value)
                    isResolving = false
                    return
                }

                ids.append(id)
            }

            isResolving = false

            guard session.repository == repository else {
                return
            }

            close()
            action(ids)
        }
    }
}
