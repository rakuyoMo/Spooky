import AppKit
import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - SpookyURLTests

/// App 接收的链接：打开本机或服务器仓库与视图、克隆，以及无效或不可信的链接只得到 nil。
@MainActor
struct SpookyURLTests {
    /// 解析一个链接。
    private static func parse(_ text: String) throws -> SpookyURL? {
        SpookyURL(try #require(URL(string: text)))
    }

    /// 本机仓库写绝对路径，服务器仓库写主机别名加路径；视图、分支与提交都能直达。
    @Test("打开仓库与视图")
    func openRequests() throws {
        let local = RepositoryLocation.local(path: "/Users/me/仓库 app")
        let remote = RepositoryLocation.remote(host: "spooky-test", path: "/Users/wgy/spooky-test/app")
        let encoded = "%2FUsers%2Fme%2F%E4%BB%93%E5%BA%93%20app"

        #expect(try Self.parse("spooky://open?repository=" + encoded) == .open(local, nil))
        #expect(
            try Self.parse("spooky://open?repository=spooky-test:/Users/wgy/spooky-test/app&view=history")
                == .open(remote, .history(references: []))
        )
        #expect(
            try Self.parse("spooky://open?repository=/tmp/app&branch=feature/login")
                == .open(.local(path: "/tmp/app"), .history(references: ["refs/heads/feature/login"]))
        )
        #expect(
            try Self
                .parse("spooky://open?repository=/tmp/app&commit=abc123") == .open(.local(path: "/tmp/app"), .commit("abc123"))
        )
        #expect(try Self.parse("spooky://open?repository=/tmp/app&view=reflog") == .open(.local(path: "/tmp/app"), .reflog))
    }

    /// 克隆请求带远端地址；github.com 的 “Open with Desktop” 链接换成 https 克隆地址。
    @Test("克隆请求")
    func cloneRequests() throws {
        #expect(
            try Self
                .parse("spooky://clone?url=git@github.com:rakuyoMo/Spooky.git") == .clone("git@github.com:rakuyoMo/Spooky.git")
        )
        #expect(
            try Self.parse("x-github-client://openRepo/https://github.com/rakuyoMo/Spooky")
                == .clone("https://github.com/rakuyoMo/Spooky.git")
        )
        #expect(
            try Self.parse("github-mac://openRepo/https://github.com/rakuyoMo/Spooky.git")
                == .clone("https://github.com/rakuyoMo/Spooky.git")
        )
    }

    /// 位置不是绝对路径、主机别名像选项、视图不认识、地址像选项、网址不在 github.com 或不是仓库主页时都无效。
    @Test("无效或不可信的链接")
    func rejectedLinks() throws {
        let rejected = [
            "spooky://open",
            "spooky://open?repository=relative/path",
            "spooky://open?repository=-oProxyCommand=x:/srv/app",
            "spooky://open?repository=/tmp/app&view=nothing",
            "spooky://delete?repository=/tmp/app",
            "spooky://clone",
            "spooky://clone?url=--upload-pack=touch%20/tmp/x",
            "x-github-client://openRepo/https://example.com/rakuyoMo/Spooky",
            "x-github-client://openRepo/http://github.com/rakuyoMo/Spooky",
            "x-github-client://openRepo/https://github.com/rakuyoMo/Spooky/tree/main",
            "x-github-client://openRepo/https://github.com/-x/Spooky",
            "https://github.com/rakuyoMo/Spooky",
        ]

        for link in rejected {
            #expect(try Self.parse(link) == nil, "应拒绝：\(link)")
        }
    }

    /// 打开本机仓库的链接经正常的打开流程，在窗口里显示链接指向的视图。
    @Test("经链接打开本机仓库")
    func openLocalRepository() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let coordinator = fixture.coordinator
        let path = try #require(fixture.directory.path.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
        let url = try #require(URL(string: "spooky://open?repository=" + path + "&view=stashes"))

        coordinator.application(NSApplication.shared, open: [url])

        try await FileViewsTests.wait {
            coordinator.windows.contains { $0.session.activeView == .stashes && !$0.showsManager }
        }
    }
}
