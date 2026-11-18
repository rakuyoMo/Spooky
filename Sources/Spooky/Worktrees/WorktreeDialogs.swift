import AppKit
import SpookyKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - AddWorktreeDialog

/// 新建工作树：版本与目标目录，可以分离 HEAD 与强制创建；目标目录默认放在仓库旁边，以仓库名与版本命名。
struct AddWorktreeDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 关闭 sheet。
    let close: () -> Void

    /// 检出的版本。
    @State
    private var revision: String

    /// 目标目录的绝对路径；打开时为空。
    @State
    private var destination = ""

    /// 以分离 HEAD 检出。
    @State
    private var detach = false

    /// 分支已在别的工作树检出时仍然创建。
    @State
    private var force = false

    /// 目标位置已有文件或非空目录。
    @State
    private var destinationTaken = false

    /// 正在浏览服务器上的目录。
    @State
    private var isBrowsing = false

    /// “Revision:” 与 “Destination:” 两行、分离 HEAD 的勾选项，以及默认收起的 Options 里的强制创建。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("worktree.add"),
            message: AppLocalization.text("worktree.add.message"),
            width: 486,
            submitTitle: AppLocalization.text("worktree.add.submit"),
            error: error,
            isValid: !revision.isEmpty && destination.hasPrefix("/") && error.isEmpty,
            cancel: close,
            submit: submit
        ) {
            RepositoryDialogRows.row(AppLocalization.text("worktree.revision")) {
                RevisionComboBox(
                    text: $revision,
                    items: session.revisionCandidates,
                    label: AppLocalization.text("worktree.revision")
                )
            }

            RepositoryDialogRows.row(AppLocalization.text("worktree.destination")) {
                HStack(spacing: 8) {
                    TextField("", text: $destination)
                        .accessibilityIdentifier("worktree-destination")

                    Button(AppLocalization.text("submodule.path.select"), action: selectDestination)
                        .fixedSize()
                }
            }

            DialogFormOption(
                title: AppLocalization.text("worktree.detach"),
                help: AppLocalization.text("worktree.detach.help"),
                isOn: $detach
            )
        } options: {
            DialogFormOption(
                title: AppLocalization.text("worktree.force"),
                help: AppLocalization.text("worktree.force.help"),
                isOn: $force
            )
        }
        .sheet(isPresented: $isBrowsing) {
            if let host = session.repository?.host {
                ServerDirectoryBrowser(host: host, path: parentDirectory) { chosen in
                    isBrowsing = false
                    chosen.map { destination = $0 + "/" + proposedName }
                }
            }
        }
        .task(id: destination) { await checkDestination() }
    }

    /// 创建对话框，预选给定的版本；没有给定时版本留空。
    init(session: RepositorySession, revision: String?, close: @escaping () -> Void) {
        self.session = session
        self.close = close
        _revision = State(initialValue: revision ?? "")
    }
}

// MARK: - Actions

extension AddWorktreeDialog {
    /// 仓库所在的目录：选择目标时从这里开始。
    private var parentDirectory: String {
        let path = session.repository?.path ?? "/"
        return path.lastIndex(of: "/").map { String(path[..<$0]) }.flatMap { $0.isEmpty ? "/" : $0 } ?? "/"
    }

    /// 选择目标时建议的目录名：仓库名与版本以 “-” 相连，版本里的 “/” 换成 “-”。
    private var proposedName: String {
        let name = session.repository?.name ?? "worktree"
        let suffix = revision.replacingOccurrences(of: "/", with: "-")
        return suffix.isEmpty ? name : name + "-" + suffix
    }

    /// 版本与目标目录的说明。
    private var error: String {
        if session.history.snapshot?.references.isEmpty ?? false, session.status?.branch.oid == nil {
            return AppLocalization.text("worktree.noRefs")
        }

        if destinationTaken {
            let name = destination.split(separator: "/").last.map(String.init) ?? destination
            return AppLocalization.text("worktree.destination.exists", name)
        }

        // 本地分支已在某个工作树检出时，Git 只在分离 HEAD 或强制时才创建
        if !detach, !force, session.worktrees.items.contains(where: { $0.branch == "refs/heads/" + revision }) {
            return AppLocalization.text("worktree.branchInUse", revision)
        }

        return ""
    }

    /// 本机仓库用系统的存储面板起名并选位置，服务器仓库浏览 B 上的目录，在选中的目录里以默认名称新建。
    private func selectDestination() {
        guard session.repository?.localURL != nil else {
            isBrowsing = true
            return
        }

        let panel = NSSavePanel()
        panel.directoryURL = URL(filePath: parentDirectory)
        panel.nameFieldStringValue = proposedName
        panel.canCreateDirectories = true
        panel.prompt = AppLocalization.text("submodule.path.choose")

        if panel.runModal() == .OK, let url = panel.url {
            destination = url.path
        }
    }

