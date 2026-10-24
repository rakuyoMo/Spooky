import Foundation

// MARK: - BranchComparison

/// 一个分支与基准分支的比较：双向提交数与把分支并入基准时的合并预览。
///
/// 分支整理视图、历史的基准分支头与 Update Branch 共用它；全部来自结构化的 Git 结果，不解析人读文字。
public struct BranchComparison: Sendable, Equatable {
    /// `ahead` 是分支独有的提交数，`behind` 是基准独有的提交数。
    public let divergence: ReferenceDivergence

    /// 分支并入基准的预览：`unchanged` 表示分支已完全并入基准，`clean` 表示能干净合并。
    public let merge: MergePreview

    /// 分支是否已完全并入基准。
    public var isMerged: Bool { merge == .unchanged }
}

// MARK: - MergeTreeBatchResult

/// `merge-tree --stdin` 一段输出的结论：能否干净合并与冲突的文件。
struct MergeTreeBatchResult: Sendable, Equatable {
    /// 是否能干净合并。
    let isClean: Bool

    /// 冲突的文件路径，按 Git 输出的顺序。
    let conflicts: [String]
}

// MARK: - RepositoryReferences

extension RepositoryReferences {
    /// 解析 `merge-tree --write-tree --stdin -z --name-only --no-messages` 的输出。
    ///
    /// 每段是合并状态（1 干净，0 冲突）、结果树、各冲突路径，最后以一个空字段结束；段数与输入的行数一致。
    static func parseMergeTreeBatch(_ data: Data, count: Int) throws -> [MergeTreeBatchResult] {
        var fields = data.split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }

        // 输出以 NUL 结尾，拆分后最后多出一个空字段
        if let last = fields.last, last.isEmpty {
            fields.removeLast()
        }

        var results: [MergeTreeBatchResult] = []
        var index = 0

        while index < fields.count {
            guard
                index + 1 < fields.count,
                ["0", "1"].contains(fields[index]),
                GitObjectID.isValid(fields[index + 1])
            else {
                throw RepositoryReadError.malformedOutput("merge-tree")
            }

            let isClean = fields[index] == "1"
            index += 2

            // 冲突路径一直列到这一段结尾的空字段
            var conflicts: [String] = []

            while index < fields.count, !fields[index].isEmpty {
                conflicts.append(fields[index])
                index += 1
            }

            guard index < fields.count else {
                throw RepositoryReadError.malformedOutput("merge-tree")
            }

            index += 1
            results.append(MergeTreeBatchResult(isClean: isClean, conflicts: conflicts))
        }

        guard results.count == count else {
            throw RepositoryReadError.malformedOutput("merge-tree")
        }

        return results
    }

    /// 逐个比较本地分支与基准分支。
    ///
    /// 双向计数用 `rev-list --left-right --count`，按哈希缓存；分支没有独有提交时已完全并入，基准没有独有提交时能快进，
    /// 两侧都有独有提交的分支一次交给 `merge-tree --stdin` 批量预览，服务器上只多一次往返。
    /// 批量预览失败（如某个分支与基准没有共同历史）时退回逐个预览，失败的那个记为无法检查。
    ///
    /// - Parameters:
    ///   - branches: 以分支的完整引用名为键、顶端提交为值；取自同一份引用快照。
    ///   - base: 基准分支的顶端提交。
    /// - Returns: 以分支的完整引用名为键。
    public func compare(
        _ branches: [String: String],
        toBase base: String
    ) async throws -> [String: BranchComparison] {
        guard GitObjectID.isValid(base), branches.values.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.invalidQuery
        }

        // 双向计数并发读取，并发度由仓库队列的主机槽统一限制
        let counts = try await withThrowingTaskGroup(of: (String, ReferenceDivergence).self) { group in
            for (id, tip) in branches {
                group.addTask {
                    (id, try await divergence(local: tip, upstream: base))
                }
            }

            var result: [String: ReferenceDivergence] = [:]

            for try await (id, counts) in group {
                result[id] = counts
            }

            return result
        }

        let diverged = counts.filter { $0.value.ahead > 0 && $0.value.behind > 0 }.keys.sorted()
        let previews = try await mergePreviews(diverged.map { ($0, branches[$0] ?? "") }, into: base)
        var result: [String: BranchComparison] = [:]

        for (id, counts) in counts {
            let merge: MergePreview =
                if counts.ahead == 0 {
                    .unchanged
                } else if counts.behind == 0 {
                    .clean
                } else {
                    previews[id] ?? .unavailable("")
                }

            result[id] = BranchComparison(divergence: counts, merge: merge)
        }

        return result
    }

    /// 分支与基准的分叉点；两者没有共同历史时为 nil。
    ///
    /// `merge-base` 找不到共同祖先时以 1 退出，是正常的空结果；128 才是真正的错误。
    public func forkPoint(of branch: String, base: String) async throws -> String? {
        guard GitObjectID.isValid(branch), GitObjectID.isValid(base) else {
            throw RepositoryReadError.invalidQuery
        }

        let result = try await runner.execute(["merge-base", branch, base], acceptedExitCodes: [0, 1])

        guard result.exitCode == 0 else {
            return nil
        }

        let hash = String(decoding: result.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)

        guard GitObjectID.isValid(hash) else {
            throw RepositoryReadError.malformedOutput("merge-base")
        }

        return hash
    }

    /// 批量预览若干分支并入基准；批量失败时逐个预览。
    private func mergePreviews(
        _ branches: [(id: String, tip: String)],
        into base: String
    ) async throws -> [String: MergePreview] {
        guard !branches.isEmpty else {
            return [:]
        }

        // 每行是 “基准 分支”，基准作为我方
        let input = branches.map { base + " " + $0.tip + "\n" }.joined()

        do {
            let result = try await runner.execute(
                ["merge-tree", "--write-tree", "--stdin", "-z", "--name-only", "--no-messages"],
                input: Data(input.utf8)
            )
            let parsed = try Self.parseMergeTreeBatch(result.standardOutput, count: branches.count)

            return Dictionary(
                uniqueKeysWithValues: zip(branches, parsed).map { branch, outcome in
                    (branch.id, outcome.isClean ? MergePreview.clean : .conflicts(outcome.conflicts))
                }
            )
        } catch let error as GitError where !error.isCancelled {
            var result: [String: MergePreview] = [:]

            for branch in branches {
                result[branch.id] = try await mergePreview(of: branch.tip, into: base)
            }

            return result
        }
    }

    /// 单个分支并入基准的预览；Git 报错时记为无法检查并保留原始输出，取消照常抛出。
    private func mergePreview(of tip: String, into base: String) async throws -> MergePreview {
        do {
            let result = try await runner.execute(
                ["merge-tree", "--write-tree", "--name-only", "-z", "--no-messages", base, tip],
                acceptedExitCodes: [0, 1]
            )
            let fields = result.standardOutput.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }

            guard let tree = fields.first, GitObjectID.isValid(tree) else {
                return .unavailable("merge-tree")
            }

            return result.exitCode == 0 ? .clean : .conflicts(Array(fields.dropFirst()))
        } catch let error as GitError where !error.isCancelled {
            return .unavailable(String(decoding: error.result.standardError, as: UTF8.self))
        }
    }
}
