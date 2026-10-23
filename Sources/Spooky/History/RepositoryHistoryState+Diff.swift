import Foundation
import SpookyKit

// MARK: - Diff

extension RepositoryHistoryState {
    /// 开着 Diff 着色时为提交里一个文件的 Diff 着色；全文补丁只由提交决定，按哈希复用。
    func diffSyntax(path: String, diff: RepositoryDiff) async -> DiffSyntax? {
        guard
            TextPreferences.colorsDiffSyntax,
            let runner,
            let commit = selectedCommit,
            let file = changes.first(where: { $0.path == path })
        else { return nil }

        let oldPath = file.originalPath ?? file.path

        guard DiffSyntax.mayColor(diff, oldPath: oldPath, newPath: file.path) else {
            return nil
        }

        var full = diff

        // 全文补丁超过大 Diff 警告阈值时不解析，也就不着色
        if !DiffSyntax.isEntireFile(diff, options: DiffPreferences.options()) {
            let result = try? await RepositoryHistory(runner: runner).diff(
                in: commit.id,
                file: file,
                options: DiffOptions(showsEntireFile: true),
                warningKilobytes: RepositorySession.diffWarningBytes / 1000
            )

            guard let parsed = result?.diff else {
                return nil
            }

            full = parsed
        }

        return await Task.detached(priority: .userInitiated) { [full] in
            DiffSyntax.make(from: full, oldPath: oldPath, newPath: file.path)
        }.value
    }

    /// 提交里一个图片文件两侧的内容，都取自对象库。
    func imageContents(path: String, file: DiffFile) async throws -> (old: Data?, new: Data?) {
        guard let runner else {
            throw CancellationError()
        }

        return try await DiffImageSource(runner: runner).contents(of: file, path: path, newFromWorkingTree: false)
    }
}
