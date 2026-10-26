import AppKit
import SpookyKit
import SwiftUI

// MARK: - AddSubmoduleDialog

/// 添加子模块：远端地址与工作区里的路径；路径可以手填，也可以选一个目录。
struct AddSubmoduleDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 关闭 sheet。
    let close: () -> Void

    /// 子模块仓库的地址。
    @State
    private var url = ""

    /// 工作区里的相对路径。
    @State
    private var path = ""

    /// 正在浏览服务器上的目录。
    @State
    private var isBrowsing = false

    /// “Remote URL:” 与 “Path:” 两行。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text("submodule.add"),
            message: AppLocalization.text("submodule.add.message"),
            submitTitle: AppLocalization.text("submodule.add.submit"),
            error: error,
            isValid: !url.isEmpty && !trimmedPath.isEmpty && error.isEmpty,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(AppLocalization.text("remote.url")) {
                TextField("", text: $url, prompt: Text(verbatim: "ssh://example.com/repo.git"))
                    .accessibilityIdentifier("submodule-url")
            }

            ReferenceDialogRows.row(AppLocalization.text("submodule.path")) {
                HStack(spacing: 8) {
                    TextField("", text: $path, prompt: Text(AppLocalization.text("submodule.path.placeholder")))
                        .frame(minWidth: 200)
                        .accessibilityIdentifier("submodule-path")

                    Button(AppLocalization.text("submodule.path.select"), action: selectDestination)
                        .fixedSize()
                }
            }
        }
        .sheet(isPresented: $isBrowsing) {
            if let repository = session.repository, let host = repository.host {
                ServerDirectoryBrowser(host: host, path: repository.path) { chosen in
                    isBrowsing = false
                    chosen.flatMap(relativePath).map { path = $0 }
                }
            }
        }
        .onChange(of: url) { oldValue, newValue in
            // 路径还空着或仍是按旧地址推出的名字时，跟着地址换成仓库名，与 git submodule add 的默认路径相同
            if path.isEmpty || path == RepositoryClone.directoryName(for: oldValue) {
                path = RepositoryClone.directoryName(for: newValue) ?? ""
            }
        }
    }
}

// MARK: - Actions

extension AddSubmoduleDialog {
    /// 去掉首尾空白与末尾斜杠的路径。
    private var trimmedPath: String {
        var value = path.trimmingCharacters(in: .whitespaces)

        while value.hasSuffix("/") {
            value.removeLast()
        }

        return value
    }

    /// 地址与路径的说明：地址写法不对，或路径是绝对路径、带 “..” 一级。
    private var error: String {
        if !url.isEmpty {
            do {
                try RepositoryReferences.validate(url: url)
            } catch {
                return ReferenceDialogRows.validationMessage(error, in: session)
            }
        }

        if trimmedPath.hasPrefix("/") || trimmedPath.split(separator: "/").contains("..") {
            return AppLocalization.text("submodule.path.invalid")
        }

        return ""
    }

    /// 本机仓库用系统的目录面板，服务器仓库浏览 B 上的目录；选中的目录换成相对仓库根目录的路径。
    private func selectDestination() {
        guard let repository = session.repository else {
            return
        }

        guard let local = repository.localURL else {
            isBrowsing = true
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = local
        panel.prompt = AppLocalization.text("submodule.path.choose")

        guard panel.runModal() == .OK, let chosen = panel.url, let relative = relativePath(chosen.path) else {
            return
        }

        path = relative
    }

    /// 仓库里的绝对路径换成相对路径；不在仓库里时为 nil。
    private func relativePath(_ absolute: String) -> String? {
        guard let root = session.repository?.path, absolute.hasPrefix(root + "/") else {
            return nil
        }

        return String(absolute.dropFirst(root.count + 1))
    }

    /// 捕获表单值后开始添加；仓库忙碌时表单保持打开。
    private func submit() {
        if session.addSubmodule(url: url, path: trimmedPath) {
            close()
        }
    }
}

// MARK: - SubmoduleOperationDialog

/// 获取、更新、初始化、同步、修复与删除子模块的对话框：一句说明，按种类带子模块菜单与勾选项。
struct SubmoduleOperationDialog: View {
    /// 对话框的种类。
    enum Kind {
        /// 获取；可以选子模块或全部获取，可以清理远端已删除的分支。
        case fetch

