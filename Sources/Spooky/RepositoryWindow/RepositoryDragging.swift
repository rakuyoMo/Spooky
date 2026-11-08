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

        /// 提交变更集里的单个文件，引用为提交哈希。
        case commitFile
    }

    /// Spooky 专用粘贴板类型。
    static let type = "com.rakuyo.spooky.repository-reference"

    /// 来源仓库，用于阻止跨仓库误操作。
    let repository: RepositoryLocation

    /// 来源种类。
    let kind: Kind

    /// 完整引用名或提交哈希。
    let reference: String

    /// 储藏或提交里的文件在仓库内的相对路径；其它来源为 nil。
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

    /// 当前来源身份；换成新的来源时清掉上一次的整批来源。
    var payload: RepositoryDragPayload? = nil {
        didSet { batch = [] }
    }

    /// 一次拖动多项时的全部来源，按列表顺序；由历史列表在拖动开始时写入，单项拖动时为空。
    var batch: [RepositoryDragPayload] = []

    /// 当前拖动的全部来源：多项拖动时是整批，否则是唯一的来源。
    var payloads: [RepositoryDragPayload] {
        batch.isEmpty ? (payload.map { [$0] } ?? []) : batch
    }
}

// MARK: - RepositoryDropDestination

/// 已实现的引用落点。
enum RepositoryDropDestination: Equatable {
    /// Working Copy 行。
    case workingCopy

    /// HEAD 分支行。
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

    /// Tags 标题。
    case tags

    /// 本地分支的 “/” 文件夹，值是文件夹的完整路径。
    case branchFolder(String)

    /// 标签的 “/” 文件夹，值是文件夹的完整路径。
    case tagFolder(String)

    /// 一个远端下远端分支的 “/” 文件夹：远端名，以及文件夹在远端分支名里的路径。
    case remoteBranchFolder(String, String)

    /// Worktrees 标题。
    case worktrees
}

// MARK: - RepositoryDropTarget

/// 引用落点：拖动中把动作名加在拖动影像上，落下时执行同一个动作；需要参数的动作只打开已有的参数表单。
struct RepositoryDropTarget: ViewModifier {
    /// 当前会话。
    let session: RepositorySession

    /// 当前行的目标种类。
    let destination: RepositoryDropDestination

    /// 参数表单入口。
    let request: (RepositoryActionRequest) -> Void

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

extension RepositoryDropTarget {
    /// 引用拖动的粘贴板类型。
    private static let type = NSPasteboard.PasteboardType(RepositoryDragPayload.type)

    /// 这次拖动的有效动作：只接受同仓库的拖放，拖动的每一项都在载荷里；动作按来源、落点、⌥ 与会话解析。
    private func action(for info: any NSDraggingInfo) -> DropBadgeAction? {
        let expected = RepositoryDragContext.shared.payloads
        let items = info.draggingPasteboard.pasteboardItems?.filter { $0.types.contains(Self.type) } ?? []

        guard
            !expected.isEmpty,
            items.count == expected.count,
            let action = ReferenceDropAction(
                payloads: expected,
                destination: destination,
                alternate: NSEvent.modifierFlags.contains(.option),
                session: session
            )
        else { return nil }

        return DropBadgeAction(title: action.title) {
            // 实际载荷必须是本次拖动的来源之一
            guard
                let data = items.first?.data(forType: Self.type),
                let payload = try? JSONDecoder().decode(RepositoryDragPayload.self, from: data),
                expected.contains(where: {
                    $0.repository == payload.repository && $0.reference == payload.reference && $0.path == payload.path
                })
            else { return false }

            // 拖动会话结束后再执行，执行前核对仓库没有变化且仍可写
            Task { @MainActor in
                guard session.repository == payload.repository, session.canWrite else {
                    return
                }

                action.perform(in: session, request: request)
            }

            return true
        }
    }
}
