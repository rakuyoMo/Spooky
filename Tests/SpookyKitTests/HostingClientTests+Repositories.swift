import Foundation
import Testing

@testable import SpookyKit

// MARK: - Repositories

/// 发布仓库用到的接口：所有者、是否已存在与新建；与 ``HostingClientTests`` 同属一组依次执行。
extension HostingClientTests {
    /// GitHub：账号本人在前、组织在后；在组织下新建时请求发到组织，私有写成布尔值。
    @Test("GitHub 的所有者与新建仓库")
    func githubRepositories() async throws {
        HostingStub.respond { request in
            request.url?.path() == "/user"
                ? (200, [:], Data(#"{"login":"rakuyo","name":null}"#.utf8))
                : (200, [:], Data(#"[{"login":"acme"}]"#.utf8))
        }

        let client = HostingClient(instance: .github, token: "t", session: HostingStub.session())
        #expect(try await client.owners() == [
            HostingOwner(id: "rakuyo", path: "rakuyo", isUser: true),
            HostingOwner(id: "acme", path: "acme", isUser: false),
        ])

        let created =
            #"{"full_name":"acme/新仓库","html_url":"https://github.com/acme/x","clone_url":"https://github.com/acme/x.git","ssh_url":"git@github.com:acme/x.git"}"#
        let requests = HostingStub.respond { _ in (201, [:], Data(created.utf8)) }

        let repository = try await client.createRepository(
            named: "新仓库",
            description: "描述",
            visibility: .internal,
            owner: HostingOwner(id: "acme", path: "acme", isUser: false)
        )

        #expect(repository == HostingRepository(
            project: "acme/新仓库",
            webURL: URL(string: "https://github.com/acme/x"),
            httpsURL: "https://github.com/acme/x.git",
            sshURL: "git@github.com:acme/x.git"
        ))

        let sent = try #require(requests.withLock { $0.first })
        let body = try JSONSerialization.jsonObject(with: HostingStub.body(of: sent)) as? [String: Any]
        #expect(sent.url?.absoluteString == "https://api.github.com/orgs/acme/repos")
        #expect((body?["private"] as? Bool) ?? false)
        #expect(body?["name"] as? String == "新仓库")
    }

    /// GitLab：命名空间按个人在前；新建时带命名空间编号与可见性；项目不存在按 404 判断。
    @Test("GitLab 的命名空间、新建项目与是否存在")
    func gitlabRepositories() async throws {
        HostingStub.respond { _ in
            (200, [:], Data(#"[{"id":7,"full_path":"group/sub","kind":"group"},{"id":3,"full_path":"me","kind":"user"}]"#.utf8))
        }

        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        #expect(try await client.owners().map(\.path) == ["me", "group/sub"])

        let created =
            #"{"path_with_namespace":"group/sub/x","web_url":"https://gitlab.com/group/sub/x","http_url_to_repo":"https://gitlab.com/group/sub/x.git","ssh_url_to_repo":"git@gitlab.com:group/sub/x.git"}"#
        let requests = HostingStub.respond { _ in (201, [:], Data(created.utf8)) }

        let repository = try await client.createRepository(
            named: "x",
            description: "",
            visibility: .internal,
            owner: HostingOwner(id: "7", path: "group/sub", isUser: false)
        )
        #expect(repository.project == "group/sub/x" && repository.sshURL == "git@gitlab.com:group/sub/x.git")

        let body = try JSONSerialization
            .jsonObject(with: HostingStub.body(of: try #require(requests.withLock { $0.first }))) as? [String: Any]
        #expect(body?["namespace_id"] as? Int == 7 && body?["visibility"] as? String == "internal")

        HostingStub.respond { request in
            request.url?.absoluteString.hasSuffix("group%2Fsub%2Fx") ?? false
                ? (200, [:], Data("{}".utf8))
                : (404, [:], Data(#"{"message":"404 Project Not Found"}"#.utf8))
        }
        #expect(try await client.repositoryExists("group/sub/x"))
        #expect(try await !client.repositoryExists("group/sub/y"))
    }

    /// GitHub 的 Issue 列表去掉 Pull Request；GitLab 用项目内编号。
    @Test("打开着的 Issue")
    func openIssues() async throws {
        HostingStub.respond { _ in
            (200, [:], Data(#"[{"number":3,"title":"崩溃"},{"number":4,"title":"PR","pull_request":{"url":"x"}}]"#.utf8))
        }
        let github = HostingClient(instance: .github, token: "t", session: HostingStub.session())
        #expect(try await github.openIssues(in: "o/r") == [HostingIssue(number: 3, title: "崩溃")])

        let requests = HostingStub.respond { _ in (200, [:], Data(#"[{"iid":12,"title":"文档"}]"#.utf8)) }
        let gitlab = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        #expect(try await gitlab.openIssues(in: "g/p") == [HostingIssue(number: 12, title: "文档")])
        #expect(requests.withLock { $0.first?.url?.absoluteString.contains("projects/g%2Fp/issues?state=opened") } ?? false)
    }
}
