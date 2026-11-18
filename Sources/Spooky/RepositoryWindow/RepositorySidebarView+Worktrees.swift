import AppKit
import SpookyKit
import SwiftUI

// MARK: - Worktrees

extension RepositorySidebarView {
    /// 工作树行的身份前缀：选中工作树时主视图显示它的详情。
    static let worktreeRowPrefix = "worktree:"

    /// Worktrees 分组：本窗口仓库之外的工作树，按名称排列，过滤时按路径匹配；标题接受本地分支拖入以新建工作树。
    var worktreeGroup: some View {
        sidebarSection(.worktrees) {
            ForEach(filteredWorktrees) {
                worktreeRow($0)
            }
        } header: {
            groupHeader("worktree.group", destination: .worktrees)
                .contextMenu {
                    Button(AppLocalization.text("worktree.add.menu")) { session.requestWorktree(.add(revision: nil)) }
                        .disabled(!session.canWrite)
                }
        }
    }

    /// 分组里列出的工作树：过滤时只留路径匹配的。
    var filteredWorktrees: [Worktree] {
        session.worktrees.others.filter { !isFiltering || SidebarRefTree.matches($0.path, filter: filterText) }
    }

    /// 悬停提示：工作树名与它所在的位置；失效的工作树同样写出，服务器仓库的路径带主机前缀。
    ///
    /// - Parameters:
    ///   - worktree: 工作树。
    ///   - repository: 窗口显示的仓库。
    static func tooltip(of worktree: Worktree, in repository: RepositoryLocation?) -> String {
        let path = repository?.host.map { $0 + ":" + worktree.path } ?? worktree.path

        return AppLocalization.text("worktree.tooltip", worktree.name) + "\n"
            + AppLocalization.text("worktree.tooltip.path", path)
    }

    /// 工作树行：单击显示详情，双击在本窗口打开，失效时响铃。
    /// 失效时行的右端多一个告警图标。
    private func worktreeRow(_ worktree: Worktree) -> some View {
        HStack(spacing: 4) {
            Label {
                Text(worktree.name)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "rectangle.on.rectangle")
            }

            if !worktree.isValid {
                Spacer(minLength: 4)

                // 用次要文字的颜色画，所在行被选中时随之反白
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .accessibilityLabel(AppLocalization.text("worktree.warning"))
            }
        }
        .help(Self.tooltip(of: worktree, in: session.repository))
        .tag(Self.worktreeRowPrefix + worktree.path)
        .onTapGesture(count: 2) { session.open(worktree, in: .currentWindow) }
        .contextMenu { WorktreeMenu(session: session, worktree: worktree, branch: nil) }
    }
}

// MARK: - BranchWorktreeMenuItems

/// 本地分支右键菜单里与工作树有关的项：分支已在别的工作树检出时是打开、删除那个工作树，否则是在新工作树里检出。
struct BranchWorktreeMenuItems: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 本地分支。
    let branch: RepositoryReference

    /// 检出项之后的一组；已在别的工作树检出时以不可点的一行说明开头，写出那个工作树的名字。
    var body: some View {
        if let worktree = session.worktrees.branchWorktrees[branch.id] {
            Text(AppLocalization.text("worktree.checkedOutIn", worktree.name))

            WorktreeMenu(session: session, worktree: worktree, branch: branch.name)
        } else {
            Button(AppLocalization.text("worktree.checkoutBranch", branch.name)) {
                session.requestWorktree(.add(revision: branch.name))
            }
            .disabled(!session.canWrite)
        }
    }
}

// MARK: - WorktreeMenu

/// 工作树的右键菜单：在本窗口、新标签或新窗口打开，删除、移动与修复，在 Finder 或终端中打开；
/// 从分支菜单打开时各项写出分支名，且不列移动与修复。
struct WorktreeMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 工作树。
    let worktree: Worktree

    /// 从分支菜单打开时的分支名；为 nil 时是工作树自己的菜单。
    let branch: String?

    /// 打开、管理与系统三组，组间以分隔线隔开。
    var body: some View {
        Button(title("worktree.open.current", "worktree.branch.open")) { session.open(worktree, in: .currentWindow) }
            .disabled(!worktree.isValid)

        Button(title("worktree.open.newTab", "worktree.branch.openNewTab")) { session.open(worktree, in: .newTab) }
            .disabled(!worktree.isValid)

        Button(title("worktree.open.newWindow", "worktree.branch.openNewWindow")) {
            session.open(worktree, in: .newWindow)
        }
        .disabled(!worktree.isValid)

        if branch == nil {
            Divider()
        }

        Button(title("worktree.remove.menu", "worktree.branch.remove")) { session.requestWorktree(.remove(worktree)) }
            .disabled(!session.canRemove(worktree))

        if branch == nil {
            Button(AppLocalization.text("worktree.move.menu")) { session.requestWorktree(.move(worktree)) }
                .disabled(!session.canMove(worktree))

            // 修复只在工作树失效时列出
            if !worktree.isValid {
                Button(AppLocalization.text("worktree.repair.menu")) { session.requestWorktree(.repair(worktree)) }
                    .disabled(!session.canRepair(worktree))
            }
        }

        Divider()

        systemItems
    }

    /// 工作树在 Finder 中显示，服务器上的按挂载位置打开；复制路径，服务器上的带主机前缀；都可以在终端中打开。
    @ViewBuilder
    private var systemItems: some View {
        let location = session.location(of: worktree)

        Button(title("worktree.reveal", "worktree.branch.reveal")) {
            if let url = session.finderURL(of: worktree) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        .disabled(!session.canShowInFinder(worktree))
        .help(session.finderUnavailableTip(of: worktree) ?? "")

        Button(AppLocalization.text("action.copyPath")) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(location?.displayPath ?? worktree.path, forType: .string)
        }
        .disabled(location == nil)

        Button(title("action.openTerminal", "worktree.branch.terminal")) {
            if let location { session.onOpenInTerminal?(location) }
        }
        .disabled(location == nil)
    }

    /// 工作树自己的菜单用不带名字的标题，分支菜单里写出分支名。
    private func title(_ key: String, _ branchKey: String) -> String {
        branch.map { AppLocalization.text(branchKey, $0) } ?? AppLocalization.text(key)
    }
}
