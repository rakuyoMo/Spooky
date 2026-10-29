import Foundation
import SpookyKit

// MARK: - HistoryBaseComparison

/// 历史里所选分支与一个基准分支的比较：分叉点、双向提交数与合并预览。
struct HistoryBaseComparison: Equatable {
    /// 所选的本地分支。
    let branch: RepositoryReference

    /// 基准分支。
    let base: RepositoryReference

    /// 两者的分叉点；还在读取或没有共同历史时为 nil。
    var forkPoint: String? = nil

    /// 双向提交数与合并预览；还在读取时为 nil。
    var comparison: BranchComparison? = nil

    /// 分支没有自己的提交：顶端就是分叉点。
    var hasNoNewCommits: Bool { forkPoint == branch.objectID }

    /// 并入时冲突的文件；没有冲突或还在读取时为空。
    var conflicts: [String] {
        guard case .conflicts(let paths) = comparison?.merge else { return [] }
        return paths
    }
}

// MARK: - Compare Branches

extension RepositoryHistoryState {
    /// Compare Branches 开关的偏好键。
    static let comparesBranchesKey = "historyComparesBranches"

    /// 是否打开了 Compare Branches。
    var comparesBranches: Bool {
        preferences.bool(forKey: Self.comparesBranchesKey)
    }

    /// 单选的本地分支；多选、全部历史或分离 HEAD 时为 nil。
    var selectedLocalBranch: RepositoryReference? {
        guard let id = selectedReference else { return nil }
        return snapshot?.references.first { $0.id == id && $0.isLocal && $0.objectType == "commit" }
    }

    /// 所选分支的默认基准：父分支仍存在时用它，否则依次取标准名的基准分支与引用名排第一的其它本地分支。
    func defaultBase(for branch: RepositoryReference) -> RepositoryReference? {
        let locals = (snapshot?.references ?? []).filter { $0.isLocal && $0.id != branch.id }

        if
            let parent = snapshot?.metadata(for: branch.id).parent,
            let found = locals.first(where: { $0.id == parent })
        {
            return found
        }

        let standard = RepositoryReferences.standardBaseBranchNames.map { "refs/heads/" + $0 }

        // 快照按引用名排序，没有标准名的分支时 locals.first 就是引用名排第一的
        return standard.lazy.compactMap { name in locals.first { $0.id == name } }.first
            ?? locals.first
    }

    /// 选择 Compare to 的基准分支后重新比较。
    func selectComparisonBase(_ id: String) {
        comparisonBase = id
        loadBaseComparison()
    }

    /// 读取所选分支与基准、父分支的比较；搜索时不比较，比较结果到达后重排表格行。
    func loadBaseComparison() {
        comparisonTask?.cancel()
        comparisonTask = nil

        guard let runner, let branch = selectedLocalBranch, !query.isSearching else {
            clearComparison()
            return
        }

        let parent = snapshot?.metadata(for: branch.id).parent.flatMap { id in
            snapshot?.references.first { $0.id == id && $0.objectType == "commit" }
        }

        var base: RepositoryReference? = nil

        if comparesBranches {
            base = comparisonBase.flatMap { id in snapshot?.references.first { $0.id == id && $0.isLocal } }
                ?? defaultBase(for: branch)
        }

        // 换了分支或基准时先清掉旧的分叉点，结果到达前不画分叉点行
        baseComparison = base.map { Self.keep(baseComparison, branch: branch, base: $0) }
        parentComparison = parent.map { Self.keep(parentComparison, branch: branch, base: $0) }
        updateComparisonRows()

        let request: (String?, String?, String?) = (branch.id, base?.id, parent?.id)

        comparisonTask = Task { [weak self] in
            let pairs = [base, parent].compactMap { $0 }
            var results: [String: HistoryBaseComparison] = [:]

            for other in pairs where results[other.id] == nil {
                guard let result = await Self.compare(branch, with: other, runner: runner) else { continue }
                results[other.id] = result
            }

            guard
                let self, !Task.isCancelled,
                (selectedLocalBranch?.id, baseComparison?.base.id, parentComparison?.base.id) == request
            else { return }

            baseComparison = base.flatMap { results[$0.id] }
            parentComparison = parent.flatMap { results[$0.id] }
            comparisonTask = nil
            updateComparisonRows()
        }
    }

    /// 按日期分组排好表格行，再插入分叉点行或 “没有新提交” 行。
    func updateComparisonRows() {
        updateParentCommits()

        let base = HistoryRow.rows(for: commits, grouping: grouping)

        guard let comparison = baseComparison, let fork = comparison.forkPoint else {
            rows = base
            return
        }

        if comparison.hasNoNewCommits {
            rows = [.noNewCommits(comparison.base.name)] + base
            return
        }

        guard let index = base.firstIndex(where: { $0.commit?.id == fork }) else {
            rows = base
            return
        }

        var result = base
        result.insert(.forkPoint(comparison.base.name), at: index)
        rows = result
    }
}

// MARK: - Private

extension RepositoryHistoryState {
    /// 同一对分支与基准、顶端都没变时沿用上一次的结果，避免刷新时分叉点行闪烁。
    private static func keep(
        _ previous: HistoryBaseComparison?,
        branch: RepositoryReference,
        base: RepositoryReference
    ) -> HistoryBaseComparison {
        if let previous, previous.branch == branch, previous.base == base {
            return previous
        }

        return HistoryBaseComparison(branch: branch, base: base)
    }

    /// 读取一对分支的分叉点与比较；读取失败时为 nil，表头不显示比较结果。
    private static func compare(
        _ branch: RepositoryReference,
        with base: RepositoryReference,
        runner: GitRunner
    ) async -> HistoryBaseComparison? {
        let references = RepositoryReferences(runner: runner)

        do {
            async let fork = references.forkPoint(of: branch.objectID, base: base.objectID)
            async let compared = references.compare([branch.id: branch.objectID], toBase: base.objectID)

            return try await HistoryBaseComparison(
                branch: branch,
                base: base,
                forkPoint: fork,
                comparison: compared[branch.id]
            )
        } catch {
            return nil
        }
    }

    /// 关闭比较时清空结果与置灰的提交。
    private func clearComparison() {
        let hadRows = baseComparison?.forkPoint != nil
        baseComparison = nil
        parentComparison = nil
        parentCommits = []

        if hadRows {
            rows = HistoryRow.rows(for: commits, grouping: grouping)
        }
    }

    /// 分叉点与它的祖先属于基准分支：沿已加载的父链标出，拓扑序保证孩子先到达。
    private func updateParentCommits() {
        guard let fork = baseComparison?.forkPoint else {
            parentCommits = []
            return
        }

        var ancestors: Set<String> = [fork]
        var marked = Set<String>()

        for commit in commits where ancestors.contains(commit.id) {
            marked.insert(commit.id)
            ancestors.formUnion(commit.parents)
        }

        parentCommits = marked
    }
}
