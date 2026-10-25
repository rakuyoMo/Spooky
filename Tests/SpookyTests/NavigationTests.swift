import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 后退 / 前进记录与视图引用：记录的截断与去重，视图引用文字形式的往返与拒绝。
@MainActor
struct NavigationTests {
    /// 测试用的本机仓库位置。
    private static let local = RepositoryLocation.local(path: "/tmp/spooky repo")

    /// 后退之后到达新视图，前进的记录作废；与当前视图相同的到达不重复记录，否则一次后退会原地不动。
    @Test("后退、前进与截断")
    func historyTruncation() {
        var history = NavigationHistory()
        let working = ViewReference.repository(Self.local, .workingCopy)
        let log = ViewReference.repository(Self.local, .history(references: []))
        let stashes = ViewReference.repository(Self.local, .stashes)
        let reflog = ViewReference.repository(Self.local, .reflog)

        #expect(!history.canGoBack && !history.canGoForward)

        history.record(.repositories)
        history.record(working)
        history.record(working)
        history.record(log)
        history.record(stashes)
        #expect(history.entries == [.repositories, working, log, stashes])

        #expect(history.goBack() == log)
        #expect(history.goBack() == working)
        #expect(history.canGoBack && history.canGoForward)
        #expect(history.goForward() == log)

        // 回到当前视图本身不算到达新视图，前进的记录保留
        history.record(log)
        #expect(history.canGoForward)

        history.record(reflog)
        #expect(history.entries == [.repositories, working, log, reflog])
        #expect(!history.canGoForward)
        #expect(history.goForward() == nil)
        #expect(history.current == reflog)

        while history.goBack() != nil { }
        #expect(history.current == .repositories)
        #expect(history.goBack() == nil)
    }

    /// 每种视图引用写成文字再解析回来不变：窗口恢复与之后的 URL Scheme 都靠它还原到同一个视图。
    @Test("视图引用的文字形式往返不变")
    func referenceRoundTrip() throws {
        let remote = RepositoryLocation.remote(host: "b", path: "/srv/git/app & co")

        // 路径与引用名里有查询的分隔字符、空格、中文与 NFD 字符
        let path = "dir a/e\u{301} [1]&x=y+z#.txt"

        let references: [ViewReference] = [
            .repositories,
            .repository(Self.local, .workingCopy),
            .repository(remote, .history(references: [])),
            .repository(remote, .history(references: ["refs/heads/a&b", "refs/heads/功能"])),
            .repository(Self.local, .commit("0123456789abcdef0123456789abcdef01234567")),
            .repository(Self.local, .stashes),
            .repository(Self.local, .reflog),
            .repository(Self.local, .branchesReview),
            .repository(remote, .remote("origin")),
            .repository(Self.local, .fileHistory(path: path)),
            .repository(remote, .file(path: path, revision: nil, mode: .raw)),
            .repository(Self.local, .file(path: path, revision: "abc123", mode: .blame)),
        ]

        for reference in references {
            let parsed = try #require(ViewReference(string: reference.string), "无法解析：\(reference.string)")
            #expect(parsed == reference)
        }

        // NFD 路径逐字节保持原样，按路径查找树里的对象才不会落空
        let file = ViewReference.repository(Self.local, .fileHistory(path: path))

        guard
            case .repository(_, .fileHistory(let parsed)) = ViewReference(string: file.string)
        else {
            Issue.record("文件历史的引用没有解析回来")
            return
        }

        #expect(Array(parsed.utf8) == Array(path.utf8))
    }

    /// 文字形式里服务器仓库写作 “主机别名:路径”，与复制路径的写法一致。
    @Test("服务器仓库的位置写作主机别名加路径")
    func remoteLocationText() {
        let reference = ViewReference.repository(.remote(host: "b", path: "/srv/app"), .workingCopy)

        #expect(reference.string == "repository?location=b:/srv/app&view=workingCopy")
        #expect(RepositoryLocation(displayPath: "b:/srv/app") == .remote(host: "b", path: "/srv/app"))
        #expect(RepositoryLocation(displayPath: "/Users/me/app") == .local(path: "/Users/me/app"))
    }

    /// 读不懂的文字一律不当作视图：恢复时据此回到仓库管理，主机别名也不能被当成 ssh 的选项。
    @Test("无法识别的视图引用解析为 nil")
    func invalidReferences() {
        let invalid = [
            "",
            "settings",
            "repository",
            "repository?view=workingCopy",
            "repository?location=/tmp/app",
            "repository?location=/tmp/app&view=unknown",
            "repository?location=/tmp/app&view=commit",
            "repository?location=/tmp/app&view=remote&remote=",
            "repository?location=/tmp/app&view=fileHistory",
            "repository?location=/tmp/app&view=file",
            "repository?location=relative/app&view=workingCopy",
            "repository?location=-oProxyCommand%3Dx:/app&view=workingCopy",
            "repository?location=:/app&view=workingCopy",
            "repository?location=b:&view=workingCopy",
            "repository?location=a%20b:/app&view=workingCopy",
        ]

        for string in invalid {
            #expect(ViewReference(string: string) == nil, "不应解析：\(string)")
        }
    }
}
