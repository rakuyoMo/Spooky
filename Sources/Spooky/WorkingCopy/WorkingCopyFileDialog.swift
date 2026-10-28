import AppKit
import SpookyKit
import SwiftUI

// MARK: - WorkingCopyFileDialog

/// 工作区文件操作的参数表单：恢复到指定版本、移动、自定义忽略规则、LFS 跟踪规则与应用补丁；提交后表单立即关闭，进度与失败由仓库窗口承接。
struct WorkingCopyFileDialog: View {
    /// 发起操作的窗口会话。
    let session: RepositorySession

    /// 由入口确定的操作与所选文件。
    let form: WorkingCopyFileForm

    /// 关闭表单。
    let close: () -> Void

    /// 版本、新路径或规则的输入。
    @State
    private var text = ""

    /// 本次表单里选过的补丁文件，最近选的在前。
    @State
    private var patchFiles: [URL] = []

    /// 当前要应用的补丁文件。
    @State
    private var patchFile: URL?

    /// 输入校验或读取补丁失败的说明。
    @State
    private var error = ""

    /// 头部、内容、校验说明与底栏，与其它操作表单一致。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            content
                .font(.system(size: 13))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            if !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            // 断线或其它写操作进行中时主按钮禁用，说明原因并保留已填写的参数
            if !session.canWrite {
                Label(AppLocalization.text("dialog.blocked"), systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            footer
        }
        .frame(width: 540)
        .onAppear(perform: prepare)
    }
}

// MARK: - Layout

extension WorkingCopyFileDialog {
    /// 头部：图标、操作名、服务器仓库的位置与说明。
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 42))
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))

                // 服务器仓库在标题下写出带主机前缀的位置，本机仓库没有这一行
                if let repository = session.repository, repository.host != nil {
                    Text(repository.displayPath)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                }

                Text(message)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 各操作的输入行。
    @ViewBuilder
    private var content: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
            switch form {
            case .revert:
                revisionRow

            case .move:
                textRow("files.move.destination")

            case .pattern, .lfsPattern:
                textRow("files.pattern")

            case .applyPatch:
                patchRow
            }
        }
    }

    /// 版本输入：组合框里可以直接输入版本，也可以从引用里选。
    private var revisionRow: some View {
        GridRow {
            Text(AppLocalization.text("files.revert.revision"))
                .gridColumnAlignment(.trailing)

            RevisionComboBox(
                text: $text,
                items: revisions,
                label: AppLocalization.text("files.revert.revision")
            )
            .onChange(of: text) {
                // 输入版本后不再显示 “没有引用” 的说明
                error = ""
            }
        }
    }

    /// 补丁文件：本次表单选过的文件与选择新文件的入口。
    private var patchRow: some View {
        GridRow {
            Text(AppLocalization.text("files.applyPatch.file"))
                .gridColumnAlignment(.trailing)

            Menu {
                ForEach(patchFiles, id: \.self) { url in
                    Toggle(url.lastPathComponent, isOn: Binding(get: { patchFile == url }, set: { _ in patchFile = url }))
                }

                if !patchFiles.isEmpty {
                    Divider()
                }

                Button(AppLocalization.text("files.applyPatch.select"), action: choosePatchFile)
            } label: {
                Text(patchFile?.lastPathComponent ?? AppLocalization.text("files.applyPatch.none"))
            }
            .accessibilityLabel(AppLocalization.text("files.applyPatch.file"))
        }
    }

    /// 底栏：取消与执行按钮，参数不完整或仓库不可写时禁用执行。
    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(AppLocalization.text("action.cancel"), action: close)
                .keyboardShortcut(.cancelAction)

            Button(submitTitle, action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
        }
        .padding(.horizontal, 20)
        .frame(height: 53)
    }

    /// 标签加单行输入框。
    private func textRow(_ key: String) -> some View {
        GridRow {
            Text(AppLocalization.text(key))
                .gridColumnAlignment(.trailing)

            TextField("", text: $text)
                .accessibilityLabel(AppLocalization.text(key))
        }
    }
}

// MARK: - Content

extension WorkingCopyFileDialog {
    /// 表单标题。
    private var title: String {
        switch form {
        case .revert:
            AppLocalization.text("files.revert")

        case .move(let entry):
            AppLocalization.text("files.move.title", WorkingCopyFileList.fileName(of: entry.path))

        case .pattern(let file, _):
            AppLocalization.text(file == .gitignore ? "files.ignore.custom.title" : "files.exclude.custom.title")

        case .lfsPattern:
            AppLocalization.text("lfs.pattern.title")

        case .applyPatch:
            AppLocalization.text("files.applyPatch")
        }
    }

