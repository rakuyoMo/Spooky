import AppKit
import Foundation
import Synchronization
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - PullRequestListTests

/// 请求列表的状态筛选与各行的 CI/CD 状态、所选请求 CI/CD 状态的自动刷新，以及标签的显示规则。
@MainActor
struct PullRequestListTests {
    /// 默认只列打开着的请求，换成全部后关闭与已合并的也列出，分支右键菜单只认打开着的请求；
    /// 各行的 CI/CD 状态按请求各读一次，紧接着再读列表时只重读运行中的与源分支有了新提交的。
    /// 所选请求的状态在流水线运行期间自动刷新，跑完就停；刷新失败时保留已读到的，换了所选请求后迟到的结果不写入。
    /// 标签的文字按底色的明暗取色，有标签的请求在讨论的头部下面多一行。
    @Test("列表的状态筛选、CI/CD 状态的读取与自动刷新、标签")
    func statesChecksAndLabels() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.close() }

        try await expectListStates(in: fixture)
        try await expectAutoRefresh(in: fixture)
        try expectLabels(in: fixture)
    }
}

// MARK: - Sections

extension PullRequestListTests {
    /// 状态筛选、各行的 CI/CD 状态与分支对应的请求。
    private func expectListStates(in fixture: Fixture) async throws {
        let state = fixture.session.pullRequests

        // 默认只列打开着的请求，各行读出 CI/CD 的整体状态
        #expect(!state.includesClosed && state.items.map(\.id.number) == [1])
        await untilFinished { state.checks.listTasks }

        #expect(state.checks.states == [fixture.id(1): .running])
        #expect(fixture.session.pullRequest(forBranch: "feature")?.id == fixture.id(1))

        // 列出全部：关闭与已合并的也在，没有流水线的没有状态；分支对应的请求只认打开着的
        state.select(includesClosed: true, runner: fixture.runner)
        await until { !state.isLoading }
        await untilFinished { state.checks.listTasks }

        #expect(state.items.map(\.state) == [.open, .merged, .closed])
        #expect(state.checks.states == [fixture.id(1): .running, fixture.id(2): .success])
        #expect(fixture.session.pullRequest(forBranch: "done") == nil)
        #expect(RequestServer.log(of: fixture.host).contains { $0.contains("state=all") })

        // 紧接着再读列表：运行中的与源分支有了新提交的再读，其余沿用刚读到的
        RequestServer.update(fixture.host) {
            $0.entries[0].pipeline = "success"
            $0.entries[1].sha = String(repeating: "d", count: 40)
            $0.entries[1].pipeline = "failed"
            $0.entries[2].pipeline = "running"
        }

        let before = fixture.detailReads()

        state.load(runner: fixture.runner)
        await until { !state.isLoading }
        await untilFinished { state.checks.listTasks }

        #expect(state.checks.states == [fixture.id(1): .success, fixture.id(2): .failure])
        #expect(zip(fixture.detailReads(), before).map(-) == [1, 1, 0])
    }

