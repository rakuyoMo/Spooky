import Foundation
import SpookyKit

// MARK: - SidebarTooltip

/// 侧边栏各行的悬停提示与陈旧时长：逐行拼接，服务器仓库的第一行带主机前缀。
enum SidebarTooltip {
    /// 本地分支的悬停提示。
    ///
    /// 第一行是分支名，之后按需追加跟踪关系、超前落后、归档、完全合并、陈旧与跟踪错误。
    ///
    /// - Parameters:
    ///   - reference: 本地分支。
    ///   - host: 服务器仓库的主机别名；本机仓库为 nil。
    ///   - divergence: 相对上游的计数；没有上游或上游已不存在时为 nil。
    ///   - metadata: 分支的置顶与归档信息。
    ///   - status: 按视图设置筛过的完全合并、陈旧与跟踪错误。
    static func branch(
        _ reference: RepositoryReference,
        host: String?,
        divergence: ReferenceDivergence?,
        metadata: BranchMetadata,
        status: SidebarBranchStatus
    ) -> String {
        var lines = [prefix(host) + AppLocalization.text("branch.tooltip.local", reference.name)]

        if let upstream = reference.upstream {
            let isLocal = upstream.hasPrefix("refs/heads/")
            let name = shortName(upstream)
            lines.append(AppLocalization.text(isLocal ? "branch.tooltip.tracksLocal" : "branch.tooltip.tracksRemote", name))

            // 计数只对仍然存在的上游有意义
            if let divergence, divergence.ahead > 0 || divergence.behind > 0 {
                lines.append(
                    AppLocalization.text("branch.tooltip.divergence", divergence.ahead, divergence.behind, name)
                )
            }
        }

        if metadata.isArchived {
            lines.append(AppLocalization.text("branch.tooltip.archived"))
        }

        if status.isFullyMerged {
            lines.append(AppLocalization.text("branch.tooltip.merged"))
        }

        if let staleDuration = status.staleDuration {
            lines.append(AppLocalization.text("branch.tooltip.stale", staleDuration))
        }

        if let missingUpstream = status.missingUpstream {
            lines.append(AppLocalization.text("branch.tooltip.missingUpstream", shortName(missingUpstream)))
        }

        return lines.joined(separator: "\n")
    }

    /// 分离 HEAD 的悬停提示：所在提交的短哈希；未出生分支没有提交时只写主机前缀与分支名。
    static func head(branch: BranchStatus?, host: String?) -> String {
        if let head = branch?.head {
            return prefix(host) + AppLocalization.text("branch.tooltip.local", head)
        }

        let commit = branch?.oid.map { String($0.prefix(8)) } ?? ""
        return prefix(host) + AppLocalization.text("branch.tooltip.detached", commit)
    }

    /// 远端分支的悬停提示。
    static func remoteBranch(_ reference: RepositoryReference, host: String?) -> String {
        prefix(host) + AppLocalization.text("remote.tooltip.branch", reference.name)
    }

    /// 标签的悬停提示：所指提交的短哈希，附注标签再加一行说明。
    static func tag(_ reference: RepositoryReference, host: String?) -> String {
        var lines = [prefix(host) + AppLocalization.text("tag.tooltip.revision", String(reference.objectID.prefix(8)))]

        if let message = reference.message {
            lines.append(AppLocalization.text("tag.tooltip.message", message))
        }

        return lines.joined(separator: "\n")
    }

    /// 距上次更新的时长，取最大的一个单位，如 “3 months”；时间在未来时为 nil。
    static func duration(since date: Date, now: Date = Date()) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.year, .month, .weekOfMonth, .day]

        guard date <= now else {
            return nil
        }

        return formatter.string(from: date, to: now)
    }
}

// MARK: - Private

extension SidebarTooltip {
    /// 服务器仓库的主机前缀，如 “b: ”。
    private static func prefix(_ host: String?) -> String {
        host.map { $0 + ": " } ?? ""
    }

    /// 去掉 `refs/heads/`、`refs/remotes/` 前缀后的名字。
    private static func shortName(_ reference: String) -> String {
        for prefix in ["refs/heads/", "refs/remotes/"] where reference.hasPrefix(prefix) {
            return String(reference.dropFirst(prefix.count))
        }

        return reference
    }
}
