import Foundation
import Synchronization

// MARK: - GitLab Project ID

/// 有的反向代理会把 `%2F` 解码，使编码的 GitLab 项目路径 404：这时按名称搜出项目编号，换成编号重发。
extension HostingClient {
    /// 按实例与项目完整路径记下的项目编号；`HostingClient` 每次取用都新建，所以记在进程里。
    private static let gitlabProjectIDs = Mutex<[HostingInstance: [String: Int]]>([:])

    /// 路径开头编码的 GitLab 项目：解码后的完整路径，以及其后的部分；编号形式的项目不算。
    private static func encodedGitLabProject(in path: String) -> (project: String, rest: String)? {
        guard path.hasPrefix("projects/") else {
            return nil
        }

        let tail = path.dropFirst("projects/".count)
        let segment = tail.prefix { $0 != "/" }

        guard segment.contains("%2F"), let project = segment.removingPercentEncoding else {
            return nil
        }

        return (project, String(tail.dropFirst(segment.count)))
    }

    /// 已经记下编号的 GitLab 项目路径换成编号，其余路径原样返回。
    ///
    /// - Parameter path: API 根地址之后的路径，如 `projects/group%2Fproject/merge_requests`。
    func knownGitLabProjectPath(_ path: String) -> String {
        guard
            instance.service == .gitlab,
            let (project, rest) = Self.encodedGitLabProject(in: path),
            let id = Self.gitlabProjectIDs.withLock({ $0[instance]?[project] })
        else {
            return path
        }

        return "projects/\(id)" + rest
    }

    /// 编码的 GitLab 项目路径得到 404 后，按名称搜出项目编号并记下，返回换成编号的路径。
    ///
    /// - Parameter path: 得到 404 的路径。
    /// - Returns: 换成编号的路径；路径不是编码的 GitLab 项目路径，或搜不到同一路径的项目时为 nil。
    func gitlabProjectIDPath(for path: String) async throws -> String? {
        guard instance.service == .gitlab, let (project, rest) = Self.encodedGitLabProject(in: path) else {
            return nil
        }

        // 搜索按项目名与路径匹配：用路径的最后一段搜，再在结果里找完整路径相同的项目
        let name = project.split(separator: "/").last.map(String.init) ?? project
        let response: HostingResponse<[GitLabProject]> = try await send(
            "GET",
            "projects",
            query: [
                URLQueryItem(name: "search", value: name),
                URLQueryItem(name: "per_page", value: "100"),
            ]
        )

        let match = response.value.first {
            $0.pathWithNamespace?.caseInsensitiveCompare(project) == .orderedSame
        }

        guard let id = match?.id else {
            return nil
        }

        Self.gitlabProjectIDs.withLock { $0[instance, default: [:]][project] = id }
        return "projects/\(id)" + rest
    }
}
