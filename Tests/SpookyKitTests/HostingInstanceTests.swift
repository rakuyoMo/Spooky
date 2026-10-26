import Foundation
import Testing

@testable import SpookyKit

// MARK: - HostingInstanceTests

/// 托管实例：私有部署地址的解析，以及远端地址到实例与项目路径的对应。
struct HostingInstanceTests {
    /// 私有部署的地址可以带端口与部署路径，末尾的 “/”、查询与片段去掉；不是 http(s) 或带用户名的地址不接受。
    @Test("解析私有部署地址")
    func selfManagedAddress() throws {
        let instance = try #require(HostingInstance.gitlab(address: " https://Git.Example.com:8443/gitlab/?x=1#y "))

        #expect(instance.webURL.absoluteString == "https://git.example.com:8443/gitlab")
        #expect(instance.apiURL.absoluteString == "https://git.example.com:8443/gitlab/api/v4")
        #expect(instance.displayName == "git.example.com:8443/gitlab")
        #expect(instance.isSelfManaged)

        #expect(HostingInstance.gitlab(address: "http://gitlab.local")?.webURL.absoluteString == "http://gitlab.local")
        #expect(HostingInstance.gitlab(address: "ssh://git@gitlab.local") == nil)
        #expect(HostingInstance.gitlab(address: "https://user:pass@gitlab.local") == nil)
        #expect(HostingInstance.gitlab(address: "gitlab.local") == nil)

        #expect(HostingInstance.github.apiURL.absoluteString == "https://api.github.com")
        #expect(HostingInstance.gitlabCom.apiURL.absoluteString == "https://gitlab.com/api/v4")
        #expect(!HostingInstance.gitlabCom.isSelfManaged)
    }

    /// github.com 的 HTTPS、SSH、scp 与 ssh.github.com 写法都对应到 owner/repo；别的主机与不是两段的路径不对应。
    @Test("github.com 的远端")
    func githubRemotes() {
        let github = HostingInstance.github

        for url in [
            "https://github.com/rakuyoMo/Spooky.git",
            "https://user@github.com/rakuyoMo/Spooky/",
            "git@github.com:rakuyoMo/Spooky.git",
            "ssh://git@github.com/rakuyoMo/Spooky",
            "ssh://git@ssh.github.com:443/rakuyoMo/Spooky.git",
        ] {
            #expect(github.projectPath(forRemote: url) == "rakuyoMo/Spooky", "\(url)")
        }

        #expect(github.projectPath(forRemote: "https://github.com/rakuyoMo") == nil)
        #expect(github.projectPath(forRemote: "https://github.com/a/b/c") == nil)
        #expect(github.projectPath(forRemote: "https://github.com:8443/a/b") == nil)
        #expect(github.projectPath(forRemote: "https://ssh.github.com/a/b") == nil)
        #expect(github.projectPath(forRemote: "gh-work:rakuyoMo/Spooky.git") == nil)
        #expect(github.projectPath(forRemote: "/srv/git/Spooky.git") == nil)
    }

    /// 私有部署的 GitLab：HTTPS 地址要带相同的端口与部署路径，SSH 地址只比主机；组可以多层。
    @Test("私有部署 GitLab 的远端")
    func gitlabRemotes() throws {
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com:8443/gitlab"))

        #expect(instance.projectPath(forRemote: "https://git.example.com:8443/gitlab/组/子组/项目.git") == "组/子组/项目")
        #expect(instance.projectPath(forRemote: "git@git.example.com:组/子组/项目.git") == "组/子组/项目")
        #expect(instance.projectPath(forRemote: "ssh://git@git.example.com:2222/group/project.git") == "group/project")

        // 端口或部署路径不同的 HTTPS 地址属于别的实例
        #expect(instance.projectPath(forRemote: "https://git.example.com/gitlab/group/project.git") == nil)
        #expect(instance.projectPath(forRemote: "https://git.example.com:8443/group/project.git") == nil)
        #expect(instance.projectPath(forRemote: "https://git.example.com:8443/gitlab/project") == nil)

        #expect(HostingInstance.gitlabCom.projectPath(forRemote: "https://gitlab.com/a/b/c/d.git") == "a/b/c/d")
        #expect(HostingInstance.gitlabCom.projectPath(forRemote: "http://gitlab.com/a/b") == nil)
    }
}
