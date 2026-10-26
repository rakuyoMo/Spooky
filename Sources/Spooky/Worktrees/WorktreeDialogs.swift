import AppKit
import SpookyKit
import SwiftUI

// MARK: - AddWorktreeDialog

/// 新建工作树：版本与目标目录，可以分离 HEAD、强制创建与创建后打开；目标目录默认放在仓库旁边，以仓库名与版本命名。
struct AddWorktreeDialog: View {
    #warning(
        "TODO: 创建后打开的勾选项与它默认勾选、在新标签里打开，以及默认目录名里把版本的 “/” 换成 “-”，都是推断；核实方式：在 Tower 里从 feature/x 新建工作树，看对话框有没有这一项、创建后是否自动打开及在哪里打开、推出的目录名；影响新建工作树后的打开方式与默认目标目录"
    )

    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 关闭 sheet。
    let close: () -> Void

    /// 检出的版本。
    @State
    private var revision: String

    /// 目标目录的绝对路径。
    @State
    private var destination = ""

    /// 目标目录跟着版本自动推出，用户改过之后不再跟随。
    @State
    private var followsRevision = true

    /// 以分离 HEAD 检出。
    @State
    private var detach = false

    /// 分支已在别的工作树检出时仍然创建。
    @State
    private var force = false

    /// 创建后在新标签里打开。
    @AppStorage(WorktreePreferences.opensAfterCreation)
    private var opens = true

    /// 目标位置已有文件或非空目录。
    @State
    private var destinationTaken = false

    /// 正在浏览服务器上的目录。
    @State
    private var isBrowsing = false

    /// “Revision:” 与 “Destination:” 两行，以及三个勾选项。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text("worktree.add"),
            message: AppLocalization.text("worktree.add.message"),
            submitTitle: AppLocalization.text("worktree.add.submit"),
            error: error,
            isValid: !revision.isEmpty && destination.hasPrefix("/") && error.isEmpty,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(AppLocalization.text("worktree.revision")) {
                RevisionComboBox(
                    text: $revision,
                    items: session.revisionCandidates,
                    label: AppLocalization.text("worktree.revision")
                )
            }

            ReferenceDialogRows.row(AppLocalization.text("worktree.destination")) {
                HStack(spacing: 8) {
                    TextField("", text: destinationBinding)
                        .frame(minWidth: 200)
                        .accessibilityIdentifier("worktree-destination")

                    Button(AppLocalization.text("submodule.path.select"), action: selectDestination)
                        .fixedSize()
                }
            }

            ReferenceDialogRows.option(
                AppLocalization.text("worktree.detach"),
                help: AppLocalization.text("worktree.detach.help"),
                isOn: $detach
            )

            ReferenceDialogRows.option(
                AppLocalization.text("worktree.force"),
                help: AppLocalization.text("worktree.force.help"),
                isOn: $force
            )

            ReferenceDialogRows.option(AppLocalization.text("worktree.open"), help: "", isOn: $opens)
        }
        .sheet(isPresented: $isBrowsing) {
            if let host = session.repository?.host {
                ServerDirectoryBrowser(host: host, path: parentDirectory) { chosen in
                    isBrowsing = false
                    chosen.map { useDestination($0 + "/" + proposedName) }
                }
            }
        }
        .onAppear { updateProposal() }
        .onChange(of: revision) { updateProposal() }
        .task(id: destination) { await checkDestination() }
    }

    /// 创建对话框，预选给定的版本；没有给定时预选当前分支。
    init(session: RepositorySession, revision: String?, close: @escaping () -> Void) {
        self.session = session
        self.close = close
        _revision = State(initialValue: revision ?? session.status?.branch.head ?? "")
    }
}

// MARK: - Actions

extension AddWorktreeDialog {
    /// 目标目录的输入：手改之后不再跟随版本。
    private var destinationBinding: Binding<String> {
        Binding(
            get: { destination },
            set: {
                destination = $0
                followsRevision = false
            }
        )
    }

    /// 仓库所在的目录：默认目标与浏览都从这里开始。
    private var parentDirectory: String {
        let path = session.repository?.path ?? "/"
        return path.lastIndex(of: "/").map { String(path[..<$0]) }.flatMap { $0.isEmpty ? "/" : $0 } ?? "/"
    }

    /// 默认的目录名：仓库名与版本以 “-” 相连，版本里的 “/” 换成 “-”。
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

