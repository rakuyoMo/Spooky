import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ActivityRowTests

/// Activity 列表的行：标题、右上角的时间、最后一行的文字、行首图标，以及 Remote 页进行中的进度条。
@MainActor
struct ActivityRowTests {
    /// 测试记录所属的仓库。
    private let location = RepositoryLocation.local(path: "/tmp/Alpha")

    /// 测试记录的开始时间。
    private let started = Date(timeIntervalSince1970: 1_700_000_000)

    /// Remote 页的标题随状态变化：进行中写进行时加远端名，完成换成过去时；失败与取消在进行时的写法后面接 failed、cancelled，
    /// 用户由此看出操作停在了哪个远端。没有单一远端的只写动词；较早保存、没有方向的记录与其余两页写操作名称。
    @Test("标题")
    func title() throws {
        let english = try #require(
            AppLocalization.bundle
                .url(forResource: "en", withExtension: "lproj")
                .flatMap(Bundle.init(url:))
        )

        /// 按英文资源取的标题。
        func text(_ key: String, _ argument: String? = nil) -> String {
            let format = english.localizedString(forKey: key, value: nil, table: nil)
            return argument.map { String(format: format, $0) } ?? format
        }

        let fetch = RepositoryActivity(
            kind: .remote,
            repository: location,
            title: "Quick Fetch",
            transfer: .fetch,
            remote: "origin"
        )
        #expect(ActivityRow(activity: fetch).title == AppLocalization.text("activity.fetchingNamed", "origin"))
        #expect(text("activity.fetchingNamed", "origin") == "Fetching origin")

        fetch.state = "activity.finished"
        #expect(ActivityRow(activity: fetch).title == AppLocalization.text("activity.fetchedNamed", "origin"))
        #expect(text("activity.fetchedNamed", "origin") == "Fetched origin")

        // 失败与取消接在进行时的写法后面
        fetch.state = "activity.failed"
        let fetching = AppLocalization.text("activity.fetchingNamed", "origin")
        #expect(ActivityRow(activity: fetch).title == AppLocalization.text("activity.titleFailed", fetching))
        #expect(text("activity.titleFailed", text("activity.fetchingNamed", "origin")) == "Fetching origin failed")

        let push = RepositoryActivity(
            kind: .remote,
            repository: location,
            title: "Push",
            transfer: .push,
            remote: "fork"
        )
        push.state = "activity.cancelled"
        let pushing = AppLocalization.text("activity.pushingNamed", "fork")
        #expect(ActivityRow(activity: push).title == AppLocalization.text("activity.titleCancelled", pushing))
        #expect(text("activity.titleCancelled", text("activity.pushingNamed", "fork")) == "Pushing fork cancelled")

        // 同步进行中的步骤仍是进行时
        let sync = RepositoryActivity(
            kind: .remote,
            repository: location,
            title: "Sync",
            transfer: .sync,
            remote: "origin"
        )
        sync.state = "sync.step.push"
        #expect(ActivityRow(activity: sync).title == AppLocalization.text("activity.syncingNamed", "origin"))

        // 获取全部远端时没有单一的远端名，只写动词
        let all = RepositoryActivity(kind: .remote, repository: location, title: "Auto Fetch", transfer: .fetch)
        all.state = "activity.finished"
        #expect(ActivityRow(activity: all).title == AppLocalization.text("activity.fetched"))
        #expect(text("activity.fetched") == "Fetched")

        // 没有方向的旧 Remote 记录与 Repository 页写操作名称
        let old = RepositoryActivity(kind: .remote, repository: location, title: "Fetch")
        #expect(ActivityRow(activity: old).title == "Fetch")

