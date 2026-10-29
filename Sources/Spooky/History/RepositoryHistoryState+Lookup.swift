import Foundation
import SpookyKit

// MARK: - Lookup

extension RepositoryHistoryState {
    /// 读出提交在一段历史里的位置：是否排在询问的阈值以内，以及是否在这段历史里。
    ///
    /// - Parameters:
    ///   - id: 要找的提交的完整哈希。
    ///   - roots: 这段历史的起点。
    ///   - query: 列表读取这段历史时的排序与筛选。
    ///   - runner: 读取用的执行器。
    static func lookupPosition(
        of id: String,
        roots: [String],
        query: HistoryQuery,
        runner: GitRunner
    ) async throws -> (isWithinThreshold: Bool, isReachable: Bool) {
        let history = RepositoryHistory(runner: runner)
        let position = try await history.position(
            of: id,
            roots: roots,
            query: query,
            limit: slowLookupThreshold
        )

        guard position == nil else {
            return (true, true)
        }

        // 不在前面这些提交里时，再看它是否在这段历史里
        return (false, try await history.contains(id, roots: roots))
    }

    /// 回到历史里的提交之前，先核对它在全部历史里的位置，核对与询问期间视图、列表与选择都不变。
    ///
    /// 已经加载或排在询问的阈值以内时执行 `proceed`；排在之后先询问，同意才执行，取消时什么都不做；
    /// 不在历史里或读取失败时同样执行，由列表的查找说明原因。又要回到别的提交或关闭仓库时，这次核对作废。
    ///
    /// - Parameters:
    ///   - id: 要回到的提交的完整哈希。
    ///   - proceed: 放行后切换视图并定位这个提交的步骤。
    func confirmLookup(_ id: String, then proceed: @escaping () -> Void) {
        // 后退 / 前进核对过的提交经显示视图引用再回到这里，直接放行
        if releasedLookup == id {
            proceed()
            return
        }

        cancelLookupCheck()

        // 列表已是全部历史并加载了这个提交，不用核对
        if
            selectedReferences.isEmpty,
            searchConditions.isEmpty,
            !query.isSearching,
            commits.contains(where: { $0.id == id })
        {
            releaseLookup(id, proceed)
            return
        }

        // 刚打开的仓库还没读到引用，读到后再核对
        guard let runner, snapshot != nil else {
            pendingLookupCheck = (id, proceed)
            return
        }

        let request = lookupCheckRequest
        let roots = allHistoryRoots
        let query = HistoryViewSettings(defaults: preferences).query(conditions: [])

        lookupCheckTask = Task { [weak self] in
            let position = try? await Self.lookupPosition(
                of: id,
                roots: roots,
                query: query,
                runner: runner
            )

            guard let self, lookupCheckRequest == request, !Task.isCancelled else {
                return
            }

            lookupCheckTask = nil

            // 不在历史里或读取失败时照常回到，由列表的查找说明找不到或失败的原因
            guard let position, position.isReachable else {
                proceed()
                return
            }

            if position.isWithinThreshold {
                releaseLookup(id, proceed)
                return
            }

            askSlowLookup(id) { [weak self] in
                // 询问期间又要回到别的提交或关闭了仓库时，这次同意不再生效
                guard let self, lookupCheckRequest == request else { return }

                releaseLookup(id, proceed)
            }
        }
    }

    /// 经窗口询问是否回到排在询问的阈值之后的提交；同意时执行 `agree`，取消时不回调。
    func askSlowLookup(_ id: String, then agree: @escaping () -> Void) {
        let title = AppLocalization.text("history.reveal.slow")
        let message = AppLocalization.text(
            "history.reveal.slow.message",
            String(id.prefix(8)),
            Self.slowLookupThreshold
        )

        onSlowLookup?(title, message, agree)
    }

    /// 作废进行中的核对：取消读取，放弃等着引用的核对，之前的询问不再生效。
    func cancelLookupCheck() {
        lookupCheckTask?.cancel()
        lookupCheckTask = nil
        pendingLookupCheck = nil
        lookupCheckRequest += 1
    }

    /// 放行回到这个提交：执行放行的步骤期间记下它，步骤里的 `locate` 见到它就不再核对与询问。
    private func releaseLookup(_ id: String, _ proceed: () -> Void) {
        releasedLookup = id

        defer {
            releasedLookup = nil
        }

        proceed()
    }
}
