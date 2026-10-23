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

    /// 只认储藏来源与工作区或 HEAD 分支落点；储藏或文件已不在当前列表中、或当前不可应用时为 nil。
    @MainActor
    init?(payload: RepositoryDragPayload, destination: RepositoryDropDestination, session: RepositorySession) {
        guard
            case .head = destination,
            !NSEvent.modifierFlags.contains(.option),
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

    /// 悬停时的动作名。
    @State
    private var label: String?

    /// 读出拖动项中属于指定仓库的路径；格式不符或来自其它仓库的项被忽略。
    static func paths(from providers: [NSItemProvider], in repository: RepositoryLocation) async -> [String] {
        /// 读取一个拖动项的数据，失败时为 nil。
        func load(_ provider: NSItemProvider) async -> Data? {
            await withCheckedContinuation { continuation in
                _ = provider.loadDataRepresentation(forTypeIdentifier: Payload.type) { data, _ in
                    continuation.resume(returning: data)
                }
            }
        }

        var paths: [String] = []

        for provider in providers {
            guard
                let data = await load(provider),
                let payload = try? JSONDecoder().decode(Payload.self, from: data),
                payload.repository == repository
            else { continue }

            paths.append(payload.path)
        }

        return paths
    }

    /// 与引用落点相同的动作标签。
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .trailing) {
                if let label {
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(.white, in: RoundedRectangle(cornerRadius: 4))
                        .allowsHitTesting(false)
                }
            }
            .onDrop(of: [Payload.type], delegate: FileDropDelegate(session: session, label: $label))
    }
}

// MARK: - FileDropDelegate

/// 工作区文件的落点规则：仓库可以储藏时才接受，落下后核对仓库与文件再打开对话框。
private struct FileDropDelegate: DropDelegate {
    /// 当前会话。
    let session: RepositorySession

    /// 悬停时的动作名。
    @Binding
    var label: String?

    /// 有工作区文件且仓库可写时接受。
    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [StashesDropTarget.Payload.type]) && session.canSaveStash
    }

    /// 悬停时显示部分储藏的动作名。
    func dropUpdated(info: DropInfo) -> DropProposal? {
        let valid = validateDrop(info: info)
        label = valid ? AppLocalization.text("stash.stashItemsDrop") : nil
        return DropProposal(operation: valid ? .copy : .forbidden)
    }

    /// 离开落点后移除提示。
    func dropExited(info _: DropInfo) { label = nil }

    /// 路径按当前状态换成工作区条目；异步期间仓库变化或文件已没有改动则放弃。
    func performDrop(info: DropInfo) -> Bool {
        label = nil
        guard validateDrop(info: info), let repository = session.repository else { return false }
        let providers = info.itemProviders(for: [StashesDropTarget.Payload.type])

        Task { @MainActor in
            let paths = Set(await StashesDropTarget.paths(from: providers, in: repository))
            guard session.repository == repository else { return }

            let entries = session.status?.entries.filter { paths.contains($0.path) } ?? []
            guard !entries.isEmpty else { return }

            session.requestSaveStash(snapshot: false, entries: entries)
        }

        return true
    }
}
