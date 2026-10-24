import Foundation

// MARK: - RewriteAction

/// 交互式变基的一个动作；提交都用完整哈希指定，列表按调用方给的顺序，计划时按历史顺序重排。
public enum RewriteAction: Sendable, Equatable {
    /// 把若干提交压进目标；目标为 nil 时压进所选提交里最旧的一个，至少选两个。信息合并保留。
    case squash([String], into: String?)

    /// 同压缩，但只保留目标的提交信息。
    case fixup([String], into: String?)

    /// 停在这个提交上，把它的改动撤回到工作区，提交后再继续。
    case edit(String)

    /// 改写这个提交的信息；信息已按提交区的规则整理好。
    case reword(String, message: String)

    /// 删除若干提交。
    case drop([String])

    /// 把若干提交移到目标旁边，保持它们之间的先后。
    case move([String], to: String, position: MovePosition)

    /// 把暂存的改动并入这个提交。
    case amend(String)

    /// 按 `fixup!`、`squash!`、`amend!` 标记把提交并进各自的目标。
    case autosquash

    /// 只把所选提交重放到新基点之上，同一段里没选中的提交从当前分支上去掉。
    case rebase([String], onto: String)
}

// MARK: - MovePosition

/// 移动提交时落在目标的哪一侧。
public enum MovePosition: Sendable, Equatable {
    /// 历史列表中目标的上方，即比目标更新。
    case above

    /// 历史列表中目标的下方，即比目标更旧。
    case below
}

// MARK: - RebaseInstruction

/// 交互式变基 todo 里的一条指令。
public struct RebaseInstruction: Sendable, Equatable {
    /// 指令的命令字。
    public enum Command: String, Sendable {
        /// 原样重放。
        case pick

        /// 并进上一条，合并两者的信息。
        case squash

        /// 并进上一条，只保留上一条的信息。
        case fixup

        /// 重放后停下等待修改。
        case edit

        /// 重放后改写信息。
        case reword

        /// 不再重放。
        case drop
    }

    /// 命令字。
    public let command: Command

    /// 处理的提交。
    public let commit: String

    /// 提交标题，写在 todo 行尾，进行中横幅从 Git 记录的已完成指令里读回它。
    public let subject: String

    /// todo 文件中的一行。
    var line: String {
        "\(command.rawValue) \(commit) # \(subject)"
    }
}

// MARK: - RewritePlan

/// 交互式变基执行前的计划：会被改写的范围、事先算好的 todo 与风险提示，确认界面据此列出影响范围。
public struct RewritePlan: Sendable {
    /// 计划的动作。
    public let action: RewriteAction

    /// 计划时 HEAD 所在的提交。
    public let head: String

    /// 变基的上游，即范围里最旧提交的父提交；范围从根提交开始时为 nil。
    public let base: String?

    /// 只重放所选提交时的新基点。
    public let onto: String?

    /// 会被改写的提交，从旧到新；Git 生成的 todo 必须与它一致。
    public let commits: [HistoryCommit]

    /// 换掉 Git 生成的 todo 的指令；Autosquash 由 Git 自己排列，为空。
    public let instructions: [RebaseInstruction]

    /// 范围里已经在上游分支中的提交。
    public let pushed: Set<String>

    /// 范围里已经并入其它分支的提交。
    public let merged: Set<String>
}
