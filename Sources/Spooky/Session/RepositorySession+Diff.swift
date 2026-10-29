import Foundation
import SpookyKit

// MARK: - Diff

extension RepositorySession {
    /// 大 Diff 警告阈值换算成字节。
    static var diffWarningBytes: Int {
        let kilobytes = UserDefaults.standard.object(forKey: "diffWarningKilobytes") as? Int
            ?? WorkingCopyOperations.defaultWarningKilobytes

        return max(0, min(kilobytes, Int.max / 1000)) * 1000
    }

    /// 轮询时的所选文件内容哈希；没有可比较的文件或读取失败时为 nil。
    static func contentHash(of entry: StatusEntry?, service: WorkingCopyOperations) async -> String? {
        guard let entry else {
            return nil
        }

        return try? await service.worktreeHash(of: entry)
    }

    /// 暂存侧变化后重读 Diff；读取时按改动换到的那一侧、选中别的文件时换到的那一侧已经在读，不再读第二次。
    func diffSideChanged() {
        guard loadedDiffSide != diffSide else {
            return
        }

        loadDiff()
    }

    /// 开着 Diff 着色时为显示的 Diff 着色；没有全文时另取整文件上下文的 Diff，服务器仓库在服务器上生成。
    ///
    /// 全文补丁同样受大 Diff 警告阈值约束，超过阈值或识别不了语言时返回空，按纯文本显示。
    func diffSyntax(for snapshot: DiffSnapshot, diff: RepositoryDiff) async -> DiffSyntax? {
        let entry = snapshot.entry
        let oldPath = entry.originalPath ?? entry.path

        guard
            TextPreferences.colorsDiffSyntax,
            let runner,
            await DiffSyntax.mayColor(diff, oldPath: oldPath, newPath: entry.path)
        else { return nil }

        var full = diff

        if !DiffSyntax.isEntireFile(diff, options: snapshot.options) {
            let patch = try? await WorkingCopyOperations(runner: runner)
                .patch(for: entry, side: snapshot.side, options: DiffOptions(showsEntireFile: true))

            guard
                let patch,
                patch.count <= Self.diffWarningBytes,
                let parsed = try? RepositoryDiff(patch: patch)
            else { return nil }

            full = parsed
        }

        // 在当前任务中着色：视图换掉内容、任务取消时，尚未开始的着色直接跳过
        return await DiffSyntax.make(from: full, oldPath: oldPath, newPath: entry.path)
    }

    /// 图片 Diff 两侧的内容：工作区相对暂存区时新的一侧读工作区所在机器上的文件，其余取对象库。
    func imageContents(of snapshot: DiffSnapshot, file: DiffFile) async throws -> (old: Data?, new: Data?) {
        guard let runner else {
            throw CancellationError()
        }

        return try await DiffImageSource(runner: runner).contents(
            of: file,
            path: snapshot.entry.path,
            newFromWorkingTree: snapshot.side == .unstaged
        )
    }
}
