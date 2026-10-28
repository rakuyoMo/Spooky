import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 错误类别、断线核对报告、窗口恢复校验与 Activity 上限的呈现规则。
@MainActor
struct FailurePresentationTests {
    /// 连接断开、Git 退出失败、输出解析失败、用户取消和版本不支持分别归入不同类别。
    @Test("错误类别彼此区分")
    func kinds() {
        let result = GitCommandResult(
            arguments: ["status"],
            standardOutput: Data(),
            standardError: Data("fatal: failure\n".utf8),
            terminationStatus: .exited(128),
            isCancelled: false
        )
        let cases: [(any Error, FailureKind)] = [
            (RemoteConnectionError(.unavailable), .connection),
            (RemoteConnectionError(.cancellationUnconfirmed), .connection),
            (GitError(result: result, category: .commandFailed, diagnostic: nil), .git),
            (GitError(result: result, category: .indexLocked, diagnostic: nil), .git),
            (StatusParseError(record: "broken"), .output),
            (RepositoryReadError.malformedOutput("log"), .output),
            (GitError(result: result, category: .cancelled, diagnostic: nil), .cancelled),
            (CancellationError(), .cancelled),
            (RepositoryOpenError.unsupportedGitVersion(result), .version),
            (RemoteConnectionError(.gitVersion), .version),
            (RemoteConnectionError(.pathUnavailable), .repository),
            (RepositorySyncError.dirtyWorkingCopy, .repository),
        ]

        for (error, kind) in cases {
            #expect(AppFailure(error: error, opening: false, location: nil).kind == kind)
        }

        #expect(Set(cases.map(\.1)).isSuperset(of: [.connection, .git, .output, .cancelled, .version]))
    }

    /// 写入中途断线时提示先核对仓库，原始 SSH 输出仍保留。
    @Test("写入断线提示核对而不是重试")
    func interruptedWrite() {
        let result = GitCommandResult(
            arguments: ["push"],
            standardOutput: Data(),
            standardError: Data("client_loop: send disconnect: Broken pipe\n".utf8),
            terminationStatus: .exited(255),
            isCancelled: false
        )
        let error = RemoteConnectionError(.unavailable, result: result)
        let location = RepositoryLocation.remote(host: "spooky-test", path: "/tmp/repository")
        let reading = AppFailure(error: error, opening: false, location: location)
        let writing = AppFailure(error: error, opening: false, location: location, writing: true)
        #expect(reading.title == AppLocalization.text("remoteError.unavailable"))
        #expect(writing.title == AppLocalization.text("remoteError.interruptedWrite"))
        #expect(writing.message == AppLocalization.text("remoteError.interruptedWrite.help"))
        #expect(writing.details.contains("Broken pipe"))
        #expect(writing.context.contains("spooky-test:/tmp/repository"))
    }

    /// 写操作的 Git 失败提示看原文后刷新核对；同一错误发生在读取时仍提示刷新重试。
    @Test("写操作失败的恢复说明")
    func writeRecovery() {
        let result = GitCommandResult(
            arguments: ["push"],
            standardOutput: Data(),
            standardError: Data("fatal: Could not read from remote repository.\n".utf8),
            terminationStatus: .exited(128),
            isCancelled: false
        )
        let error = GitError(result: result, category: .remoteNotFound, diagnostic: nil)
        let writing = AppFailure(error: error, opening: false, location: nil, writing: true)
        let reading = AppFailure(error: error, opening: false, location: nil)

        #expect(writing.message == AppLocalization.text("error.writeHelp"))
        #expect(reading.message == AppLocalization.text("error.refreshHelp"))
        #expect(writing.details.contains("Could not read from remote repository."))
    }

