import Foundation

// MARK: - CombinedDiffRange

/// 组合补丁中一个父提交或结果侧的完整范围。
public struct CombinedDiffRange: Sendable, Equatable {
    /// 该侧在文件中的起始行号。
    public let start: Int

    /// 该侧在本块中的行数，空侧为零。
    public let count: Int
}

// MARK: - CombinedDiffLine

/// 组合补丁逐父前缀与完整列号；普通双侧投影另由 DiffLine 保留。
public struct CombinedDiffLine: Sendable, Equatable {
    /// 每个父提交对应的原始空格、加号或减号。
    public let prefixes: [UInt8]

    /// 按父提交顺序、最后为结果的行号向量，未推进的侧保留上一行号。
    public let numbers: [Int]
}
