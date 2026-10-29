import CryptoKit
import Foundation
import SpookyKit

// MARK: - ActivityInventory

/// Repository 页写增减计数的四类清单；每类按身份对齐，与上一次记录读取时的清单比较。
///
/// 清单的每一项是 “身份 → 比较值的摘要”：比较值里有远端与子模块的地址，可能带凭据，只留 SHA-256 摘要。
enum ActivityInventory: String, Sendable {
    /// 本地分支；远端分支的变化算在所属的远端上。
    case branches

    /// 远端。
    case remotes

    /// 储藏。
    case stashes

    /// 子模块。
    case submodules
}

// MARK: - Items

extension ActivityInventory {
    /// 本地分支的清单：完整引用名 → 顶端、上游与相对上游的领先落后数。
    ///
    /// - Parameters:
    ///   - snapshot: 读到的引用快照。
    ///   - divergence: 各本地分支相对上游的计数，以完整引用名为键。
    static func branches(
        in snapshot: ReferenceSnapshot,
        divergence: [String: ReferenceDivergence]
    ) -> [String: String] {
        var items: [String: String] = [:]

        for branch in snapshot.references where branch.isLocal {
            let counts = divergence[branch.id]

            items[branch.id] = fingerprint([
                branch.objectID,
                branch.upstream,
                counts.map { String($0.ahead) },
                counts.map { String($0.behind) },
            ])
        }

        return items
    }

    /// 远端的清单：名字 → 它的全部设置与属于它的远端分支（含 `HEAD` 符号引用）的指向。
    static func remotes(in snapshot: ReferenceSnapshot) -> [String: String] {
        var items: [String: String] = [:]

        for remote in snapshot.remotes {
            // 快照里的引用按名字排序，同样的远端分支总是得出同样的摘要
            let branches = snapshot.references
                .filter { $0.isRemote && snapshot.remote(for: $0) == remote }
                .flatMap { branch -> [String?] in [branch.id, branch.objectID, branch.symbolicTarget] }

            items[remote.name] = fingerprint([snapshot.remoteSettingsDigests[remote.name]] + branches)
        }

        return items
    }

    /// 储藏的清单：储藏提交的哈希 → 序号；再存一个或删掉一个使序号变化的，都算更新。
    static func stashes(_ entries: [StashEntry]) -> [String: String] {
        Dictionary(
            entries.map { ($0.id, fingerprint([String($0.index)])) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// 子模块的清单：路径 → 名字、两段设置、指针、检出的提交与状态、配置问题、是否要同步与工作区概况。
    ///
    /// - Parameters:
    ///   - submodules: 读到的子模块。
    ///   - summaries: 已检出子模块的工作区概况，以路径为键。
    static func submodules(
        _ submodules: [Submodule],
        summaries: [String: SubmoduleSummary]
    ) -> [String: String] {
        var items: [String: String] = [:]

        for submodule in submodules {
            let settings = [submodule.shared, submodule.local].flatMap { settings in
                [
                    settings?.path,
                    settings?.url,
                    settings?.fetchRecurseSubmodules,
                    settings?.ignore,
                    settings?.update,
                ]
            }

            let summary = summaries[submodule.path].map { "\($0.changes) \($0.ahead) \($0.behind)" }

            items[submodule.path] = fingerprint(
                [
                    submodule.name,
                    submodule.pointer,
                    submodule.checkedOut,
                    "\(submodule.state)",
                    submodule.problem.map { "\($0)" },
                    String(submodule.needsSynchronizing),
                    summary,
                ]
                    + settings
            )
        }

        return items
    }

    /// 一项的比较值：各部分依次计入 SHA-256，没有的部分也占一个位置。
    private static func fingerprint(_ parts: [String?]) -> String {
        var hash = SHA256()

        for part in parts {
            // 先写长度再写内容，相邻两部分的边界不会混淆
            let field = part.map { "\($0.utf8.count):\($0)" } ?? "-"
            hash.update(data: Data(field.utf8))
        }

        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
