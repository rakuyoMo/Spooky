import Foundation
import Observation
import SpookyKit

// MARK: - ActivityKind

/// Activity 按操作类型分的三页。
enum ActivityKind: String, CaseIterable, Codable, Sendable {
    /// 要连接远端传输对象或引用的操作，如获取、拉取与推送；记录保存在本机，重新启动后还在。
    case remote

    /// 各仓库的其它 Git 操作，只在内存里保留最近的 100 条。
    case repository

    /// 对托管服务的接口请求。
    case service
}

// MARK: - RepositoryActivity

/// 一次 Git 操作或托管服务请求的日志和状态，完成后仍可在 Activity 查看。
@MainActor
@Observable
final class RepositoryActivity: Identifiable {
    /// 活动的稳定身份，也是保存文件的文件名。
    let id: UUID

    /// 记录所在的页。
    let kind: ActivityKind

    /// 带主机前缀的仓库身份；校验账号这类不属于仓库的托管服务请求为 nil。
    let repository: RepositoryLocation?

    /// 从本机读回的记录，不是本次运行里发生的。
    let isRestored: Bool

    /// 已本地化的操作名称。
    let title: String

    /// 开始时间。
    let started: Date

    /// 完成、失败或取消的本地化状态键。
    var state = "activity.running"

    /// 正在运行时提供取消入口，结束后清空。
    var cancel: (() -> Void)?

    /// stdout 与 stderr 分别积累字节，避免 UTF-8 跨块乱码。
    private var stdout = ActivityOutput()

    /// 原始 stderr 进度。
    private var stderr = ActivityOutput()

    /// 已完成、失败或取消；进行中的同步把状态换成了步骤名，仍算进行中。
    var isEnded: Bool {
        ["activity.finished", "activity.failed", "activity.cancelled"].contains(state)
    }

    /// 两路输出整段拼成的日志，进度里的 `\r` 已覆盖当前行。
    var log: String {
        [
            String(decoding: stdout.data, as: UTF8.self),
            String(decoding: stderr.data, as: UTF8.self),
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    /// 保存到本机的内容；没有仓库的记录不保存。
    var record: ActivityRecord? {
        guard let repository else {
            return nil
        }

        return ActivityRecord(
            id: id,
            kind: kind,
            repository: repository,
            title: title,
            started: started,
            state: state,
            stdout: stdout.data,
            stderr: stderr.data
        )
    }

    /// 建立一个进行中的记录。
    ///
    /// - Parameters:
    ///   - kind: 记录所在的页。
    ///   - repository: 带主机前缀的仓库身份；不属于仓库的托管服务请求为 nil。
    ///   - title: 已本地化的操作名称。
    init(kind: ActivityKind, repository: RepositoryLocation?, title: String) {
        id = UUID()
        self.kind = kind
        self.repository = repository
        isRestored = false
        self.title = title
        started = Date()
    }

    /// 用保存在本机的内容还原一条已结束的记录。
    init(record: ActivityRecord) {
        id = record.id
        kind = record.kind
        repository = record.repository
        isRestored = true
        title = record.title
        started = record.started
        state = record.state
        stdout = ActivityOutput(data: record.stdout)
        stderr = ActivityOutput(data: record.stderr)
    }

    /// 执行器已经脱敏，此处只按管道追加原始数据，整段保留。
    func append(_ output: GitOutputEvent) {
        switch output {
        case .standardOutput(let data):
            stdout.append(data)

        case .standardError(let data):
            stderr.append(data)
        }
    }
}

// MARK: - RepositoryActivities

/// Activity 跨窗口保留记录，关闭一个仓库不会抹掉已完成日志；设了保存位置后，Remote 记录另存到本机，重新启动后读回。
@MainActor
@Observable
final class RepositoryActivities {
    /// App 内唯一活动列表。
    static let shared = RepositoryActivities()

    /// Repository 页保留的条数上限，超出时先删最早的已结束记录。
    static let repositoryLimit = 100

    /// Remote 记录保存的时长，开始于此前的记录被删掉。
    static let retention: TimeInterval = 7 * 24 * 60 * 60

    /// App 运行期间删一次过期 Remote 记录的间隔。
    static let expiryInterval = Duration.seconds(300)

    /// 最新活动排在最前面。
    var items: [RepositoryActivity] = []

    /// Remote 记录的保存位置；没有设置时只在内存里。
    private var archive: ActivityArchive? = nil

    /// 新活动插到最前；Repository 页超过上限时删最早的已结束记录，进行中的保留。
    func insert(_ activity: RepositoryActivity) {
        items.insert(activity, at: 0)

        guard activity.kind == .repository else {
            return
        }

        while
            items.count(where: { $0.kind == .repository }) > Self.repositoryLimit,
            let index = items.lastIndex(where: { $0.kind == .repository && $0.isEnded })
        {
            items.remove(at: index)
        }
    }

    /// 记录结束：清掉取消入口；设了保存位置时把 Remote 记录写进去。
    func finish(_ activity: RepositoryActivity) {
        activity.cancel = nil

        guard
            activity.kind == .remote,
            let archive,
            let record = activity.record
        else {
            return
        }

        archive.save(record)
    }

    /// 把一次托管服务请求记进 Service 页：开始时插入进行中的记录，结束时按结果写状态与日志。
    ///
    /// 成功写 Finished，日志只有 `log` 给出的服务端结果；失败写 Failed，日志是错误说明；任务被取消时写 Cancelled。
    /// 错误照常抛给调用方，由调用方显示。
    ///
    /// - Parameters:
    ///   - title: 记录的标题。
    ///   - repository: 请求所属的仓库；校验账号这类不属于仓库的请求为 nil。
    ///   - log: 成功时要写进日志的服务端结果；读取不写响应内容。
    ///   - request: 经账号的客户端发出的请求。
    /// - Returns: 请求的结果。
    func recordHosting<Value>(
        title: String,
        repository: RepositoryLocation?,
        log: (Value) -> String? = { _ in nil },
        _ request: () async throws -> Value
    ) async throws -> Value {
        let activity = RepositoryActivity(kind: .service, repository: repository, title: title)
        insert(activity)

        // 成功、失败与取消都在返回之前结束记录
        defer { finish(activity) }

        do {
            let value = try await request()

            if let message = log(value), !message.isEmpty {
                activity.append(.standardOutput(Data(message.utf8)))
            }

            activity.state = "activity.finished"
            return value
        } catch {
            // 换远端、关仓库或关对话框取消的请求不算失败，日志不写错误说明
            if Task.isCancelled || error is CancellationError {
                activity.state = "activity.cancelled"
                throw error
            }

            // 日志写错误的原文，与界面上显示的相同
            let failure = AppFailure(error: error, opening: false, location: repository)
            activity.append(.standardError(Data(failure.details.utf8)))
            activity.state = "activity.failed"
            throw error
        }
    }

    /// 清除一页里已结束的记录，进行中的保留；Remote 记录同时删掉保存的文件。
    func clearEnded(_ kind: ActivityKind) {
        remove { $0.kind == kind && $0.isEnded }
    }

    /// App 启动时设好保存位置并读回已保存的 Remote 记录，之后每 300 秒删一次过期记录。
    func startSaving(in directory: URL) {
        Task {
            await restore(from: directory)

            while !Task.isCancelled {
                try? await Task.sleep(for: Self.expiryInterval)
                removeExpired()
            }
        }
    }

    /// 设好保存位置，在后台读回已保存的记录，按开始时间从新到旧接在列表后面；读回时删掉过期的记录。
    ///
    /// - Parameters:
    ///   - directory: 保存 Remote 记录的目录。
    ///   - now: 判断过期所用的当前时间。
    func restore(from directory: URL, now: Date = Date()) async {
        let archive = ActivityArchive(directory: directory)
        self.archive = archive

        let cutoff = now.addingTimeInterval(-Self.retention)
        let records = await Task.detached { archive.load(since: cutoff) }.value

        // 读回期间结束的记录已经在列表里，不重复加入
        let known = Set(items.map(\.id))

        items += records
            .filter { !known.contains($0.id) }
            .map { RepositoryActivity(record: $0) }
    }

    /// 删掉开始于保存时长之前的已结束 Remote 记录与它们的文件。
    ///
    /// - Parameter now: 判断过期所用的当前时间。
    func removeExpired(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Self.retention)
        remove { $0.kind == .remote && $0.isEnded && $0.started < cutoff }
    }

    /// 从列表里删掉符合条件的记录；Remote 记录同时删掉保存的文件。
    private func remove(where matches: (RepositoryActivity) -> Bool) {
        let removed = items.filter(matches)
        items.removeAll(where: matches)

        for activity in removed where activity.kind == .remote {
            archive?.delete(activity.id)
        }
    }
}

// MARK: - RepositoryWriteLocks

/// 应用内每个仓库同一时间只允许一个明确的写操作；所有窗口的写入口都据此禁用。
@MainActor
@Observable
final class RepositoryWriteLocks {
    /// 应用内唯一的写操作登记。
    static let shared = RepositoryWriteLocks()

