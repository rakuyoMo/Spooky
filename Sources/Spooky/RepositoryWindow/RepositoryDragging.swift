import AppKit
import SpookyKit
import SwiftUI

// MARK: - RepositoryDragPayload

/// 应用内部的分支与提交拖动，不接受文件路径作为 Git 引用。
struct RepositoryDragPayload: Codable, Sendable {
    /// 来源种类决定可用目标。
    enum Kind: String, Codable, Sendable {
        /// 本地分支。
        case local

        /// 远端跟踪分支。
        case remote

        /// 历史提交。
        case commit

        /// 储藏，引用为储藏提交的哈希。
        case stash

        /// 储藏详情中的单个文件，引用为储藏提交的哈希。
        case stashFile

        /// 标签，引用为完整的标签名。
        case tag
    }

    /// Spooky 专用粘贴板类型。
    static let type = "com.rakuyo.spooky.repository-reference"

    /// 来源仓库，用于阻止跨仓库误操作。
    let repository: RepositoryLocation

    /// 来源种类。
    let kind: Kind

    /// 完整引用名或提交哈希。
    let reference: String

    /// 储藏文件在仓库内的相对路径；其它来源为 nil。
    var path: String? = nil

    /// 数据仅供应用内部拖放，悬停期间共享来源来显示动作名。
    @MainActor
    func provider() -> NSItemProvider {
        RepositoryDragContext.shared.payload = self
        let provider = NSItemProvider()
        let data = try? JSONEncoder().encode(self)
        provider.registerDataRepresentation(
            forTypeIdentifier: Self.type,
            visibility: .ownProcess
        ) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }
}

// MARK: - RepositoryDragContext

/// 当前拖动来源只用于同步计算悬停动作。
@MainActor
final class RepositoryDragContext {
    /// 应用内一次拖动共用一份来源。
    static let shared = RepositoryDragContext()

    /// 当前来源身份。
    var payload: RepositoryDragPayload? = nil
}

// MARK: - RepositoryDropDestination

/// 已实现的引用落点。
enum RepositoryDropDestination {
    /// 工作区或 HEAD。
    case head

    /// Branches 标题。
    case branches

    /// 发布到指定远端。
    case remote(String)

    /// 推送到指定远端分支。
    case remoteBranch(String, String)

    /// HEAD 以外的本地分支，该行不接受拖动。
    case localBranch

    /// Pinned 标题。
    case pinned

    /// Archived Branches 标题。
    case archived
}

// MARK: - RepositoryDropTarget

/// 在目标行展示动作名，落下只打开已有参数表单。
struct RepositoryDropTarget: ViewModifier {
    /// 当前会话。
    let session: RepositorySession

    /// 当前行的目标种类。
    let destination: RepositoryDropDestination

    /// 参数表单入口。
    let request: (RepositoryActionRequest) -> Void

    /// 悬停提示文字。
    @State
    private var label: String?

    /// SwiftUI 落点高亮承载当前动作标签。
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
            .onDrop(
                of: [RepositoryDragPayload.type],
                delegate: ReferenceDropDelegate(
                    session: session,
                    destination: destination,
                    request: request,
                    label: $label
                )
            )
    }
}

// MARK: - ReferenceDropDelegate

/// 来源、目标与修饰键共用一张动作表，未交付的变体明确拒绝。
private struct ReferenceDropDelegate: DropDelegate {
    /// 当前仓库及写入状态。
    let session: RepositorySession

    /// 落点身份。
    let destination: RepositoryDropDestination

    /// 对话框入口。
    let request: (RepositoryActionRequest) -> Void

    /// 当前动作文字。
    @Binding
    var label: String?

    /// 本阶段只接受同仓库的单项引用或储藏拖放。
    func validateDrop(info: DropInfo) -> Bool {
        info.itemProviders(for: [RepositoryDragPayload.type]).count == 1
            && (action() != nil || stashAction() != nil || flagAction() != nil)
    }