    /// 所选请求的 CI/CD 状态：运行期间自动刷新，只有第一次读取记进 Activity。
    private func expectAutoRefresh(in fixture: Fixture) async throws {
        let checks = fixture.session.pullRequests.checks
        let client = try #require(fixture.session.pullRequests.client)
        let request = try #require(fixture.session.pullRequests.items.first)
        let location = fixture.runner.location
        let gate = RefreshGate()
        let title = AppLocalization.text("pullRequests.loadChecks.title")
        let recorded = { RepositoryActivities.shared.items.count { $0.repository == location && $0.title == title } }

        checks.wait = { await gate.wait() }
        RequestServer.update(fixture.host) { $0.entries[0].pipeline = "running" }

        let records = recorded()

        // 运行中：读到一次后等着下一次刷新
        var task = Task { await checks.watch(request, client: client, repository: location) }
        await until { gate.isWaiting }

        let job = PullRequestCheck(
            id: "job-1",
            name: "build",
            group: "build",
            state: .running,
            logPath: "projects/1/jobs/1/trace"
        )

        #expect(checks.selected == PullRequestChecks(state: .running, items: [job]))
        #expect(checks.states[request.id] == .running)

        // 流水线跑完后的那次刷新读到结果，不再刷新；自动刷新不记进 Activity
        RequestServer.update(fixture.host) { $0.entries[0].pipeline = "success" }
        gate.release()
        await task.value

        #expect(checks.selected?.state == .success && checks.states[request.id] == .success)
        #expect(!gate.isWaiting && recorded() == records + 1)

        // 自动刷新失败：停下并记下失败，已读到的状态保留
        RequestServer.update(fixture.host) { $0.entries[0].pipeline = "running" }
        task = Task { await checks.watch(request, client: client, repository: location) }
        await until { gate.isWaiting }

        RequestServer.update(fixture.host) { $0.fails = true }
        gate.release()
        await task.value

        #expect(checks.failure != nil && checks.selected?.state == .running)

        // 等待期间换了所选的请求：迟到的结果不写入
        RequestServer.update(fixture.host) { $0.fails = false }
        task = Task { await checks.watch(request, client: client, repository: location) }
        await until { gate.isWaiting }

        #expect(checks.failure == nil)

        checks.clearSelected()
        RequestServer.update(fixture.host) { $0.entries[0].pipeline = "success" }
        gate.release()
        await task.value

        #expect(checks.selected == nil && checks.states[request.id] == .running)
    }

    /// 标签的文字颜色，与讨论里的标签行。
    private func expectLabels(in fixture: Fixture) throws {
        // 文字按底色的相对亮度取深色或白色，界线在 0.453
        #expect(["ffffff", "fbca04", "747474"].allSatisfy { PullRequestLabelChip.usesDarkText(on: $0) })
        #expect(["000000", "d73a4a", "737373"].allSatisfy { !PullRequestLabelChip.usesDarkText(on: $0) })

        let request = try #require(fixture.session.pullRequests.items.first)

        // 可以增删标签时，没有标签的请求也有标签行，里面是添加按钮
        let coordinator = Self.conversation(of: request, in: fixture).makeCoordinator()
        let outline = PullRequestCommentRulesTests.outline(for: coordinator)

        coordinator.update(Self.conversation(of: request, in: fixture))
        #expect(fixture.session.canEditLabels)
        #expect(Self.keys(of: outline) == [.header, .labels, .description, .addComment])

        // 有标签的请求的标签行不能选中
        let few = Self.request(request, labels: [PullRequestLabel(name: "bug", color: "d73a4a")])

        coordinator.update(Self.conversation(of: few, in: fixture))
        #expect(Self.keys(of: outline) == [.header, .labels, .description, .addComment])

        let row = try #require(outline.item(atRow: 1) as? PullRequestConversationView.Node)
        let height = coordinator.outlineView(outline, heightOfRowByItem: row)

        #expect(!row.item.isSelectable && height > 1)

        // 标签一行放不下时换行，这一行随之变高
        let many = Self.request(
            request,
            labels: (1 ... 40).map { PullRequestLabel(name: "a label that takes some room \($0)") }
        )

        coordinator.update(Self.conversation(of: many, in: fixture))

        let wrapped = try #require(outline.item(atRow: 1) as? PullRequestConversationView.Node)

        #expect(coordinator.outlineView(outline, heightOfRowByItem: wrapped) > height)

        // 账号要重新认证时不能增删：没有标签的请求没有标签行，有标签的照常显示
        let accounts = fixture.session.pullRequests.accounts

        accounts.markNeedsReauthentication(try #require(fixture.session.pullRequests.account))
        coordinator.update(Self.conversation(of: request, in: fixture))
        #expect(!fixture.session.canEditLabels)
        #expect(Self.keys(of: outline) == [.header, .description, .addComment])

        coordinator.update(Self.conversation(of: few, in: fixture))
        #expect(Self.keys(of: outline) == [.header, .labels, .description, .addComment])
    }
}

// MARK: PullRequestListTests.Fixture

extension PullRequestListTests {
    /// 远端在一个假的私有部署 GitLab 上的临时仓库、已登录的账号与读过一次列表的会话。
    ///
    /// 假的 GitLab 上有三个请求：打开着、流水线运行中的 1，已合并、流水线通过的 2，已关闭、没有流水线的 3。
    @MainActor
    struct Fixture {
        /// 临时仓库所在的目录。
        let directory: URL