    /// 正在写入的仓库。
    private(set) var active: Set<RepositoryLocation> = []

    /// 登记写操作；同一仓库已有写操作时拒绝。
    func acquire(_ location: RepositoryLocation) -> Bool {
        active.insert(location).inserted
    }

    /// 写操作结束后释放登记。
    func release(_ location: RepositoryLocation) {
        active.remove(location)
    }

    /// 仓库是否正在写入。
    func contains(_ location: RepositoryLocation) -> Bool {
        active.contains(location)
    }
}

// MARK: - ActivityOutput

/// 一路输出整理后的字节：`\n` 结束当前行，`\r` 之后再来的字符覆盖当前行，进度刷新不会越积越多。
private struct ActivityOutput {
    /// 换行。
    private static let newline = UInt8(ascii: "\n")

    /// 回车，进度输出用它回到行首。
    private static let carriageReturn = UInt8(ascii: "\r")

    /// 整理后的字节，不含回车。
    private(set) var data: Data

    /// 当前行在 `data` 里的起点。
    private var lineStart: Int

    /// 上一个字节是回车；跨数据块保留，回车恰好落在块末尾时下一块仍会覆盖当前行。
    private var returned = false

    /// 从已整理好的字节接着写，当前行从最后一个换行之后开始。
    init(data: Data = Data()) {
        self.data = data
        lineStart = data.lastIndex(of: Self.newline).map { $0 + 1 } ?? 0
    }

    /// 追加一块原始输出。UTF-8 的多字节字符里没有换行与回车的字节，按字节切分不会切坏字符。
    mutating func append(_ chunk: Data) {
        var start = chunk.startIndex

        for index in chunk.indices where chunk[index] == Self.newline || chunk[index] == Self.carriageReturn {
            write(chunk[start ..< index])
            start = index + 1

            // 回车只记下标记，等下一个普通字符再清掉当前行
            if chunk[index] == Self.carriageReturn {
                returned = true
                continue
            }

            data.append(Self.newline)
            lineStart = data.count
            returned = false
        }

        write(chunk[start...])
    }

    /// 写入一段不含换行与回车的字节；上一个字节是回车时先删掉当前行。
    private mutating func write(_ bytes: Data) {
        guard !bytes.isEmpty else {
            return
        }

        if returned {
            data.removeSubrange(lineStart...)
            returned = false
        }

        data.append(bytes)
    }
}
