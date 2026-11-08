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

    /// 对话框骨架：内容区是各操作的输入行，校验与读取失败写在错误区。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: title,
            message: message,
            submitTitle: submitTitle,
            error: error,
            isValid: canSubmit,
            cancel: close,
            submit: submit
        ) {
            content
        }
        .onAppear(perform: prepare)
    }
}

// MARK: - Layout

extension WorkingCopyFileDialog {
    /// 各操作的输入行。
    @ViewBuilder
    private var content: some View {
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

    /// 版本输入：填满输入列的组合框里可以直接输入版本，也可以从引用里选。
    private var revisionRow: some View {
        // 组合框是 AppKit 控件，没有文字基线可对，标签与它按竖直居中对齐
        DialogFormRow(label: AppLocalization.text("files.revert.revision"), alignment: .center) {
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

    /// 补丁文件：输入列里填满的弹出菜单，列出本次表单选过的文件与选择新文件的入口；这一行没有标签。
    private var patchRow: some View {
        DialogFormField {
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
            .buttonSizing(.flexible)
            .accessibilityLabel(AppLocalization.text("files.applyPatch.file"))
        }
    }

    /// 标签加填满输入列的单行输入框。
    private func textRow(_ key: String) -> some View {
        DialogFormRow(label: AppLocalization.text(key)) {
            TextField("", text: $text)
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

    /// 组合框的候选，来自当前的引用快照。
    private var revisions: [String] {
        Self.revisions(in: session.history.snapshot)
    }

    /// 参数完整时允许提交；仓库是否可写由骨架判断。
    private var canSubmit: Bool {
        switch form {
        case .revert, .pattern, .lfsPattern: !text.trimmingCharacters(in: .whitespaces).isEmpty
        case .move(let entry): Self.destination(text, from: entry.path) != nil
        case .applyPatch: patchFile != nil
        }
    }

    /// 组合框的候选：本地分支、各远端的远端分支与标签依次成组，组内按公共顺序排列，不含符号引用；
    /// 第一项是打开时预选的版本，当前分支不提前。同名的分支与标签各占一项。
    ///
    /// - Parameter snapshot: 引用快照；还没有读到时为 nil。
    static func revisions(in snapshot: ReferenceSnapshot?) -> [String] {
        let candidates = snapshot?.references.filter { $0.symbolicTarget == nil } ?? []

        return ReferenceOrder.sorted(candidates, in: snapshot).map(\.name)
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