        /// 偏好域所在的临时目录。
        let defaultsDirectory: URL

        /// 假的 GitLab 的主机名，每个测试独立。
        let host: String

        /// 假的 GitLab 实例。
        let instance: HostingInstance

        /// 临时仓库的执行器。
        let runner: GitRunner

        /// 仓库的会话，远端已对应到账号。
        let session: RepositorySession

        /// 建好仓库、账号与假的 GitLab，读一次远端与列表。
        static func make() async throws -> Self {
            let host = UUID().uuidString.lowercased() + RequestServer.domain
            let instance = try #require(HostingInstance.gitlab(address: "https://" + host))

            RequestServer.install(host, entries: [
                RequestServer.Entry(iid: 1, state: "opened", branch: "feature", character: "a", pipeline: "running"),
                RequestServer.Entry(iid: 2, state: "merged", branch: "done", character: "b", pipeline: "success"),
                RequestServer.Entry(iid: 3, state: "closed", branch: "dropped", character: "c", pipeline: nil),
            ])

            let directory = try FileViewsTests.temporaryDirectory()
            let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
            _ = try await runner.run(["remote", "add", "origin", "https://" + host + "/group/project.git"])

            let defaultsDirectory = FileManager.default.temporaryDirectory
                .appending(path: "spooky-request-list-" + UUID().uuidString)
            let defaults = try #require(UserDefaults(suiteName: defaultsDirectory.appending(path: "defaults").path))

            let accounts = HostingAccounts(
                defaults: defaults,
                credentials: MemoryCredentials(),
                session: RequestServer.session()
            )

            try accounts.save(
                HostingUser(username: "me", name: nil),
                on: instance,
                authentication: .personalAccessToken,
                token: "t"
            )

            let session = RepositorySession(makeRunner: { _ in runner })
            session.pullRequests.accounts = accounts
            session.pullRequests.defaults = defaults
            session.pullRequests.load(runner: runner)

            await until { session.pullRequests.isLoaded }
            #expect(session.pullRequests.failure == nil)

            return Self(
                directory: directory,
                defaultsDirectory: defaultsDirectory,
                host: host,
                instance: instance,
                runner: runner,
                session: session
            )
        }

        /// 假的 GitLab 上 `group/project` 里的请求。
        func id(_ number: Int) -> PullRequestID {
            PullRequestID(instance: instance, project: "group/project", number: number)
        }

        /// 三个请求的详情各被读过几次；列表各行的整体状态读的就是详情。
        func detailReads() -> [Int] {
            let log = RequestServer.log(of: host)

            return (1 ... 3).map { iid in log.count { $0.hasSuffix("/merge_requests/\(iid)") } }
        }