    /// 目标位置在仓库所在的机器上是否已有文件或非空目录；输入停顿后再查。
    private func checkDestination() async {
        // 输入停顿期间保留上一次的结果，新结果出来后一次替换；不是绝对路径时不查
        guard let repository = session.repository, destination.hasPrefix("/") else {
            destinationTaken = false
            return
        }

        let location: RepositoryLocation =
            switch repository {
            case .local: .local(path: destination)
            case .remote(let host, _): .remote(host: host, path: destination)
            }

        do {
            try await Task.sleep(for: .milliseconds(200))
            let status = try await HostDirectories.status(of: location)
            try Task.checkCancellation()
            destinationTaken = status.exists && !status.isEmpty
        } catch {
            // 查不到时交给 Git 在创建时报告；被新的输入取消时由新的检查给出结果
            if !Task.isCancelled {
                destinationTaken = false
            }
        }
    }

    /// 捕获表单值后开始创建；仓库忙碌时表单保持打开。
    private func submit() {
        if session.addWorktree(at: destination, revision: revision, detach: detach, force: force) {
            close()
        }
    }
}

// MARK: - WorktreePathDialog

/// 移动工作树：选新位置，选中的目录里保留工作树原来的名称。
struct WorktreePathDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 操作的工作树。
    let worktree: Worktree

    /// 关闭 sheet。
    let close: () -> Void

    /// 输入框里的绝对路径，打开时是工作树原来的路径。
    @State
    private var path: String

    /// 正在浏览服务器上的目录。
    @State
    private var isBrowsing = false

    /// 一行路径与选择按钮。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("worktree.move"),
            message: AppLocalization.text("worktree.move.message", worktree.name),
            submitTitle: AppLocalization.text("worktree.move.submit"),
            error: "",
            isValid: path.hasPrefix("/") && path != worktree.path,
            cancel: close,
            submit: submit
        ) {
            RepositoryDialogRows.row(AppLocalization.text("worktree.destination")) {
                HStack(spacing: 8) {
                    TextField("", text: $path)
                        .accessibilityIdentifier("worktree-path")

                    Button(AppLocalization.text("submodule.path.select"), action: select)
                        .fixedSize()
                }
            }
        }
        .sheet(isPresented: $isBrowsing) {
            if let host = session.repository?.host {
                ServerDirectoryBrowser(host: host, path: Self.parent(of: path)) { chosen in
                    isBrowsing = false

                    // 在选中的目录里保留原来的名称
                    chosen.map { path = $0 + "/" + worktree.name }
                }
            }
        }
    }

    /// 创建对话框，输入框里填上工作树原来的路径。
    init(session: RepositorySession, worktree: Worktree, close: @escaping () -> Void) {
        self.session = session
        self.worktree = worktree
        self.close = close
        _path = State(initialValue: worktree.path)
    }

    /// 路径所在的目录。
    static func parent(of path: String) -> String {
        path.lastIndex(of: "/").map { String(path[..<$0]) }.flatMap { $0.isEmpty ? "/" : $0 } ?? "/"
    }
}

// MARK: - Actions

extension WorktreePathDialog {
    /// 本机仓库用存储面板起名并选位置，服务器仓库浏览 B 上的目录。
    private func select() {
        guard session.repository?.localURL != nil else {
            isBrowsing = true
            return
        }

        let panel = NSSavePanel()
        panel.directoryURL = URL(filePath: Self.parent(of: path))
        panel.nameFieldStringValue = worktree.name
        panel.canCreateDirectories = true
        panel.prompt = AppLocalization.text("submodule.path.choose")

        if panel.runModal() == .OK, let url = panel.url { path = url.path }
    }

    /// 开始移动；仓库忙碌时表单保持打开。
    private func submit() {
        if session.moveWorktree(worktree, to: path) {
            close()
        }
    }
}

// MARK: - RelocateWorktreeDialog

/// 修复工作树：在弹出菜单里选工作树目录现在的位置，选好后核对它是不是这个仓库的这个工作树，核对通过才能修复。
struct RelocateWorktreeDialog: View {
    /// 位置菜单里 “Select Destination…” 一项的标识，不是任何路径。
    private static let chooseTag = "\u{0}choose"

    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 失效的工作树。
    let worktree: Worktree

    /// 关闭 sheet。
    let close: () -> Void

    /// 选中的目录，仓库所在机器上的绝对路径；打开时是工作树登记的路径。
    @State
    private var path: String

    /// 选中目录的核对结果：还在核对时为 nil，可以修复时为空，否则是错误区的说明。
    @State
    private var problem: String?