    /// 说明：写明影响范围；服务器仓库写明改动发生在服务器上。
    private var message: String {
        let remote = session.repository?.host != nil
        let location = session.repository?.displayPath ?? ""

        switch form {
        case .revert(let entries):
            return AppLocalization.text(
                remote ? "files.revert.remote" : "files.revert.message",
                session.scopeDescription(entries),
                location
            )

        case .move:
            return AppLocalization.text("files.move.message")

        case .pattern(let file, _):
            return AppLocalization.text(file == .gitignore ? "files.ignore.custom.message" : "files.exclude.custom.message")

        case .lfsPattern:
            return AppLocalization.text("lfs.pattern.message")

        case .applyPatch:
            return AppLocalization.text(remote ? "files.applyPatch.remote" : "files.applyPatch.message", location)
        }
    }

    /// 主按钮标题。
    private var submitTitle: String {
        switch form {
        case .revert: AppLocalization.text("files.revert.button")
        case .move: AppLocalization.text("files.move")
        case .pattern, .lfsPattern: AppLocalization.text("files.pattern.save")
        case .applyPatch: AppLocalization.text("files.applyPatch")
        }
    }

    /// 组合框的候选，来自当前的引用快照与分支。
    private var revisions: [String] {
        Self.revisions(
            in: session.history.snapshot?.references ?? [],
            currentBranch: session.status?.branch.head
        )
    }

    /// 参数完整且仓库可写时允许提交。
    private var canSubmit: Bool {
        guard session.canWrite else { return false }

        switch form {
        case .revert, .pattern, .lfsPattern: return !text.trimmingCharacters(in: .whitespaces).isEmpty
        case .move(let entry): return Self.destination(text, from: entry.path) != nil
        case .applyPatch: return patchFile != nil
        }
    }

    /// 组合框的候选：当前分支在前，其后依次是本地分支、远端分支与标签，不含符号引用；第一项是打开时预选的版本。
    ///
    /// - Parameters:
    ///   - references: 按完整名称排序的引用快照。
    ///   - currentBranch: 当前分支名，分离 HEAD 时为 nil。
    static func revisions(in references: [RepositoryReference], currentBranch: String?) -> [String] {
        #warning("TODO: 核实 Revert to Revision 候选引用的顺序与打开时预选的引用，目前当前分支在前、其后依次是本地分支、远端分支与标签；只影响组合框的候选顺序与预填的版本")
        let candidates = references.filter { $0.symbolicTarget == nil }
        let current = currentBranch.map { "refs/heads/" + $0 }

        // 同名的分支与标签各占一项，按引用的完整名称认出当前分支
        let ordered = candidates.filter { $0.id == current } + candidates.filter { $0.id != current }

        return ordered.map(\.name)
    }

    /// 新路径必须是仓库内的相对路径：不能为空、以 “/” 开头、含 “.” 与 “..” 段或换行，也不能与原路径相同。
    static func destination(_ text: String, from path: String) -> String? {
        let components = text.split(separator: "/", omittingEmptySubsequences: false)

        guard
            !text.isEmpty, text != path,
            !text.contains("\n"), !text.contains("\r"), !text.contains("\0"),
            components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else { return nil }

        return text
    }
}

// MARK: - Actions

extension WorkingCopyFileDialog {
    /// 预填输入：移动预填原路径，自定义规则预填只匹配第一个所选文件的规则，LFS 规则预填第一个所选文件的路径，恢复版本预选第一个候选引用。
    private func prepare() {
        switch form {
        case .move(let entry):
            text = entry.path

        case .pattern(_, let entries):
            text = WorkingCopyOperations.ignorePatterns(for: entries.prefix(1).map(\.path), scope: .items).first ?? ""

        case .lfsPattern(let entries):
            text = entries.first?.path ?? ""

        case .revert:
            // 预选第一个候选；仓库还没有引用时说明原因，仍可直接输入版本
            text = revisions.first ?? ""

            if revisions.isEmpty {
                error = AppLocalization.text("files.revert.noRefs")
            }

        case .applyPatch:
            break
        }
    }

    /// 在本机选择补丁文件。
    private func choosePatchFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        patchFiles.removeAll { $0 == url }
        patchFiles.insert(url, at: 0)
        patchFile = url
    }

    /// 提交：写操作开始后关闭表单；仓库暂不可写时保留表单与已填写的参数。
    private func submit() {
        error = ""

        switch form {
        case .revert(let entries):
            let name = text.trimmingCharacters(in: .whitespaces)
            let reference = session.history.snapshot?.references.first { $0.name == name }
            if session.revert(entries, to: reference?.id ?? name) { close() }

        case .move(let entry):
            guard let destination = Self.destination(text, from: entry.path) else { return }
            if session.move(entry, to: destination) { close() }

        case .pattern(let file, let entries):
            // 先关闭表单，需要询问是否停止跟踪时窗口才能呈现询问
            close()
            session.addPatterns([text], for: entries, in: file)

        case .lfsPattern:
            if session.trackLFS([text.trimmingCharacters(in: .whitespaces)]) { close() }

        case .applyPatch:
            applyPatchFile()
        }
    }

    /// 在本机读出补丁内容再交给工作区所在机器上的 git apply；读取失败的说明留在表单里。
    private func applyPatchFile() {
        guard let patchFile else { return }

        do {
            let patch = try Data(contentsOf: patchFile)
            if session.applyPatch(patch) { close() }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
