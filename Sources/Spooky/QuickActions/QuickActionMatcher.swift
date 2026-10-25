import Foundation

// MARK: - QuickActionMatcher

/// 快捷操作的模糊匹配：查询的字符按顺序出现在候选里就算匹配，不区分大小写与变音符号。
///
/// 得分分五档：完全相同 > 前缀 > 从词首开始的子串 > 其它子串 > 按序散落的字符；
/// 同一档里候选越短、命中越靠前得分越高，散落的字符连续或落在词首时加分。
enum QuickActionMatcher {
    /// 词与词之间的分隔字符，紧跟其后的字符算词首。
    private static let separators: Set<Character> = [" ", "/", "-", "_", ".", ":", "@", "(", "["]

    /// 候选与查询的匹配得分；不匹配时为 nil，空查询匹配一切、得 0 分。
    static func score(_ candidate: String, query: String) -> Int? {
        let needle = fold(query)

        guard !needle.isEmpty else {
            return 0
        }

        let haystack = fold(candidate)
        let extra = haystack.count - needle.count

        guard extra >= 0 else {
            return nil
        }

        if haystack == needle {
            return 4000
        }

        if haystack.hasPrefix(needle) {
            return 3000 - min(extra, 499)
        }

        // 连续出现时按出现位置与多出的长度扣分，从词首开始的高一档
        if let range = haystack.range(of: needle) {
            let offset = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
            let wordStart = separators.contains(haystack[haystack.index(before: range.lowerBound)])

            return (wordStart ? 2500 : 2000) - min(offset + extra, 499)
        }

        return scatteredScore(Array(haystack), Array(needle))
    }

    /// 文件的得分：先匹配文件名，文件名不匹配时再匹配完整路径，只匹配路径的排在所有匹配文件名的后面。
    static func fileScore(_ path: String, query: String) -> Int? {
        let name = path.split(separator: "/").last.map(String.init) ?? path

        if let score = score(name, query: query) {
            return score
        }

        return score(path, query: query).map { max($0 - 2000, 1) }
    }

    /// 按查询筛选 HEAD 树中的文件：得分从高到低，同分按路径的自然顺序；可以在后台执行。
    static func rankFiles(_ paths: [String], query: String) -> [String] {
        let scored: [(path: String, score: Int)] = paths.compactMap { path in
            fileScore(path, query: query).map { (path, $0) }
        }

        return scored
            .sorted { lhs, rhs in
                guard lhs.score == rhs.score else {
                    return lhs.score > rhs.score
                }

                return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
            .map(\.path)
    }

    /// 按种类的固定顺序排列对象；同一种类里按得分从高到低，同分保持传入的顺序，不匹配的去掉。
    static func rank(_ objects: [QuickActionObject], query: String) -> [QuickActionObject] {
        objects.enumerated()
            .compactMap { index, object in score(object.title, query: query).map { (object, $0, index) } }
            .sorted { lhs, rhs in
                guard lhs.0.kind == rhs.0.kind else {
                    return lhs.0.kind < rhs.0.kind
                }

                return lhs.1 != rhs.1 ? lhs.1 > rhs.1 : lhs.2 < rhs.2
            }
            .map(\.0)
    }
}

// MARK: - Private

extension QuickActionMatcher {
    /// 字符按序散落时的得分，落在 1000–1999；连续命中与词首命中加分，跳过的字符扣分。
    private static func scatteredScore(_ haystack: [Character], _ needle: [Character]) -> Int? {
        var score = 1000
        var position = 0
        var previous: Int? = nil

        for character in needle {
            guard let index = haystack[position...].firstIndex(of: character) else {
                return nil
            }

            if let previous, index == previous + 1 {
                score += 15
            } else if index == 0 || separators.contains(haystack[index - 1]) {
                score += 10
            }

            // 每段跳过的字符最多扣 10 分，长路径里的远距离命中不会一扣到底
            score -= min(index - position, 10)
            previous = index
            position = index + 1
        }

        return min(max(score - (haystack.count - needle.count) / 4, 1000), 1999)
    }

    /// 比较前统一大小写与变音符号。
    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