        /// 更新；可以选子模块或全部更新，可以递归。
        case update

        /// 初始化。
        case initialize

        /// 同步地址。
        case synchronize

        /// 修复配置不完整的子模块。
        case repair

        /// 删除；可以保留工作区。
        case delete
    }

    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 对话框的种类。
    let kind: Kind

    /// 关闭 sheet。
    let close: () -> Void

    /// 选中的子模块路径。
    @State
    private var selectedPath: String

    /// 获取或更新全部子模块。
    @State
    private var all = false

    /// 获取时清理远端已删除的分支。
    @AppStorage(SubmodulePreferences.fetchPrune)
    private var prunes = false

    /// 更新时连同嵌套的子模块一起更新。
    @AppStorage(SubmodulePreferences.updateRecursive)
    private var recursive = false

    /// 删除时保留工作区。
    @AppStorage(SubmodulePreferences.deleteKeepsWorkingTree)
    private var keepsWorkingTree = false

    /// 子模块菜单只出现在获取与更新里，其余种类的说明写出子模块名。
    var body: some View {
        if kind == .delete || kind == .repair || kind == .initialize || kind == .synchronize {
            singleBody
        } else {
            selectableBody
        }
    }

    /// 创建对话框，预选给定的子模块；没有给定时预选第一个可用的子模块。
    init(session: RepositorySession, kind: Kind, submodule: Submodule?, close: @escaping () -> Void) {
        self.session = session
        self.kind = kind
        self.close = close
        _selectedPath = State(initialValue: submodule?.path ?? "")
    }
}

// MARK: - Layout

extension SubmoduleOperationDialog {
    /// 获取与更新：子模块菜单、全部的勾选项与各自的选项。
    private var selectableBody: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text(kind == .fetch ? "submodule.fetch" : "submodule.update"),
            message: message,
            submitTitle: AppLocalization.text(kind == .fetch ? "submodule.fetch.submit" : "submodule.update.submit"),
            error: candidates.isEmpty ? AppLocalization.text("submodule.none") : "",
            isValid: all ? !candidates.isEmpty : selected != nil,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(AppLocalization.text("submodule.field")) {
                Picker("", selection: $selectedPath) {
                    ForEach(candidates) { submodule in
                        Text(submodule.name).tag(submodule.path)
                    }
                }
                .labelsHidden()
                .disabled(all)
            }

            ReferenceDialogRows.option(
                AppLocalization.text(kind == .fetch ? "submodule.fetchAll" : "submodule.updateAll"),
                help: "",
                isOn: $all
            )

