import SpookyKit

// MARK: - ReferenceDropAction

/// 侧边栏引用落点上的一次拖放动作：按来源、落点、⌥ 与会话解析，拖动影像上写它的动作名，落下时执行同一个动作。
///
/// 来源、落点与修饰键共用一张动作表，可用条件与对应的菜单项相同；表里没有的组合不接受。
enum ReferenceDropAction {
    /// 打开参数表单：合并、拉取、新建与跟踪分支、发布分支。
    case request(RepositoryActionRequest)

    /// 本地分支拖到远端分支：打开 Push Branch 对话框。
    case pushBranch(PushBranchRequest)

    /// 按住 ⌥ 把远端分支拖到 HEAD 分支行：设为当前分支的上游。
    case upstream(remote: RepositoryReference, branch: RepositoryReference)

    /// 储藏或储藏里的文件拖到 Working Copy 或 HEAD 分支行。
    case stash(StashDropAction)

    /// 本地分支拖到 Pinned 或 Archived Branches 标题。
    case flag(BranchFlagDropAction)

    /// 提交、提交里的文件、分支与标签的改写、标签、改名、发布标签与新建工作树。
    case operation(RepositoryOperationDrop)

    /// 拖动影像上的动作名：跟踪远端分支与设为上游写 Track，发布分支写 Publish。
    var title: String {
        switch self {
        case .request(let request):
            switch request.kind {
            case .track: AppLocalization.text("branch.dragTrack")
            case .publish: AppLocalization.text("branch.dragPublish")
            case .create, .fetch, .pull, .push, .merge: AppLocalization.text(request.kind.rawValue)
            }

        case .pushBranch:
            AppLocalization.text("sync.push")

        case .upstream:
            AppLocalization.text("branch.dragTrack")

        case .stash(let action):
            AppLocalization.text(action.titleKey)

        case .flag(let action):
            AppLocalization.text(action.titleKey)

        case .operation(let action):
            AppLocalization.text(action.titleKey)
        }
    }

    /// 查动作表；不可用或不在表里时为 nil。
    ///
    /// - Parameters:
    ///   - payloads: 本次拖动的全部来源；多项只来自历史里多选的提交，只有摘取与反转接受。
    ///   - destination: 落点。
    ///   - alternate: 是否按住 ⌥。
    ///   - session: 当前会话。
    @MainActor
    init?(
        payloads: [RepositoryDragPayload],
        destination: RepositoryDropDestination,
        alternate: Bool,
        session: RepositorySession
    ) {
        let operation = RepositoryOperationDrop(
            payloads: payloads,
            destination: destination,
            alternate: alternate,
            session: session
        )

        if let operation {
            self = .operation(operation)
            return
        }

        guard
            payloads.count == 1,
            let payload = payloads.first,
            payload.repository == session.repository
        else { return nil }

        let stash = StashDropAction(
            payload: payload,
            destination: destination,
            alternate: alternate,
            session: session
        )

        let flag = BranchFlagDropAction(
            payload: payload,
            destination: destination,
            alternate: alternate,
            session: session
        )

        if let request = Self.request(payload, on: destination, alternate: alternate, in: session) {
            self = .request(request)
        } else if let push = Self.pushBranch(payload, on: destination, in: session) {
            self = .pushBranch(push)
        } else if let upstream = Self.upstream(payload, on: destination, alternate: alternate, in: session) {
            self = .upstream(remote: upstream.remote, branch: upstream.branch)
        } else if let stash {
            self = .stash(stash)
        } else if let flag {
            self = .flag(flag)
        } else {
            return nil
        }
    }

    /// 打开表单或对话框的动作交给入口，设为上游直接执行，储藏、置顶、归档与改写交给会话。
    ///
    /// - Parameters:
    ///   - session: 当前会话。
    ///   - request: 参数表单入口。
    @MainActor
    func perform(in session: RepositorySession, request: (RepositoryActionRequest) -> Void) {
        switch self {
        case .request(let action): request(action)
        case .pushBranch(let push): session.requestPushBranch(push)
        case .upstream(let remote, let branch): session.setUpstream(remote, for: branch)
        case .stash(let action): action.perform(in: session)
        case .flag(let action): action.perform(in: session)
        case .operation(let action): action.perform(in: session)
        }
    }
}

// MARK: - Private

extension ReferenceDropAction {
    /// 打开参数表单的动作：本地分支拖到 Working Copy 或 HEAD 分支行是合并、远端分支是拉取，按住 ⌥ 时不是；
    /// 拖到 Branches 标题或分支文件夹是新建或跟踪分支，本地分支拖到远端是发布分支。
    @MainActor
    private static func request(
        _ payload: RepositoryDragPayload,
        on destination: RepositoryDropDestination,
        alternate: Bool,
        in session: RepositorySession
    ) -> RepositoryActionRequest? {
        let source = session.history.branches.first { $0.id == payload.reference }

        switch (payload.kind, destination) {
        case (.local, .workingCopy), (.local, .head):
            guard !alternate, let source, session.canMerge(source) else { return nil }
            return RepositoryActionRequest(kind: .merge, reference: payload.reference)

        case (.remote, .workingCopy), (.remote, .head):
            guard !alternate, let source, session.canPull(from: source) else { return nil }
            return RepositoryActionRequest(kind: .pull, reference: payload.reference)

        case (.local, .branches), (.commit, .branches), (.tag, .branches), (.commit, .branchFolder):
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
                localBranch: source.name
            )

        default:
            return nil
        }
    }

    /// 本地分支拖到远端分支：预选拖动的本地分支与落点的远端分支。
    @MainActor
    private static func pushBranch(
        _ payload: RepositoryDragPayload,
        on destination: RepositoryDropDestination,
        in session: RepositorySession
    ) -> PushBranchRequest? {
        guard
            payload.kind == .local,
            case .remoteBranch(_, let target) = destination,
            let source = session.history.branches.first(where: { $0.id == payload.reference }),
            session.canPush(source)
        else { return nil }

        return PushBranchRequest(localBranch: source.id, remoteBranch: target)
    }

    /// 按住 ⌥ 把远端分支拖到 HEAD 分支行：设为当前分支的上游；Working Copy 行不接受。
    @MainActor
    private static func upstream(
        _ payload: RepositoryDragPayload,
        on destination: RepositoryDropDestination,
        alternate: Bool,
        in session: RepositorySession
    ) -> (remote: RepositoryReference, branch: RepositoryReference)? {
        let branches = session.history.branches

        guard
            alternate,
            case .head = destination,
            payload.kind == .remote,
            let remote = branches.first(where: { $0.id == payload.reference }),
            let head = branches.first(where: { $0.isLocal && $0.name == session.status?.branch.head }),
            session.canManage(head)
        else { return nil }

        return (remote, head)
    }
}