    /// 正在浏览服务器上的目录。
    @State
    private var isBrowsing = false

    /// “Location:” 一行；选中的目录与工作树登记的路径相同时不能修复，也不写说明。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("worktree.relocate"),
            message: AppLocalization.text("worktree.relocate.message", worktree.name),
            submitTitle: AppLocalization.text("worktree.relocate.submit"),
            error: isRegisteredPath ? "" : problem ?? "",
            isValid: !isRegisteredPath && (problem?.isEmpty ?? false),
            cancel: close,
            submit: submit
        ) {
            RepositoryDialogRows.row(AppLocalization.text("worktree.location")) {
                locationPicker
            }
        }
        .sheet(isPresented: $isBrowsing) {
            if let host = session.repository?.host {
                ServerDirectoryBrowser(host: host, path: WorktreePathDialog.parent(of: worktree.path)) { chosen in
                    isBrowsing = false
                    chosen.map { path = $0 }
                }
            }
        }
        .task(id: path) {
            await check()
        }
    }

    /// 填满输入列的位置弹出菜单：选中的目录、分隔线与 “Select Destination…”；
    /// 选最后一项时打开目录选择，菜单仍停在原来的项上。
    private var locationPicker: some View {
        Picker(
            "",
            selection: Binding(
                get: { path },
                set: { $0 == Self.chooseTag ? selectDestination() : () }
            )
        ) {
            Label {
                Text(session.repository?.host == nil ? HomePath.abbreviated(path) : path)
            } icon: {
                Image(nsImage: Self.folderIcon)
            }
            .tag(path)

            Divider()

            Text(AppLocalization.text("submodule.path.select"))
                .tag(Self.chooseTag)
        }
        .labelsHidden()
        .buttonSizing(.flexible)
        .accessibilityLabel(AppLocalization.text("worktree.location"))
        .accessibilityIdentifier("worktree-path")
    }

    /// 创建对话框，位置菜单选中工作树登记的路径。
    init(session: RepositorySession, worktree: Worktree, close: @escaping () -> Void) {
        self.session = session
        self.worktree = worktree
        self.close = close
        _path = State(initialValue: worktree.path)
    }
}

// MARK: - Actions

extension RelocateWorktreeDialog {
    /// 菜单里选中目录前面的 16 × 16 文件夹图标。
    private static var folderIcon: NSImage {
        let icon = NSWorkspace.shared.icon(for: .folder)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }

    /// 选中的就是工作树登记的路径。
    private var isRegisteredPath: Bool {
        path == worktree.path
    }

    /// 核对选中的目录；选中的目录变了时上一次核对随任务取消。
    private func check() async {
        problem = nil

        guard !isRegisteredPath else {
            return
        }

        let result = await session.repairProblem(of: worktree, at: path)

        guard !Task.isCancelled else {
            return
        }

        problem = result ?? ""
    }

    /// 本机仓库用目录面板，以 sheet 挂在对话框上；服务器仓库浏览 B 上的目录。
    private func selectDestination() {
        guard session.repository?.localURL != nil else {
            isBrowsing = true
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = URL(filePath: WorktreePathDialog.parent(of: worktree.path))
        panel.title = AppLocalization.text("worktree.relocate.panel")
        panel.prompt = AppLocalization.text("submodule.path.choose")

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let url = panel.url { path = url.path }
        }

        guard let window = NSApp.keyWindow else {
            finish(panel.runModal())
            return
        }

        panel.beginSheetModal(for: window, completionHandler: finish)
    }

    /// 开始修复；仓库忙碌时表单保持打开。
    private func submit() {
        if session.repairWorktree(at: path) {
            close()
        }
    }
}

// MARK: - RemoveWorktreeDialog

/// 删除工作树：普通删除遇到改动时 Git 拒绝，勾选强制删除后连同未提交的改动一起删除。
struct RemoveWorktreeDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 要删除的工作树。
    let worktree: Worktree

    /// 关闭 sheet。
    let close: () -> Void

    /// 强制删除。
    @State
    private var force = false

    /// 说明与强制删除的勾选项；勾选项紧贴头部，下方留 20。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("worktree.remove"),
            message: AppLocalization.text("worktree.remove.message", worktree.name),
            formInsets: (0, 20),
            submitTitle: AppLocalization.text("worktree.remove.submit"),
            error: "",
            isValid: true,
            cancel: close,
            submit: submit
        ) {
            DialogFormOption(
                title: AppLocalization.text("worktree.remove.force"),
                help: AppLocalization.text("worktree.remove.force.help"),
                isOn: $force
            )
        }
    }

    /// 开始删除；仓库忙碌时表单保持打开。
    private func submit() {
        if session.removeWorktree(worktree, force: force) {
            close()
        }
    }
}