            if kind == .fetch {
                ReferenceDialogRows.option(
                    AppLocalization.text("sync.prune"),
                    help: AppLocalization.text("sync.prune.help"),
                    isOn: $prunes
                )
            } else {
                ReferenceDialogRows.option(
                    AppLocalization.text("submodule.update.recursive"),
                    help: AppLocalization.text("submodule.update.recursive.help"),
                    isOn: $recursive
                )
            }
        }
        .onAppear {
            if selected == nil { selectedPath = candidates.first?.path ?? "" }
        }
    }

    /// 只作用于一个子模块的种类：说明与删除的保留工作区。
    private var singleBody: some View {
        ReferenceDialogLayout(
            session: session,
            title: title,
            message: message,
            submitTitle: submitTitle,
            error: "",
            isValid: selected != nil,
            cancel: close,
            submit: submit
        ) {
            if kind == .delete {
                ReferenceDialogRows.option(
                    AppLocalization.text("submodule.delete.keepWorkingTree"),
                    help: AppLocalization.text("submodule.delete.keepWorkingTree.help"),
                    isOn: $keepsWorkingTree
                )
            }
        }
    }

    /// 菜单里列出的子模块：获取只列已检出的，更新列出配置完整的。
    private var candidates: [Submodule] {
        session.submodules.items.filter { kind == .fetch ? session.canFetch($0) : $0.isValid }
    }

    /// 选中的子模块。
    private var selected: Submodule? {
        session.submodules.items.first { $0.path == selectedPath }
    }

    /// 标题。
    private var title: String {
        switch kind {
        case .fetch: AppLocalization.text("submodule.fetch")
        case .update: AppLocalization.text("submodule.update")
        case .initialize: AppLocalization.text("submodule.initialize")
        case .synchronize: AppLocalization.text("submodule.synchronize")
        case .repair: AppLocalization.text("submodule.repair")
        case .delete: AppLocalization.text("submodule.delete")
        }
    }

    /// 主按钮的标题。
    private var submitTitle: String {
        switch kind {
        case .fetch: AppLocalization.text("submodule.fetch.submit")
        case .update: AppLocalization.text("submodule.update.submit")
        case .initialize: AppLocalization.text("submodule.initialize.submit")
        case .synchronize: AppLocalization.text("submodule.synchronize.submit")
        case .repair: AppLocalization.text("submodule.repair.submit")
        case .delete: AppLocalization.text("submodule.delete.submit")
        }
    }

    /// 说明；更新一个检出了别的提交的子模块时写出两个提交。
    private var message: String {
        switch kind {
        case .fetch:
            return AppLocalization.text("submodule.fetch.message")

        case .update:
            guard !all else { return AppLocalization.text("submodule.update.message.all") }

            if let selected, selected.state == .updated, let checkedOut = selected.checkedOut, let pointer = selected.pointer {
                return AppLocalization.text(
                    "submodule.update.message.updated",
                    String(checkedOut.prefix(8)),
                    String(pointer.prefix(8))
                )
            }

            return AppLocalization.text("submodule.update.message")

        case .initialize:
            return AppLocalization.text("submodule.initialize.message")

        case .synchronize:
            return AppLocalization.text("submodule.synchronize.message")

        case .repair:
            return AppLocalization.text("submodule.repair.message")

        case .delete:
            return AppLocalization.text("submodule.delete.message", selected?.name ?? "")
        }
    }

    /// 捕获选项后开始执行；仓库忙碌时表单保持打开。
    private func submit() {
        let targets = all ? candidates : selected.map { [$0] } ?? []

        guard !targets.isEmpty else {
            return
        }

        let started: Bool =
            switch kind {
            case .fetch: session.fetchSubmodules(targets, prunes: prunes)
            case .update: session.updateSubmodules(all ? nil : targets, recursive: recursive)
            case .initialize: session.initializeSubmodule(targets[0])
            case .synchronize: session.synchronizeSubmodule(targets[0])
            case .repair: session.repairSubmodule(targets[0])
            case .delete: session.deleteSubmodule(targets[0], keepsWorkingTree: keepsWorkingTree, force: false)
            }

        if started {
            close()
        }
    }
}

// MARK: - SubmoduleValueDialog

/// 填一个值的子模块对话框：移动的新路径、新名称与地址。
struct SubmoduleValueDialog: View {
    /// 填的是什么。
    enum Target {
        /// 移动到新路径，可以同时改名。
        case move

        /// 修改名称。
        case rename

        /// 修改 `.gitmodules` 或本地配置里的地址。
        case url(SubmoduleConfigurationScope)
    }

    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 操作的子模块。
    let submodule: Submodule

    /// 填的是什么。
    let target: Target

    /// 关闭 sheet。
    let close: () -> Void

    /// 输入框里的值，打开时是原值。
    @State
    private var value: String

    /// 移动时把名称改成新路径。
    @AppStorage(SubmodulePreferences.moveRenames)
    private var renames = false