        let checkout = RepositoryActivity(kind: .repository, repository: location, title: "Check Out “main”")
        #expect(ActivityRow(activity: checkout).title == "Check Out “main”")
    }

    /// Remote 页进行中的行写 In Progress…，结束后换成开始的日期，今天与昨天写作相对的说法、更早的写完整日期，都不写时间；
    /// 其余两页写两位小数的耗时，进行中的算到当前时间。
    @Test("右上角的时间")
    func corner() throws {
        let now = Date()
        let fetch = RepositoryActivity(kind: .remote, repository: location, title: "Fetch", started: now, transfer: .fetch)
        #expect(ActivityRow(activity: fetch).corner(now: now) == AppLocalization.text("activity.inProgress"))

        // 结束后按开始的日期写，与系统的相对日期写法相同
        let relative = DateFormatter()
        relative.dateStyle = .long
        relative.timeStyle = .none
        relative.doesRelativeDateFormatting = true

        let absolute = DateFormatter()
        absolute.dateStyle = .long
        absolute.timeStyle = .none

        fetch.state = "activity.finished"
        #expect(ActivityRow(activity: fetch).corner(now: now) == relative.string(from: now))
        #expect(ActivityRow(activity: fetch).corner(now: now) != absolute.string(from: now))

        let old = RepositoryActivity(kind: .remote, repository: location, title: "Push", started: started, transfer: .push)
        old.state = "activity.failed"
        #expect(ActivityRow(activity: old).corner(now: now) == absolute.string(from: started))

        // Repository 与 Service 页：进行中的算到当前时间，结束的写开始到结束
        for kind in [ActivityKind.repository, .service] {
            let activity = RepositoryActivity(kind: kind, repository: location, title: "Other", started: started)
            #expect(ActivityRow(activity: activity).corner(now: started.addingTimeInterval(1.5)) == elapsed(1.5))

            activity.state = "activity.finished"
            activity.ended = started.addingTimeInterval(0.034)
            #expect(ActivityRow(activity: activity).corner(now: now) == elapsed(0.034))
        }

        let english = try #require(
            AppLocalization.bundle
                .url(forResource: "en", withExtension: "lproj")
                .flatMap(Bundle.init(url:))
        )

        #expect(english.localizedString(forKey: "activity.elapsed", value: nil, table: nil) == "%@ sec")
        #expect(english.localizedString(forKey: "activity.inProgress", value: nil, table: nil) == "In Progress…")
    }

    /// 最后一行写日志的最后一个非空行，行首的空白原样保留：stderr 有内容时取它的，否则取 stdout 的；
    /// 没有日志时写状态，同步进行中是步骤名。
    @Test("最后一行的文字")
    func status() {
        let push = RepositoryActivity(kind: .remote, repository: location, title: "Push", transfer: .push)
        push.append(.standardOutput(Data("ignored\n".utf8)))
        push.append(.standardError(Data("To /tmp/remote.git\n   1a2b3c4..5d6e7f8  main -> main\n  \n".utf8)))
        push.state = "activity.finished"
        #expect(ActivityRow(activity: push).status == "   1a2b3c4..5d6e7f8  main -> main")

        // 读取记录的一行结果写在 stdout
        let read = RepositoryActivity(kind: .repository, repository: location, title: "Update Branches")
        read.append(.standardOutput(Data("0 updated, 1 added, 0 deleted".utf8)))
        read.state = "activity.finished"
        #expect(ActivityRow(activity: read).status == "0 updated, 1 added, 0 deleted")

        // 没有日志：进行中、同步的步骤、结束
        let sync = RepositoryActivity(kind: .remote, repository: location, title: "Sync", transfer: .sync)
        #expect(ActivityRow(activity: sync).status == AppLocalization.text("activity.running"))

        sync.state = "sync.step.push"
        #expect(ActivityRow(activity: sync).status == AppLocalization.text("sync.step.push"))

        let request = RepositoryActivity(kind: .service, repository: nil, title: "Verify Account")
        request.state = "activity.finished"
        #expect(ActivityRow(activity: request).status == AppLocalization.text("activity.finished"))
    }

    /// Remote 页按传输方向显示图标，同步与拉取同用一个，失败或取消的用警告图标；
    /// Repository 与 Service 页是文件夹与账号，只有失败的用警告图标。
    @Test("行首图标")
    func symbols() {
        let warning = "exclamationmark.triangle.fill"

        // 较早保存、没有方向的 Remote 记录与拉取同用一个图标
        let transfers: [(ActivityTransfer?, String)] = [
            (.fetch, "arrow.down.circle"),
            (.pull, "arrow.down.to.line"),
            (.push, "arrow.up.circle"),
            (.sync, "arrow.down.to.line"),
            (nil, "arrow.down.to.line"),
        ]

        for (transfer, symbol) in transfers {
            let activity = RepositoryActivity(kind: .remote, repository: location, title: "Remote", transfer: transfer)
            #expect(ActivityRow(activity: activity).symbol == symbol)

            activity.state = "activity.cancelled"
            #expect(ActivityRow(activity: activity).symbol == warning)

            activity.state = "activity.failed"
            #expect(ActivityRow(activity: activity).symbol == warning)
        }

        for (kind, symbol) in [(ActivityKind.repository, "folder"), (.service, "person.crop.circle")] {
            let activity = RepositoryActivity(kind: kind, repository: location, title: "Other")

            activity.state = "activity.cancelled"
            #expect(ActivityRow(activity: activity).symbol == symbol)

            activity.state = "activity.failed"
            #expect(ActivityRow(activity: activity).symbol == warning)
        }
    }

    /// 进度是几个阶段的平均：推送以外的操作算 Compressing、Receiving、Resolving、Unpacking 四个阶段，没出现过的算 0，
    /// 各阶段取回车刷新后最新的百分比；跨块的行拼成整行再认，不是这些阶段的输出与 stdout 不改动已有的值。
    @Test("进度条的进度")
    func progress() {
        let fetch = RepositoryActivity(kind: .remote, repository: location, title: "Fetch", transfer: .fetch)
        #expect(fetch.progress == nil)

        // 只有数量的阶段与 Counting 不算进度
        fetch.append(.standardError(Data("remote: Enumerating objects: 12, done.\n".utf8)))
        fetch.append(.standardError(Data("remote: Counting objects:  50% (6/12)\r".utf8)))
        #expect(fetch.progress == nil)

        // 一块里刷新几次，取最新的；四个阶段只出现了一个
        let compressed = "remote: Compressing objects:  50% (3/6)\rremote: Compressing objects: 100% (6/6), done.\n"
        fetch.append(.standardError(Data(compressed.utf8)))
        #expect(fetch.progress == 0.25)

        // 下一个阶段的一行拆在两块里
        fetch.append(.standardError(Data("Receiving objects:  5".utf8)))
        #expect(fetch.progress == 0.25)

        fetch.append(.standardError(Data("0% (6/12)".utf8)))
        #expect(fetch.progress == 0.375)

        let received = "\rReceiving objects: 100% (12/12), done.\nResolving deltas: 100% (2/2), done.\n"
        fetch.append(.standardError(Data(received.utf8)))
        #expect(fetch.progress == 0.75)

        fetch.append(.standardError(Data("From /tmp/origin\n * [new branch]      main       -> origin/main\n".utf8)))
        #expect(fetch.progress == 0.75)

        fetch.append(.standardOutput(Data("Unpacking objects: 100% (12/12)\n".utf8)))
        #expect(fetch.progress == 0.75)
        #expect(ActivityRow(activity: fetch).status == " * [new branch]      main       -> origin/main")

        // 推送算 Compressing、Writing、Unpacking 三个阶段
        let push = RepositoryActivity(kind: .remote, repository: location, title: "Push", transfer: .push)
        let writing = "Compressing objects: 100% (2/2), done.\nWriting objects:  50% (1/2)\r"
        push.append(.standardError(Data(writing.utf8)))
        #expect(push.progress == 0.5)
    }

    /// 两位小数、按系统地区数字格式的耗时。
    private func elapsed(_ seconds: TimeInterval) -> String {
        AppLocalization.text("activity.elapsed", seconds.formatted(.number.precision(.fractionLength(2))))
    }
}
