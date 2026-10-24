import Foundation

// MARK: - MergeDiffMode

/// 合并提交在提交详情里的 Diff 方式；对普通提交没有影响。
///
/// 原始值是偏好里保存的值，详情与整页详情按同一个值读取变更集与补丁。
public enum MergeDiffMode: Int, Sendable, CaseIterable {
    /// 合并提交不显示改动，变更集为空。
    case off = 0

    /// 与第一父提交比较，输出与普通提交相同。
    case firstParent = 1

    /// 组合 Diff：只列出与每个父提交都不同的文件，即合并时真正合过的文件。
    case mergedFilePaths = 2

    /// `show` 处理合并提交的参数。
    var arguments: [String] {
        switch self {
        case .off:
            ["--diff-merges=off"]

        case .firstParent:
            ["--diff-merges=first-parent"]

        case .mergedFilePaths:
            ["--diff-merges=combined"]
        }
    }
}
