import AppKit
import SpookyKit
import SwiftUI

// MARK: - WorkingCopyFileDialog

/// 工作区文件操作的参数表单：恢复到指定版本、移动、自定义忽略规则与应用补丁；提交后表单立即关闭，进度与失败由仓库窗口承接。
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
    /// 头部：图标、操作名、仓库路径与说明。
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 42))
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))

                Text(session.repository?.displayPath ?? "")
                    .font(.system(size: 13))
                    .textSelection(.enabled)

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

            case .pattern:
                textRow("files.pattern")

            case .applyPatch:
                patchRow
            }
        }
    }

    /// 版本输入：可以直接输入提交哈希，也可以从引用里选。
    private var revisionRow: some View {
        GridRow {
            Text(AppLocalization.text("files.revert.revision"))
                .gridColumnAlignment(.trailing)

            HStack(spacing: 4) {
                TextField("", text: $text)
                    .accessibilityLabel(AppLocalization.text("files.revert.revision"))

                Menu {
                    ForEach(revisions, id: \.self) { name in
                        Button(name) { text = name }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24)
                .disabled(revisions.isEmpty)
                .accessibilityLabel(AppLocalization.text("files.revert.revision"))
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

        case .applyPatch:
            return AppLocalization.text(remote ? "files.applyPatch.remote" : "files.applyPatch.message", location)
        }
    }

    /// 主按钮标题。
    private var submitTitle: String {
        switch form {
        case .revert: AppLocalization.text("files.revert.button")
        case .move: AppLocalization.text("files.move")
        case .pattern: AppLocalization.text("files.pattern.save")
        case .applyPatch: AppLocalization.text("files.applyPatch")
        }
    }

    /// 可选的版本：HEAD 与全部本地分支、远端分支和标签。
    private var revisions: [String] {
        ["HEAD"] + (session.history.snapshot?.references ?? [])
            .filter { $0.symbolicTarget == nil }
            .map(\.name)
    }

    /// 参数完整且仓库可写时允许提交。
    private var canSubmit: Bool {
        guard session.canWrite else { return false }

        switch form {
        case .revert, .pattern: return !text.trimmingCharacters(in: .whitespaces).isEmpty
        case .move(let entry): return Self.destination(text, from: entry.path) != nil
        case .applyPatch: return patchFile != nil
        }
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
    /// 预填输入：移动预填原路径，自定义规则预填只匹配第一个所选文件的规则。
    private func prepare() {
        switch form {
        case .move(let entry):
            text = entry.path

        case .pattern(_, let entries):
            text = WorkingCopyOperations.ignorePatterns(for: entries.prefix(1).map(\.path), scope: .items).first ?? ""

        case .revert, .applyPatch:
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