    /// 修饰键变化时同步更新动作提示。
    func dropUpdated(info _: DropInfo) -> DropProposal? {
        let action = action()
        let stash = stashAction()
        let flag = flagAction()
        label = action.map { AppLocalization.text($0.kind.rawValue) }
            ?? stash.map { AppLocalization.text($0.titleKey) }
            ?? flag.map { AppLocalization.text($0.titleKey) }
        return DropProposal(operation: action == nil && stash == nil && flag == nil ? .forbidden : .copy)
    }

    /// 离开落点后移除提示。
    func dropExited(info _: DropInfo) { label = nil }

    /// 核对实际载荷后打开表单，异步期间仓库变化则放弃。
    func performDrop(info: DropInfo) -> Bool {
        label = nil
        let action = action()
        let stash = stashAction()
        let flag = flagAction()
        guard
            validateDrop(info: info),
            let expected = RepositoryDragContext.shared.payload,
            let provider = info.itemProviders(for: [RepositoryDragPayload.type]).first
        else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: RepositoryDragPayload.type) { data, _ in
            guard
                let data, let payload = try? JSONDecoder().decode(RepositoryDragPayload.self, from: data),
                payload.repository == expected.repository, payload.reference == expected.reference,
                payload.path == expected.path
            else { return }
            Task { @MainActor in
                guard session.repository == payload.repository, session.canWrite else { return }

                // 储藏、置顶与归档直接交给会话，其余动作打开参数表单
                if let action {
                    request(action)
                } else if let stash {
                    stash.perform(in: session)
                } else {
                    flag?.perform(in: session)
                }
            }
        }
        return true
    }

    /// 储藏或储藏文件拖到工作区与 HEAD 分支时的动作；可用条件与菜单和右键菜单相同。
    private func stashAction() -> StashDropAction? {
        guard
            let payload = RepositoryDragContext.shared.payload,
            payload.repository == session.repository
        else { return nil }

        return StashDropAction(payload: payload, destination: destination, session: session)
    }

    /// 本地分支拖到 Pinned 或 Archived Branches 标题时的动作；可用条件与右键菜单相同。
    private func flagAction() -> BranchFlagDropAction? {
        guard
            let payload = RepositoryDragContext.shared.payload,
            payload.repository == session.repository
        else { return nil }

        return BranchFlagDropAction(payload: payload, destination: destination, session: session)
    }

    /// 每个映射都指向实际可用的业务动作，可用条件与菜单和右键菜单相同。
    private func action() -> RepositoryActionRequest? {
        guard
            let payload = RepositoryDragContext.shared.payload,
            payload.repository == session.repository
        else { return nil }
        let alternate = NSEvent.modifierFlags.contains(.option)
        let source = session.history.branches.first { $0.id == payload.reference }

        switch (payload.kind, destination) {
        case (.local, .head):
            guard !alternate, let source, session.canMerge(source) else { return nil }
            return RepositoryActionRequest(kind: .merge, reference: payload.reference)

        case (.remote, .head):
            guard !alternate, let source, session.canPull(from: source) else { return nil }
            return RepositoryActionRequest(kind: .pull, reference: payload.reference)

        case (.local, .branches), (.commit, .branches), (.tag, .branches):
            guard !alternate, session.canCreateBranchFromReference else { return nil }
            return RepositoryActionRequest(kind: .create, reference: payload.reference)

        case (.remote, .branches):
            guard let source, session.canTrack(source) else { return nil }
            return RepositoryActionRequest(kind: .track, reference: payload.reference)

        case (.local, .remote(let remote)):
            guard let source, session.canPush(source) else { return nil }
            return RepositoryActionRequest(
                kind: .publish,
                remote: remote,
                localBranch: String(payload.reference.dropFirst(11))
            )

        case (.local, .remoteBranch(let remote, let reference)):
            guard let source, session.canPush(source) else { return nil }
            return RepositoryActionRequest(
                kind: .push,
                reference: reference,
                remote: remote,
                localBranch: String(payload.reference.dropFirst(11))
            )

        default: return nil
        }
    }
}