    /// 一个输入框；移动另带改名的勾选项。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: texts.title,
            message: texts.message,
            submitTitle: texts.submit,
            error: error,
            isValid: !trimmed.isEmpty && error.isEmpty,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(texts.label) {
                TextField("", text: $value, prompt: texts.placeholder.map { Text(verbatim: $0) })
                    .accessibilityIdentifier("submodule-value")
            }

            if case .move = target {
                ReferenceDialogRows.option(
                    AppLocalization.text("submodule.move.rename"),
                    help: AppLocalization.text("submodule.move.rename.help"),
                    isOn: $renames
                )
            }
        }
    }

    /// 创建对话框，输入框里填上原值。
    init(session: RepositorySession, submodule: Submodule, target: Target, close: @escaping () -> Void) {
        self.session = session
        self.submodule = submodule
        self.target = target
        self.close = close

        let original: String =
            switch target {
            case .move: submodule.path
            case .rename: submodule.name
            case .url(let scope): (scope == .shared ? submodule.shared?.url : submodule.local?.url) ?? ""
            }

        _value = State(initialValue: original)
    }
}

// MARK: - Actions

extension SubmoduleValueDialog {
    /// 去掉首尾空白的值；路径另去掉末尾斜杠。
    private var trimmed: String {
        var text = value.trimmingCharacters(in: .whitespaces)

        if case .move = target {
            while text.hasSuffix("/") {
                text.removeLast()
            }
        }

        return text
    }

    /// 标题、说明、主按钮、标签与占位文字。
    private var texts: (title: String, message: String, submit: String, label: String, placeholder: String?) {
        switch target {
        case .move:
            (
                AppLocalization.text("submodule.move"),
                AppLocalization.text("submodule.move.message"),
                AppLocalization.text("submodule.move.submit"),
                AppLocalization.text("submodule.newPath"),
                nil
            )

        case .rename:
            (
                AppLocalization.text("submodule.rename"),
                AppLocalization.text("submodule.rename.message"),
                AppLocalization.text("submodule.rename.submit"),
                AppLocalization.text("submodule.newName"),
                AppLocalization.text("submodule.newName.placeholder")
            )

        case .url:
            (
                AppLocalization.text("submodule.editURL"),
                AppLocalization.text("submodule.editURL.message"),
                AppLocalization.text("submodule.editURL.submit"),
                AppLocalization.text("remote.url"),
                "ssh://example.com/repo.git"
            )
        }
    }

    /// 输入的说明：路径不能是绝对路径或带 “..”，地址要能被 Git 接受，名称不能与别的子模块重复。
    private var error: String {
        switch target {
        case .move:
            if trimmed.hasPrefix("/") || trimmed.split(separator: "/").contains("..") {
                return AppLocalization.text("submodule.path.invalid")
            }

            return session.submodules.items.contains { $0.path == trimmed && $0.path != submodule.path }
                ? AppLocalization.text("submodule.path.exists")
                : ""

        case .rename:
            return session.submodules.items.contains { $0.name == trimmed && $0.name != submodule.name }
                ? AppLocalization.text("submodule.error.nameInUse")
                : ""

        case .url:
            guard !trimmed.isEmpty else { return "" }

            do {
                try RepositoryReferences.validate(url: trimmed)
                return ""
            } catch {
                return ReferenceDialogRows.validationMessage(error, in: session)
            }
        }
    }

    /// 值没变时直接关闭，否则开始执行；仓库忙碌时表单保持打开。
    private func submit() {
        let started: Bool =
            switch target {
            case .move:
                trimmed == submodule.path || session.moveSubmodule(submodule, to: trimmed, renaming: renames)

            case .rename:
                trimmed == submodule.name || session.renameSubmodule(submodule, to: trimmed)

            case .url(let scope):
                session.setSubmoduleURL(trimmed, for: submodule, in: scope)
            }

        if started {
            close()
        }
    }
}
