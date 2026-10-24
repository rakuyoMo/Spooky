import AppKit
import SpookyKit

// MARK: - BranchFlagDropAction

/// 本地分支拖到 Pinned 或 Archived Branches 标题时的动作；不打开对话框，直接写入。
enum BranchFlagDropAction {
    /// 置顶拖动的分支。
    case pin(RepositoryReference)

    /// 归档分支；拖动的分支在多选中时归档整个选区里尚未归档的分支。
    case archive([RepositoryReference])

    /// 悬停时显示的动作名。
    var titleKey: String {
        switch self {
        case .pin: "branch.pin"
        case .archive: "branch.archive"
        }
    }

    /// 只认本地分支来源与两个分组标题；已经置顶或全部已归档、或当前不可写时为 nil。
    @MainActor
    init?(payload: RepositoryDragPayload, destination: RepositoryDropDestination, session: RepositorySession) {
        guard
            payload.kind == .local,
            !NSEvent.modifierFlags.contains(.option),
            let snapshot = session.history.snapshot,
            let source = session.history.branches.first(where: { $0.id == payload.reference })
        else { return nil }

        switch destination {
        case .pinned:
            guard !snapshot.metadata(for: source.id).isPinned, session.canSetPinned([source]) else {
                return nil
            }

            self = .pin(source)

        case .archived:
            let selected = session.history.branches.filter {
                $0.isLocal && session.history.selectedReferences.contains($0.id)
            }
            let branches = (selected.contains(source) ? selected : [source])
                .filter { !snapshot.metadata(for: $0.id).isArchived }

            guard session.canSetArchived(branches) else {
                return nil
            }

            self = .archive(branches)

        default:
            return nil
        }
    }

    /// 交给会话写入。
    @MainActor
    func perform(in session: RepositorySession) {
        switch self {
        case .pin(let branch): session.setPinned(true, branches: [branch])
        case .archive(let branches): session.setArchived(true, branches: branches)
        }
    }
}