    /// 目标目录还跟随版本时按新版本重新推出。
    private func updateProposal() {
        guard followsRevision else { return }

        let parent = parentDirectory
        destination = (parent == "/" ? "" : parent) + "/" + proposedName
    }

    /// 选定的目标目录：不再跟随版本。
    private func useDestination(_ path: String) {
        destination = path
        followsRevision = false
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
            useDestination(url.path)
        }
    }

    /// 目标位置在仓库所在的机器上是否已有文件或非空目录；输入停顿后再查。
    private func checkDestination() async {
        destinationTaken = false

        guard let repository = session.repository, destination.hasPrefix("/") else {
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
            // 查不到时交给 Git 在创建时报告
        }
    }

    /// 捕获表单值后开始创建；仓库忙碌时表单保持打开。
    private func submit() {
        if session.addWorktree(at: destination, revision: revision, detach: detach, force: force, opens: opens) {
            close()
        }
    }
}

// MARK: - WorktreePathDialog

/// 选一个位置的工作树对话框：移动到新位置，或给出手动移走的工作树现在的位置以修复它。
struct WorktreePathDialog: View {
    /// 选的是什么。
    enum Target {
        /// 移动到新位置。
        case move

        /// 修复：工作树目录现在的位置。
        case repair
    }

    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 操作的工作树。
    let worktree: Worktree

    /// 选的是什么。
    let target: Target

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
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text(target == .move ? "worktree.move" : "worktree.relocate"),
            message: AppLocalization.text(target == .move ? "worktree.move.message" : "worktree.relocate.message", worktree.name),
            submitTitle: AppLocalization.text(target == .move ? "worktree.move.submit" : "worktree.relocate.submit"),
            error: "",
            isValid: path.hasPrefix("/") && path != worktree.path,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(AppLocalization.text(target == .move ? "worktree.destination" : "worktree.location")) {
                HStack(spacing: 8) {
                    TextField("", text: $path)
                        .frame(minWidth: 200)
                        .accessibilityIdentifier("worktree-path")

                    Button(AppLocalization.text("submodule.path.select"), action: select)
                        .fixedSize()
                }
            }
        }
        .sheet(isPresented: $isBrowsing) {
            if let host = session.repository?.host {
                ServerDirectoryBrowser(host: host, path: parent(of: path)) { chosen in
                    isBrowsing = false

                    // 移动时在选中的目录里保留原来的名称，修复时选中的就是工作树目录
                    chosen.map { path = target == .move ? $0 + "/" + worktree.name : $0 }
                }
            }
        }
    }

    /// 创建对话框，输入框里填上工作树原来的路径。
    init(session: RepositorySession, worktree: Worktree, target: Target, close: @escaping () -> Void) {
        self.session = session
        self.worktree = worktree
        self.target = target
        self.close = close
        _path = State(initialValue: worktree.path)
    }
}

// MARK: - Actions

extension WorktreePathDialog {
    /// 路径所在的目录。
    private func parent(of path: String) -> String {
        path.lastIndex(of: "/").map { String(path[..<$0]) }.flatMap { $0.isEmpty ? "/" : $0 } ?? "/"
    }

    /// 本机仓库：移动用存储面板起名并选位置，修复用目录面板选工作树目录；服务器仓库浏览 B 上的目录。
    private func select() {
        guard session.repository?.localURL != nil else {
            isBrowsing = true
            return
        }

        switch target {
        case .move:
            let panel = NSSavePanel()
            panel.directoryURL = URL(filePath: parent(of: path))
            panel.nameFieldStringValue = worktree.name
            panel.canCreateDirectories = true
            panel.prompt = AppLocalization.text("submodule.path.choose")

            if panel.runModal() == .OK, let url = panel.url { path = url.path }

        case .repair:
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.directoryURL = URL(filePath: parent(of: path))
            panel.prompt = AppLocalization.text("submodule.path.choose")

            if panel.runModal() == .OK, let url = panel.url { path = url.path }
        }
    }

    /// 开始移动或修复；仓库忙碌时表单保持打开。
    private func submit() {
        let started =
            switch target {
            case .move: session.moveWorktree(worktree, to: path)
            case .repair: session.repairWorktree(at: path)
            }

        if started {
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

    /// 说明与强制删除的勾选项。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text("worktree.remove"),
            message: AppLocalization.text("worktree.remove.message", worktree.name),
            submitTitle: AppLocalization.text("worktree.remove.submit"),
            error: "",
            isValid: true,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.option(
                AppLocalization.text("worktree.remove.force"),
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
