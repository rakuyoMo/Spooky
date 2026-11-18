import Foundation
import SpookyKit

// MARK: - ReferenceOrder

/// 引用的公共顺序：名为 main、master、trunk、dev、develop、next 的分支依次排在最前，其余分支与标签按名字排列。
///
/// 侧边栏的分支与远端分支、恢复版本的候选、Reflog 的引用菜单、合并与拉取的下拉共用这一顺序；当前分支不提前。
enum ReferenceOrder {
    /// 排在最前的分支名，按先后排列；远端分支比较去掉远端名之后的部分。
    static let preferredBranches = ["main", "master", "trunk", "dev", "develop", "next"]

    /// 两个分支名的先后：优先名按表中的先后排在最前，其余按 ``precedes(_:_:)`` 比较名字。
    ///
    /// - Parameters:
    ///   - lhs: 本地分支名，或去掉远端名的远端分支名。
    ///   - rhs: 另一个分支名，写法同 `lhs`。
    static func precedes(branch lhs: String, _ rhs: String) -> Bool {
        let left = preferredBranches.firstIndex(of: lhs) ?? preferredBranches.count
        let right = preferredBranches.firstIndex(of: rhs) ?? preferredBranches.count

        guard left == right else {
            return left < right
        }

        return precedes(lhs, rhs)
    }

    /// 两个名字的先后，不看优先名：比较整个名字，不分大小写与全半角，数字按数值，标点等其余字符按 Unicode 码位；
    /// 只差大小写的两个名字也分出先后，结果不随输入顺序变化。
    ///
    /// 按 “/” 折叠出的文件夹出现在它第一个子项的位置，如 “-” 的码位小于 “/”，`sub-x` 排在文件夹 `sub` 之前。
    static func precedes(_ lhs: String, _ rhs: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .numeric, .widthInsensitive, .forcedOrdering]

        // 经 NSString 比较会先做规范分解，é 排在 e 旁边；Swift 原生的 compare 会把 é 排到 z 之后
        // swiftlint:disable:next legacy_objc_type
        return (lhs as NSString).compare(rhs, options: options) == .orderedAscending
    }

    /// 一组引用按公共顺序排列。
    ///
    /// 本地分支、每个远端的远端分支与标签各自成组，组的先后保持在输入里第一次出现的位置；
    /// 组内的分支按 ``precedes(branch:_:)``，标签与其它引用按 ``precedes(_:_:)``。
    ///
    /// - Parameters:
    ///   - references: 待排列的引用。
    ///   - snapshot: 引用所在的快照，用来按最长前缀认出远端分支所属的远端；为 nil 时取远端分支名的第一段。
    static func sorted(_ references: [RepositoryReference], in snapshot: ReferenceSnapshot?) -> [RepositoryReference] {
        var groups: [String: Int] = [:]

        let keyed = references.map { reference in
            let (group, name) = groupAndName(of: reference, in: snapshot)

            // 组号按第一次出现的先后分配
            if groups[group] == nil {
                groups[group] = groups.count
            }

            return (reference: reference, group: groups[group] ?? 0, name: name)
        }

        return keyed
            .sorted { lhs, rhs in
                guard lhs.group == rhs.group else {
                    return lhs.group < rhs.group
                }

                guard lhs.reference.isLocal || lhs.reference.isRemote else {
                    return precedes(lhs.name, rhs.name)
                }

                return precedes(branch: lhs.name, rhs.name)
            }
            .map(\.reference)
    }

    /// 版本候选的顺序：本地分支、各远端的远端分支、标签依次成组，组内按 ``sorted(_:in:)``；远端之间见 ``precedes(remote:_:)``。
    ///
    /// 新建分支与标签、检出版本、跟踪远端分支与设置上游的候选共用这一顺序。
    ///
    /// - Parameters:
    ///   - references: 待排列的引用，不应含远端的 HEAD。
    ///   - snapshot: 引用所在的快照，用来认出远端分支所属的远端。
    static func candidates(
        _ references: [RepositoryReference],
        in snapshot: ReferenceSnapshot?
    ) -> [RepositoryReference] {
        // 远端分支按所属远端分组，组按远端的先后排好位置，组内的先后交给公共顺序
        let byRemote = Dictionary(grouping: references.filter(\.isRemote)) {
            remoteName(of: $0, in: snapshot)
        }

        let remoteBranches = byRemote.keys
            .sorted(by: precedes(remote:_:))
            .flatMap { byRemote[$0] ?? [] }

        let others = references.filter { !$0.isLocal && !$0.isRemote }

        return sorted(references.filter(\.isLocal), in: snapshot)
            + sorted(remoteBranches, in: snapshot)
            + sorted(others, in: snapshot)
    }

    /// 两个远端的先后：名为 origin 的远端在最前，其余按名字。
    static func precedes(remote lhs: String, _ rhs: String) -> Bool {
        guard (lhs == "origin") == (rhs == "origin") else {
            return lhs == "origin"
        }

        return precedes(lhs, rhs)
    }
}

// MARK: - Private

extension ReferenceOrder {
    /// 引用所在的组与组内比较用的名字：远端分支按远端分组，名字去掉远端名。
    private static func groupAndName(
        of reference: RepositoryReference,
        in snapshot: ReferenceSnapshot?
    ) -> (group: String, name: String) {
        guard reference.isRemote else {
            let kind = reference.isLocal ? "heads" : (reference.isTag ? "tags" : "other")
            return (kind, reference.name)
        }

        let remote = remoteName(of: reference, in: snapshot)

        return ("remotes/" + remote, String(reference.name.dropFirst(remote.count + 1)))
    }

    /// 远端分支所属的远端名：远端名可以带 “/”，快照里配置的远端按最长前缀匹配；远端已不在配置里时取第一段。
    private static func remoteName(of reference: RepositoryReference, in snapshot: ReferenceSnapshot?) -> String {
        snapshot?.remote(for: reference)?.name
            ?? reference.name.split(separator: "/").first.map(String.init)
            ?? ""
    }
}
