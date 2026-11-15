import Foundation

// MARK: - File Paths

extension RepositoryFileViews {
    /// 对象查询保留原始 Unicode 字节，路径中的魔法前缀由每个 pathspec 明确控制。
    static let filePathOptions = ["--no-literal-pathspecs", "-c", "core.precomposeunicode=false"]

    /// 新旧路径互为祖先时，需要完整变更集定位其它分叉子树。
    public static func needsFileChangeScope(_ paths: [String]) -> Bool {
        paths.contains { parent in paths.contains { isDescendant($0, of: parent) } }
    }

    /// 单文件补丁的字面包含与子项排除，保留祖先路径之间的重命名配对。
    ///
    /// - Parameters:
    ///   - paths: 要读取的真实新旧路径。
    ///   - changedPaths: 互为祖先时同一比较范围的全部新旧变更路径。
    public static func filePathspecs(_ paths: [String], changedPaths: [String] = []) -> [String] {
        let wanted = uniquePaths(paths)
        var excluded: [String] = []

        for path in wanted {
            let descendants = wanted.filter { isDescendant($0, of: path) }

            if descendants.isEmpty {
                excluded.append(path + "/")
                continue
            }

            for other in changedPaths where isDescendant(other, of: path) {
                guard !wanted.contains(where: { samePath($0, other) || isDescendant($0, of: other) }) else {
                    continue
                }

                let components = other.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
                let shared = descendants.map { candidate in
                    zip(components, candidate.split(separator: "/").map(String.init))
                        .prefix { samePath($0.0, $0.1) }
                        .count
                }
                let longest = shared.max() ?? 0

                excluded.append(components.prefix(longest + 1).joined(separator: "/"))
            }
        }

        let unique = uniquePaths(excluded)
        let minimal = unique.filter { candidate in
            !unique.contains { !samePath($0, candidate) && isDescendant(candidate, of: $0) }
        }

        return wanted.map { ":(top,literal)" + $0 }
            + minimal.map(exclusion)
    }

    /// 目录归属按 UTF-8 字节与路径组件边界判断。
    public static func contains(_ path: String, in directory: String) -> Bool {
        samePath(path, directory) || isDescendant(path, of: directory)
    }

    /// Git 路径不进行 Unicode 规范等价折叠。
    private static func samePath(_ first: String, _ second: String) -> Bool {
        first.utf8.elementsEqual(second.utf8)
    }

    /// 子项必须在父路径后的斜线边界内。
    private static func isDescendant(_ path: String, of parent: String) -> Bool {
        path.utf8.starts(with: (parent + "/").utf8)
    }

    /// 一项排除：以斜线结尾的只排除目录里的子项；其余按字面排除路径本身与它的子项。
    ///
    /// 字面的 `目录/` 也会排除同名的子模块，子模块的 Diff 因此为空；glob 写法的 `目录/**` 只匹配子项。
    private static func exclusion(_ path: String) -> String {
        guard path.hasSuffix("/") else {
            return ":(top,exclude,literal)" + path
        }

        // 路径里的通配字符逐个转义，按字面匹配
        let escaped = path.reduce(into: "") { result, character in
            if "\\*?[".contains(character) {
                result.append("\\")
            }

            result.append(character)
        }

        return ":(top,exclude,glob)" + escaped + "**"
    }

    /// 保持首次出现顺序，按 Git 使用的原始字节去重。
    private static func uniquePaths(_ paths: [String]) -> [String] {
        var seen: Set<Data> = []
        return paths.filter { seen.insert(Data($0.utf8)).inserted }
    }
}
