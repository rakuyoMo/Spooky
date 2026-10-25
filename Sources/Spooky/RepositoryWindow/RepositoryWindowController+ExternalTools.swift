import AppKit
import SpookyKit

// MARK: - External Tool Actions

extension RepositoryWindowController {
    /// Repository › Open Diff Tool：工作区比较所选文件与 HEAD，历史比较所选提交的全部改动，储藏比较所选储藏的全部改动。
    @objc
    func openDiffTool() {
        switch session.activeView {
        case .workingCopy:
            session.compare(session.selectedEntries, .workingTreeToBase)

        case .history:
            guard let commit = session.history.selectedCommit else { return }

            session.openDiffTool(for: commit, files: RepositorySession.comparedFiles(session.history.changes))

        case .stashes:
            guard let stash = session.stashes.selectedStash else { return }

            session.openDiffTool(for: stash, changes: session.stashes.changes)

        default:
            return
        }
    }

    /// Working Copy › Compare ▸ Working Tree to Base：所选文件的工作区版本与 HEAD 比较。
    @objc
    func compareWorkingTreeToBase() { session.compare(session.selectedEntries, .workingTreeToBase) }

    /// Working Copy › Compare ▸ Working Tree to Index：所选文件的工作区版本与暂存区比较。
    @objc
    func compareWorkingTreeToIndex() { session.compare(session.selectedEntries, .workingTreeToIndex) }

    /// Working Copy › Compare ▸ Index to Base：所选文件的暂存区版本与 HEAD 比较。
    @objc
    func compareIndexToBase() { session.compare(session.selectedEntries, .indexToBase) }

    /// 外部比较工具各入口的可用性；动作不属于本组时为 nil。
    func externalToolAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        let working = repositoryView && session.activeView == .workingCopy

        return switch action {
        case #selector(openDiffTool):
            repositoryView && canOpenDiffTool

        case #selector(compareWorkingTreeToBase):
            working && session.canCompare(session.selectedEntries, .workingTreeToBase)

        case #selector(compareWorkingTreeToIndex):
            working && session.canCompare(session.selectedEntries, .workingTreeToIndex)

        case #selector(compareIndexToBase):
            working && session.canCompare(session.selectedEntries, .indexToBase)

        default:
            nil
        }
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// Open Diff Tool 在当前视图可用：工作区要有能比较的所选文件，历史与储藏要选中一个提交或储藏并已读出它的改动。
    private var canOpenDiffTool: Bool {
        switch session.activeView {
        case .workingCopy:
            session.canCompare(session.selectedEntries, .workingTreeToBase)

        case .history:
            session.history.selectedIDs.count == 1 && !session.history.changes.isEmpty

        case .stashes:
            session.stashes.selectedStashes.count == 1 && !session.stashes.changes.isEmpty

        default:
            false
        }
    }
}