        /// 删除仓库、偏好域与假的 GitLab 上的内容。
        func close() {
            session.close()
            RequestServer.remove(host)
            try? FileManager.default.removeItem(at: defaultsDirectory)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

// MARK: - Helpers

extension PullRequestListTests {
    /// 没有评论、提交还没读完的讨论。
    static func conversation(of request: PullRequest, in fixture: Fixture) -> PullRequestConversationView {
        PullRequestConversationView(
            session: fixture.session,
            request: request,
            comments: [],
            commits: nil,
            canComment: true
        )
    }

    /// 讨论列表各行的身份。
    static func keys(of outline: NSOutlineView) -> [PullRequestConversationItem.Key] {
        (0 ..< outline.numberOfRows).compactMap {
            (outline.item(atRow: $0) as? PullRequestConversationView.Node)?.item.key
        }
    }

    /// 换上一组标签的同一个请求。
    static func request(_ request: PullRequest, labels: [PullRequestLabel]) -> PullRequest {
        PullRequest(
            id: request.id,
            title: request.title,
            body: request.body,
            state: request.state,
            isDraft: request.isDraft,
            author: request.author,
            createdAt: request.createdAt,
            updatedAt: request.updatedAt,
            source: request.source,
            target: request.target,
            labels: labels
        )
    }
}

// MARK: - RefreshGate

/// 两次自动刷新之间的等待，由测试放行。
@MainActor
final class RefreshGate {
    /// 等着放行的那次等待。
    private var continuation: CheckedContinuation<Void, Never>? = nil

    /// 自动刷新正等着放行。
    var isWaiting: Bool { continuation != nil }

    /// 停住，直到测试放行。
    func wait() async {
        await withCheckedContinuation { continuation = $0 }
    }

    /// 放行正等着的那次等待。
    func release() {
        continuation?.resume()
        continuation = nil
    }
}

// MARK: - RequestServer

/// 假的 GitLab：按主机名各存一份 Merge Request、项目的标签与作业的日志，并记下收到的请求；
/// 只拦截本测试的独立域名，不访问真实托管服务。
/// 父类要求重申 Sendable；共享的内容由 Mutex 保护，实例没有可变字段。

// swiftlint:disable:next no_unchecked_sendable
final class RequestServer: URLProtocol, @unchecked Sendable {
    /// 一个 Merge Request。
    struct Entry {
        /// 项目里的编号。
        let iid: Int

        /// GitLab 的状态：`opened`、`merged` 或 `closed`。
        let state: String

        /// 源分支名。
        let branch: String

        /// 源分支提交。
        var sha: String

        /// 最新流水线的状态；没有流水线时为 nil。
        var pipeline: String? = nil

        /// 请求上的标签名。
        var labels: [String] = []

        /// 创建一个请求；源分支提交由一个字符重复 40 次而成。
        init(iid: Int, state: String, branch: String, character: Character, pipeline: String?) {
            self.iid = iid
            self.state = state
            self.branch = branch
            self.pipeline = pipeline
            sha = String(repeating: character, count: 40)
        }

        /// 请求的 JSON；流水线在项目 1 里，编号是 100 加请求的编号。
        var json: String {
            let pipeline = pipeline.map { #"{"id":\#(100 + iid),"project_id":1,"status":"\#($0)"}"# } ?? "null"

            return """
                {"iid":\(iid),"title":"t","state":"\(state)","source_branch":"\(branch)","target_branch":"main",
                "source_project_id":1,"target_project_id":1,"created_at":"2023-11-14T00:00:00Z",
                "updated_at":"2023-11-14T00:00:00Z","sha":"\(sha)","labels":\(labels),"head_pipeline":\(pipeline)}
                """
        }
    }

    /// 一个主机上的内容。
    struct Content {
        /// 项目里的请求，从新到旧。
        var entries: [Entry]

        /// 项目里的标签名。
        var projectLabels = ["bug", "docs"]

        /// 各个作业日志的原文。
        var trace = "section_start:1:step_script\r\u{1B}[0KRunning\nfirst\n"

        /// 读取详情、作业与日志时回 500。
        var fails = false

        /// 收到的请求的地址，按先后。
        var log: [String] = []

        /// 收到的写请求，写成 “方法 路径 请求体”，按先后。
        var writes: [String] = []
    }

    /// 测试域名的后缀。
    static let domain = ".spooky-request-list.invalid"

    /// 各主机上的内容，支持测试并行执行。
    private static let contents = Mutex<[String: Content]>([:])

    /// 给一个主机放上请求。
    static func install(_ host: String, entries: [Entry]) {
        contents.withLock { $0[host] = Content(entries: entries) }
    }

    /// 改动一个主机上的内容。
    static func update(_ host: String, _ change: (inout Content) -> Void) {
        contents.withLock { contents in
            guard var content = contents[host] else { return }

            change(&content)
            contents[host] = content
        }
    }

    /// 一个主机收到过的请求的地址。
    static func log(of host: String) -> [String] {
        contents.withLock { $0[host]?.log ?? [] }
    }

    /// 一个主机收到过的写请求。
    static func writes(of host: String) -> [String] {
        contents.withLock { $0[host]?.writes ?? [] }
    }

    /// 清掉一个主机上的内容。
    static func remove(_ host: String) {
        _ = contents.withLock { $0.removeValue(forKey: host) }
    }

    /// 只经这个协议发请求的会话，交给账号的 API 客户端。
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Self.self]
        return URLSession(configuration: configuration)
    }

    /// 只认测试域名。
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasSuffix(domain) ?? false
    }

