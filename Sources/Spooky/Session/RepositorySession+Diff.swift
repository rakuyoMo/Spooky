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

    /// 开着 Diff 着色时为显示的 Diff 着色；没有全文时另取整文件上下文的 Diff，服务器仓库在服务器上生成。
    ///
    /// 全文补丁同样受大 Diff 警告阈值约束，超过阈值或识别不了语言时返回空，按纯文本显示。
    func diffSyntax(for snapshot: DiffSnapshot, diff: RepositoryDiff) async -> DiffSyntax? {
        let entry = snapshot.entry
        let oldPath = entry.originalPath ?? entry.path

        guard
            TextPreferences.colorsDiffSyntax,
            let runner,
            DiffSyntax.mayColor(diff, oldPath: oldPath, newPath: entry.path)
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

        // 着色按全文线性扫描，大文件放到后台完成
        return await Task.detached(priority: .userInitiated) { [full] in
            DiffSyntax.make(from: full, oldPath: oldPath, newPath: entry.path)
        }.value
    }
}
