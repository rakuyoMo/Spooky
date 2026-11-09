import AppKit
import SpookyKit
import SwiftUI

// MARK: - StashDropAction

/// 储藏或储藏中的文件拖到工作区或 HEAD 分支时的动作。
enum StashDropAction: Sendable {
    /// 应用整个储藏，打开应用储藏的对话框并预选它。
    case apply(StashEntry)

    /// 只把储藏里的这个文件套用到工作区。
    case applyFile(StashFileChange, StashEntry)

    /// 悬停时显示的动作名。
    var titleKey: String {
        switch self {
        case .apply: "stash.apply"
        case .applyFile: "stash.applyFile"
        }
    }

    /// 只认储藏来源与 Working Copy 或 HEAD 分支落点；按住 ⌥、储藏或文件已不在当前列表中、或当前不可应用时为 nil。
    ///
    /// - Parameter alternate: 是否按住 ⌥。
    @MainActor
    init?(
        payload: RepositoryDragPayload,
        destination: RepositoryDropDestination,
        alternate: Bool,
        session: RepositorySession
    ) {
        guard
            [.workingCopy, .head].contains(destination),
            !alternate,
            let stash = session.stashes.entries.first(where: { $0.id == payload.reference }),
            session.canApply(stash)
        else { return nil }

        switch payload.kind {
        case .stash:
            self = .apply(stash)

        case .stashFile:
            // 文件只能来自当前显示的储藏详情
            guard
                session.stashes.selectedStash?.id == stash.id,
                let change = session.stashes.changes.first(where: { $0.id == payload.path })
            else { return nil }

            self = .applyFile(change, stash)

        default:
            return nil
        }
    }

    /// 交给会话的储藏入口执行。
    @MainActor
    func perform(in session: RepositorySession) {
        switch self {
        case .apply(let stash): session.requestApplyStash(stash)
        case .applyFile(let change, let stash): session.applyStashFile(change, from: stash)
        }
    }
}

// MARK: - StashesDropTarget

/// 侧边栏 Stashes 项的落点：工作区文件拖到这里打开部分储藏的对话框，所选的未跟踪文件一并储藏。
struct StashesDropTarget: ViewModifier {
    /// 工作区文件列表写入粘贴板的应用内载荷。
    struct Payload: Codable, Sendable {
        /// 仅本进程可见的粘贴板类型。
        static let type = "com.rakuyo.spooky.working-copy-file"

        /// 来源仓库，用于阻止跨仓库误操作。
        let repository: RepositoryLocation

        /// 仓库内的相对路径。
        let path: String
    }

    /// 当前会话。
    let session: RepositorySession

    /// 读出拖动项中属于指定仓库的路径；格式不符或来自其它仓库的项被忽略。
    ///
    /// - Parameters:
    ///   - items: 拖动的粘贴板项。
    ///   - repository: 落点所在的仓库。
    static func paths(from items: [NSPasteboardItem], in repository: RepositoryLocation) -> [String] {
        items.compactMap { item in
            guard
                let data = item.data(forType: type),
                let payload = try? JSONDecoder().decode(Payload.self, from: data),
                payload.repository == repository
            else { return nil }

            return payload.path
        }
    }

    /// 落点盖在行上，点击穿透给行。
    func body(content: Content) -> some View {
        content
            .overlay {
                RepositoryDropView(type: Self.type) { action(for: $0) }
                    .allowsHitTesting(false)
            }
    }
}

// MARK: - Private

extension StashesDropTarget {
    /// 工作区文件拖动的粘贴板类型。
    private static let type = NSPasteboard.PasteboardType(Payload.type)

    /// 有工作区文件且仓库可以储藏时是部分储藏；落下后按当前状态把路径换成工作区条目，
    /// 仓库已变化或文件已没有改动时放弃。
    private func action(for info: any NSDraggingInfo) -> DropBadgeAction? {
        let items = info.draggingPasteboard.pasteboardItems?.filter { $0.types.contains(Self.type) } ?? []

        guard !items.isEmpty, session.canSaveStash, let repository = session.repository else {
            return nil
        }

        return DropBadgeAction(title: AppLocalization.text("stash.stashItemsDrop")) {
            let paths = Set(Self.paths(from: items, in: repository))

            // 拖动会话结束后再打开对话框
            Task { @MainActor in
                guard session.repository == repository else {
                    return
                }

                let entries = session.status?.entries.filter { paths.contains($0.path) } ?? []

                guard !entries.isEmpty else {
                    return
                }

                session.requestSaveStash(snapshot: false, entries: entries)
            }

            return true
        }
    }
}