    /// 错误对象与界面原文只包含命令输出，不带进程环境中的值。
    @Test("错误与原文不包含环境变量")
    func environmentStaysPrivate() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-env-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = "spooky-private-" + UUID().uuidString
        let runner = GitRunner(
            location: .local(path: directory.path),
            environment: .inherit.updating(["SPOOKY_TEST_SECRET": marker, "GIT_CONFIG_GLOBAL": "/dev/null"])
        )
        let error = await #expect(throws: GitError.self) {
            try await runner.execute(["rev-parse", "--verify", "missing-revision"])
        }
        let failure = AppFailure(error: try #require(error), opening: false, location: runner.location)
        #expect(!String(reflecting: try #require(error)).contains(marker))
        #expect(!failure.details.contains(marker) && !failure.message.contains(marker))
    }

    /// 没有新的核对说明写入未开始；HEAD 未变与已变分别给出不同结论。
    @Test("中断写入的核对报告")
    func recoveryMessages() throws {
        let before = try status(oid: String(repeating: "a", count: 40))
        let after = try status(oid: String(repeating: "b", count: 40))
        let write = InterruptedWrite(title: "Commit", branch: before.branch, time: Date())
        let unchanged = RemoteRecoverySnapshot(
            status: before,
            indexLocked: false,
            merging: false,
            rebasing: false,
            checkedAt: Date()
        )
        let changed = RemoteRecoverySnapshot(
            status: after,
            indexLocked: true,
            merging: false,
            rebasing: false,
            checkedAt: Date()
        )

        #expect(
            RepositoryWindowController.recoveryMessage(write, snapshot: nil)
                == AppLocalization.text("recovery.notStarted", "Commit")
        )
        #expect(
            RepositoryWindowController.recoveryMessage(write, snapshot: unchanged)
                .hasPrefix(AppLocalization.text("recovery.unchanged", "Commit", "aaaaaaaa"))
        )
        let changedMessage = RepositoryWindowController.recoveryMessage(write, snapshot: changed)
        #expect(changedMessage.hasPrefix(AppLocalization.text("recovery.changed", "Commit", "aaaaaaaa", "bbbbbbbb")))
        #expect(changedMessage.contains(AppLocalization.text("state.yes")))
    }

    /// 只有大部分落在某个屏幕内且不超过屏幕尺寸的位置才沿用，其余回到默认尺寸。
    @Test("窗口位置恢复校验")
    func frameRestoration() {
        let screens = [
            NSRect(x: 0, y: 0, width: 1440, height: 875),
            NSRect(x: 1440, y: 0, width: 1920, height: 1055),
        ]
        #expect(RepositoryWindowController.isUsable(NSRect(x: 100, y: 100, width: 1000, height: 540), in: screens))
        #expect(RepositoryWindowController.isUsable(NSRect(x: 1500, y: 200, width: 1800, height: 800), in: screens))
        #expect(!RepositoryWindowController.isUsable(NSRect(x: 5000, y: 100, width: 1000, height: 540), in: screens))
        #expect(!RepositoryWindowController.isUsable(NSRect(x: 1300, y: 100, width: 1000, height: 540), in: [screens[0]]))
        #expect(!RepositoryWindowController.isUsable(NSRect(x: 0, y: 0, width: 2000, height: 600), in: [screens[0]]))
    }

    /// 分栏记录里每一栏都有宽度才沿用；零宽、缺少字段、无法读取或为空的记录回到默认宽度。
    @Test("分栏宽度恢复校验")
    func splitFrameRestoration() {
        let saved = [
            "0.000000, 0.000000, 260.000000, 600.000000, NO, NO",
            "260.000000, 0.000000, 740.000000, 600.000000, NO, NO",
        ]
        let collapsed = [
            "0.000000, 0.000000, 0.000000, 600.000000, NO, NO",
            "0.000000, 0.000000, 1000.000000, 600.000000, NO, NO",
        ]

        #expect(RepositoryWindowController.isUsable(splitFrames: saved))
        #expect(!RepositoryWindowController.isUsable(splitFrames: collapsed))
        #expect(!RepositoryWindowController.isUsable(splitFrames: ["0.000000, 0.000000"]))
        #expect(!RepositoryWindowController.isUsable(splitFrames: [42]))
        #expect(!RepositoryWindowController.isUsable(splitFrames: []))
    }

    /// 输出整段保留不截断；进度里的回车让后面的字符覆盖当前行，刷新多少次都只留最后一次，输出不会越积越多。
    @Test("Activity 输出不截断，回车覆盖当前行")
    func activityOutput() {
        let location = RepositoryLocation.local(path: "/temporary/activity-" + UUID().uuidString)

        // 超过 512 KiB 的输出整段保留
        let long = RepositoryActivity(kind: .remote, repository: location, title: "Fetch")
        long.append(.standardOutput(Data(repeating: 65, count: 600 * 1024)))
        long.append(.standardOutput(Data("tail\n".utf8)))
        #expect(long.log == String(repeating: "A", count: 600 * 1024) + "tail\n")

        // 回车换行保留整行；回车恰好落在数据块末尾时，下一块开头的字符仍覆盖当前行
        let progress = RepositoryActivity(kind: .remote, repository: location, title: "Push")
        progress.append(.standardError(Data("start\r\n接收 10%\r接收 20%\r".utf8)))
        progress.append(.standardError(Data("接收 30%\n".utf8)))

        // 多字节字符被数据块切开也不会乱码
        let done = Data("完成\n".utf8)
        progress.append(.standardError(done.prefix(2)))
        progress.append(.standardError(done.dropFirst(2)))

        #expect(progress.log == "start\n接收 30%\n完成\n")

        // 同一行刷新三次只剩最后一次
        let refreshing = RepositoryActivity(kind: .remote, repository: location, title: "Fetch")
        refreshing.append(.standardError(Data("10%\r20%\r30%\n".utf8)))
        #expect(refreshing.log == "30%\n")
    }

    /// Repository 页超过 100 条时删最早的已结束记录，进行中的保留；Remote 与 Service 不限条数，也不挤占 Repository 页。
    @Test("Activity 各页的条数上限")
    func activityLimits() {
        let location = RepositoryLocation.local(path: "/temporary/activity-" + UUID().uuidString)
        let activities = RepositoryActivities()

        // 最早的一条仍在进行中，之后再插 104 条已结束的记录
        let running = RepositoryActivity(kind: .repository, repository: location, title: "Rebase")
        activities.insert(running)

        let fillers = (0 ..< 104).map { _ in finished(.repository, in: location) }
        fillers.forEach(activities.insert)

        let repository = activities.items.filter { $0.kind == .repository }
        #expect(repository.count == RepositoryActivities.repositoryLimit)
        #expect(repository.contains { $0 === running })
        #expect(repository.first === fillers.last)
        #expect(!repository.contains { $0 === fillers[4] })
        #expect(repository.contains { $0 === fillers[5] })

        // Remote 与 Service 各插 150 条全部保留
        for kind in [ActivityKind.remote, .service] {
            for _ in 0 ..< 150 {
                activities.insert(finished(kind, in: location))
            }
        }

        #expect(activities.items.count(where: { $0.kind == .remote }) == 150)
        #expect(activities.items.count(where: { $0.kind == .service }) == 150)
        #expect(activities.items.count(where: { $0.kind == .repository }) == RepositoryActivities.repositoryLimit)
    }

    /// 经生产解析器构造只含分支头的状态快照。
    private func status(oid: String) throws -> WorkingCopyStatus {
        try WorkingCopyStatus(porcelainV2: Data("# branch.oid \(oid)\0# branch.head main\0".utf8))
    }

    /// 一条已完成的记录。
    private func finished(_ kind: ActivityKind, in location: RepositoryLocation) -> RepositoryActivity {
        let activity = RepositoryActivity(kind: kind, repository: location, title: "Done")
        activity.state = "activity.finished"
        return activity
    }
}
