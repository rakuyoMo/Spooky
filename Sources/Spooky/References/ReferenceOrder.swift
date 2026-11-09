import Foundation
import SpookyKit

// MARK: - ReferenceOrder

/// 引用的公共顺序：名为 main、master、trunk、dev、develop、next 的分支依次排在最前，其余分支与标签按名字排列。
///
/// 侧边栏的分支与远端分支、恢复版本的候选、Reflog 的引用菜单、合并与拉取的下拉共用这一顺序；当前分支不提前。
enum ReferenceOrder {
    /// 排在最前的分支名，按先后排列；远端分支比较去掉远端名之后的部分。
    static let preferredBranches = ["main", "master", "trunk", "dev", "develop", "next"]

    /// 两个分支名的先后：优先名按表中的先后排在最前，其余按名字逐段比较。
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

    /// 两个名字按 “/” 分段逐段比较的先后，不看优先名；前面各段都相同时段数少的在前。
    ///
    /// 逐段比较让按 “/” 折叠出的文件夹按自己的名字插在同级的引用之间。
    #warning(
        "TODO: 名字的各段按 Finder 的规则比较（不分大小写，数字按数值），未核实是否应区分大小写或按字典序；核实方式：建 Alpha、beta、release/1.9 与 release/1.10 几个分支比对 Branches 分组的先后；只影响优先名以外的分支与标签的先后"
    )
    static func precedes(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs.split(separator: "/", omittingEmptySubsequences: false)
        let right = rhs.split(separator: "/", omittingEmptySubsequences: false)

        for (leftPart, rightPart) in zip(left, right) {
            let result = leftPart.localizedStandardCompare(rightPart)

            if result != .orderedSame {
                return result == .orderedAscending
            }
        }

        // 各段都相同时段数少的在前，段数也相同时按字节决定，结果不随输入顺序变化
        guard left.count == right.count else {
            return left.count < right.count
        }

        return lhs < rhs
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

        // 远端名可以带 “/”，快照里配置的远端按最长前缀匹配；远端已不在配置里时取第一段
        let remote =
            snapshot?.remote(for: reference)?.name
                ?? reference.name.split(separator: "/").first.map(String.init)
                ?? ""

        return ("remotes/" + remote, String(reference.name.dropFirst(remote.count + 1)))
    }
}
