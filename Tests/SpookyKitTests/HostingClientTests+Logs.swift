import Foundation
import Testing

@testable import SpookyKit

// MARK: - Logs and Labels

/// 作业日志的读取与整理、标签的列出与增删；与 ``HostingClientTests`` 同属一组依次执行。
extension HostingClientTests {
    /// GitHub：只有 GitHub Actions 写的、已结束且没被跳过的检查运行有日志；日志接口以 302 给出地址，
    /// 取那个地址时不带令牌；整理后没有 BOM、时间戳与控制码，分组开头留下标题、结尾不留。
    /// 跳转之后的失败照常分类；没有日志可读的项不发请求。
    @Test("GitHub 的作业日志：哪些项有、跳转不带令牌、整理")
    func githubLog() async throws {
        let runs = """
            {"total_count":5,"check_runs":[
             {"id":15,"name":"other","status":"completed","conclusion":"success","app":{"name":"Reviewer","slug":"reviewer"}},
             {"id":14,"name":"skipped","status":"completed","conclusion":"skipped",
              "app":{"name":"GitHub Actions","slug":"github-actions"}},
             {"id":13,"name":"lint","status":"in_progress","conclusion":null,
              "app":{"name":"GitHub Actions","slug":"github-actions"}},
             {"id":12,"name":"test","status":"completed","conclusion":"failure",
              "app":{"name":"GitHub Actions","slug":"github-actions"}}]}
            """

        HostingStub.respond { request in
            let isRuns = request.url?.path().hasSuffix("/check-runs") ?? false

            return (200, [:], Data((isRuns ? runs : #"{"state":"success","statuses":[]}"#).utf8))
        }

        let client = HostingClient(instance: .github, token: "secret-token", session: HostingStub.session())
        let checks = try await client.checks(for: Self.githubRequest(fork: false))

        #expect(checks.items.map(\.logPath) == ["repos/o/r/actions/jobs/12/logs", nil, nil, nil])

        // 日志原文：BOM、时间戳、分组、带颜色的命令与回车加换行的行尾
        let raw = "\u{FEFF}2026-11-24T05:12:03.8137910Z Current runner version: '2.338.2'\n"
            + "2026-11-24T05:12:05.5789300Z ##[group]Run actions/checkout@v7\n"
            + "2026-11-24T05:12:05.5789880Z with:\r\n"
            + "2026-11-24T05:12:05.5813550Z ##[endgroup]\n"
            + "2026-11-24T05:12:12.5329810Z \u{1B}[36;1mmise run swift:lint\u{1B}[0m\n"
            + "2026-11-24T05:12:12.5949960Z \n"
            + "2026-11-24T05:25:26.3072400Z ##[error]Process completed with exit code 1.\n"

        let blob = "https://storage.example.com/logs/12?sig=abc"

        let requests = HostingStub.respond { request in
            request.url?.host() == "api.github.com" ? (302, ["Location": blob], Data()) : (200, [:], Data(raw.utf8))
        }

        let log = try #require(try await client.log(of: checks.items[0]))

        #expect(
            log.lines == [
                "Current runner version: '2.338.2'",
                "Run actions/checkout@v7",
                "with:",
                "mise run swift:lint",
                "",
                "##[error]Process completed with exit code 1.",
            ]
        )

        let sent = requests.withLock { $0 }

        #expect(sent.map { $0.url?.absoluteString } == ["https://api.github.com/repos/o/r/actions/jobs/12/logs", blob])
        #expect(sent.first?.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
        #expect(sent.last?.value(forHTTPHeaderField: "Authorization") == nil)

        // 跳转到的地址已过期
        HostingStub.respond { request in
            request.url?.host() == "api.github.com" ? (302, ["Location": blob], Data()) : (403, [:], Data("expired".utf8))
        }

        await #expect(throws: HostingError.forbidden("expired")) { try await client.log(of: checks.items[0]) }

        // 没有日志可读的项
        let none = HostingStub.respond { _ in (500, [:], Data()) }

        #expect(try await client.log(of: checks.items[1]) == nil)
        #expect(none.withLock { $0.isEmpty })
    }

    /// GitLab：日志直接在响应体里；新版 Runner 的时间戳与输出流标记去掉，被拆开的行接回去（控制码被拆成两半时也一样），
    /// 分组标记不留、同一行里它后面的标题留下，回车盖掉前面的内容；旧版没有时间戳的写法同样整理。
    @Test("GitLab 的作业日志：直接读取与整理")
    func gitlabLog() async throws {
        let esc = "\u{1B}"

        let raw = "2026-11-24T09:50:08.150044Z 00O \(esc)[0KRunning with gitlab-runner 19.3.0\(esc)[0;m\n"
            + "2026-11-24T09:50:08.150311Z 00O section_start:1795513808:prepare_executor\r\(esc)[0K\n"
            + "2026-11-24T09:50:08.150316Z 00O+\(esc)[0K\(esc)[36;1mPreparing the executor\(esc)[0;m\(esc)[0;m\n"
            + "2026-11-24T09:50:35.720929Z 01O section_end:1795513816:get_sources\r\(esc)[0\n"
            + "2026-11-24T09:50:35.720973Z 01O+Ksection_start:1795513835:step_script\r\(esc)[0\n"
            + "2026-11-24T09:50:35.722928Z 01O+K\(esc)[32;1m$ npm install\(esc)[0m\n"
            + "2026-11-24T09:50:36.100000Z 01O \n"
            + "2026-11-24T09:50:36.200000Z 01E Receiving objects:  10%\rReceiving objects: 100%\n"
            + "2026-11-24T09:50:36.961914Z 01O section_end:1795513835:step_script\r\(esc)[0\n"
            + "2026-11-24T09:50:36.962184Z 01O+K\n"
            + "2026-11-24T09:50:37.354420Z 00O \(esc)[32;1mJob succeeded\(esc)[0;m\n"

        let requests = HostingStub.respond { _ in (200, [:], Data(raw.utf8)) }
        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let check = PullRequestCheck(
            id: "job-34",
            name: "lint",
            group: "test",
            state: .success,
            logPath: "projects/42/jobs/34/trace"
        )
        let log = try #require(try await client.log(of: check))

        #expect(
            log.lines == [
                "Running with gitlab-runner 19.3.0",
                "Preparing the executor",
                "$ npm install",
                "",
                "Receiving objects: 100%",
                "Job succeeded",
            ]
        )

        #expect(
            requests
                .withLock { $0.map { $0.url?.absoluteString } } == ["https://gitlab.com/api/v4/projects/42/jobs/34/trace"]
        )

        // 没有时间戳的写法
        let legacy = "section_start:1560896352:step_script\r\(esc)[0K\(esc)[36;1mExecuting the script\(esc)[0;m\n"
            + "00O is not a stream marker here\n"
            + "section_end:1560896353:step_script\r\(esc)[0K\n"

        #expect(
            PullRequestCheckLog(text: legacy, service: .gitlab).lines == [
                "Executing the script",
                "00O is not a stream marker here",
            ]
        )