    /// 请求原样处理。
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    /// 记下请求并同步送回响应；主机上的内容清掉之后的请求算失败，不联网。
    override func startLoading() {
        guard
            let url = request.url,
            let host = url.host,
            let (status, body) = Self.respond(to: request, url: url, on: host),
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    /// 响应同步完成，没有挂起的网络任务。
    override func stopLoading() { }
}

// MARK: - Responses

extension RequestServer {
    /// 记下请求：写请求改动主机上的内容，读请求按路径给出列表、标签、作业、日志或详情；列表按 `state` 参数只给打开着的或全部。
    private static func respond(to request: URLRequest, url: URL, on host: String) -> (Int, String)? {
        contents.withLock { contents -> (Int, String)? in
            guard var content = contents[host] else { return nil }

            content.log.append(url.absoluteString)

            let response =
                request.httpMethod == "GET"
                    ? read(url, in: content)
                    : write(request, path: url.path, in: &content)

            contents[host] = content
            return response
        }
    }

    /// 新建标签，或按 `add_labels` 与 `remove_labels` 改动请求的标签。
    private static func write(_ request: URLRequest, path: String, in content: inout Content) -> (Int, String) {
        let body = body(of: request)
        let fields = (try? JSONSerialization.jsonObject(with: body)) as? [String: String] ?? [:]

        // 请求体的键按字母排序后记下
        let sorted = (try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])) ?? body

        content.writes.append((request.httpMethod ?? "") + " " + path + " " + String(decoding: sorted, as: UTF8.self))

        if path.hasSuffix("/labels"), let name = fields["name"] {
            content.projectLabels.append(name)
            return (201, "{}")
        }

        guard let index = content.entries.firstIndex(where: { path.hasSuffix("/merge_requests/\($0.iid)") }) else {
            return (404, #"{"message":"404 Not Found"}"#)
        }

        if let added = fields["add_labels"] {
            content.entries[index].labels.append(added)
        }

        content.entries[index].labels.removeAll { $0 == fields["remove_labels"] }
        return (200, content.entries[index].json)
    }

    /// 读请求的响应。
    private static func read(_ url: URL, in content: Content) -> (Int, String) {
        let path = url.path

        if path.hasSuffix("/merge_requests") {
            let opened = url.query?.contains("state=opened") ?? false
            let listed = content.entries.filter { !opened || $0.state == "opened" }

            return (200, "[" + listed.map(\.json).joined(separator: ",") + "]")
        }

        if path.hasSuffix("/labels") {
            let labels = content.projectLabels.map { ##"{"name":"\##($0)","color":"#d73a4a"}"## }

            return (200, "[" + labels.joined(separator: ",") + "]")
        }

        // 请求都没有评论
        if path.hasSuffix("/notes") {
            return (200, "[]")
        }

        guard !content.fails else {
            return (500, #"{"message":"500 Internal Server Error"}"#)
        }

        if path.hasSuffix("/trace") {
            return (200, content.trace)
        }

        // 作业的状态与所在流水线的相同
        if path.hasSuffix("/jobs") {
            let entry = content.entries.first { path.contains("/pipelines/\(100 + $0.iid)/") }
            let status = entry?.pipeline ?? "success"
            let iid = entry?.iid ?? 0

            return (200, #"[{"id":\#(iid),"name":"build","stage":"build","status":"\#(status)"}]"#)
        }

        guard let entry = content.entries.first(where: { path.hasSuffix("/merge_requests/\($0.iid)") }) else {
            return (404, #"{"message":"404 Not Found"}"#)
        }

        return (200, entry.json)
    }

    /// 请求体：经会话发出的请求把它放在流里。
    private static func body(of request: URLRequest) -> Data {
        guard let stream = request.httpBodyStream else {
            return request.httpBody ?? Data()
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)

            guard count > 0 else { break }
            data.append(buffer, count: count)
        }

        return data
    }
}