        // 还没开始的作业没有日志
        #expect(PullRequestCheckLog(text: "", service: .gitlab).lines.isEmpty)
    }

    /// 标签：项目里的标签逐页读完，GitHub 的颜色不带 “#”、GitLab 的带；新建时各按服务的写法给颜色；
    /// GitHub 经同号 Issue 的接口增删，名称作为路径的一段转义；GitLab 经请求的 `add_labels` 与 `remove_labels`。
    @Test("标签的列出、新建与增删")
    func labels() async throws {
        // GitHub
        let link = #"<https://api.github.com/repos/o/r/labels?per_page=100&page=2>; rel="next""#

        var requests = HostingStub.respond { request in
            request.url?.query()?.hasSuffix("page=1") ?? false
                ? (200, ["Link": link], Data(#"[{"name":"bug","color":"d73a4a","description":"Broken"}]"#.utf8))
                : (200, [:], Data(#"[{"name":"help wanted","color":"008672","description":null}]"#.utf8))
        }

        let github = HostingClient(instance: .github, token: "t", session: HostingStub.session())
        let id = PullRequestID(instance: .github, project: "o/r", number: 7)

        #expect(
            try await github.labels(in: "o/r") == [
                PullRequestLabel(name: "bug", color: "d73a4a", description: "Broken"),
                PullRequestLabel(name: "help wanted", color: "008672"),
            ]
        )

        #expect(requests.withLock { $0.count } == 2)

        requests = HostingStub.respond { _ in (200, [:], Data("[]".utf8)) }

        try await github.createLabel("needs review", color: "fbca04", in: "o/r")
        try await github.addLabel("needs review", to: id)
        try await github.removeLabel("needs review/2", from: id)

        #expect(
            Self.calls(requests) == [
                #"POST https://api.github.com/repos/o/r/labels {"color":"fbca04","name":"needs review"}"#,
                #"POST https://api.github.com/repos/o/r/issues/7/labels {"labels":["needs review"]}"#,
                "DELETE https://api.github.com/repos/o/r/issues/7/labels/needs%20review%2F2 ",
            ]
        )

        // GitLab
        requests = HostingStub.respond { _ in
            (200, [:], Data(##"[{"id":1,"name":"bug","color":"#d73a4a","description":null,"text_color":"#FFFFFF"}]"##.utf8))
        }

        let gitlab = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let request = PullRequestID(instance: .gitlabCom, project: "group/project", number: 3)

        #expect(try await gitlab.labels(in: "group/project") == [PullRequestLabel(name: "bug", color: "d73a4a")])

        try await gitlab.createLabel("needs review", color: "fbca04", in: "group/project")
        try await gitlab.addLabel("needs review", to: request)
        try await gitlab.removeLabel("bug", from: request)

        let api = "https://gitlab.com/api/v4/projects/group%2Fproject/"

        #expect(
            Self.calls(requests) == [
                "GET " + api + "labels?per_page=100&page=1 ",
                "POST " + api + ##"labels {"color":"#fbca04","name":"needs review"}"##,
                "PUT " + api + #"merge_requests/3 {"add_labels":"needs review"}"#,
                "PUT " + api + #"merge_requests/3 {"remove_labels":"bug"}"#,
            ]
        )
    }
}

// MARK: - Helpers

extension HostingClientTests {
    /// 收到的各个请求写成 “方法 地址 请求体”，请求体的键按字母排序。
    private static func calls(_ requests: HostingStub.RequestLog) -> [String] {
        requests.withLock { sent in
            sent.map { request in
                let body = HostingStub.body(of: request)
                let object = try? JSONSerialization.jsonObject(with: body)
                let sorted = object.flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) }

                return (request.httpMethod ?? "") + " " + (request.url?.absoluteString ?? "") + " "
                    + String(decoding: sorted ?? body, as: UTF8.self)
            }
        }
    }
}
