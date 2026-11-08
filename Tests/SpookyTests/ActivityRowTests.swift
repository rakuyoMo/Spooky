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

    /// Remote 页的标题随状态变化：进行中写进行时加远端名，拉取与推送再接 refspec，完成换成过去时；
    /// 失败与取消在进行时的写法后面接 failed、cancelled，用户由此看出操作停在了哪个远端的哪个分支。
    /// 没有单一远端的只写动词；较早保存、没有方向的记录与其余两页写操作名称。
    /// 行首图标：Remote 页按传输方向显示，失败或取消的用警告图标；Repository 与 Service 页是文件夹与账号，只有失败的用警告图标。
    /// 侧边栏底部的活动区共用按方向取的图标，失败与取消不换，结束的行仍看得出是哪种传输。
    @Test("标题与行首图标")
    func titleAndIcons() {
        let fetch = RepositoryActivity(
            kind: .remote,
            repository: location,
            title: "Quick Fetch",
            target: .fetch("origin")
        )
        let fetching = AppLocalization.text("activity.fetchingNamed", "origin")
        #expect(fetch.displayTitle == fetching)

        fetch.state = "activity.finished"
        #expect(fetch.displayTitle == AppLocalization.text("activity.fetchedNamed", "origin"))

        // 失败与取消接在进行时的写法后面
        fetch.state = "activity.failed"
        #expect(fetch.displayTitle == AppLocalization.text("activity.titleFailed", fetching))

        let push = RepositoryActivity(
            kind: .remote,
            repository: location,
            title: "Push",
            target: .push("fork", refspec: "refs/heads/main:refs/heads/main")
        )
        push.state = "activity.cancelled"

        let pushing = AppLocalization.text("activity.pushingNamed", "fork refs/heads/main:refs/heads/main")
        #expect(push.displayTitle == AppLocalization.text("activity.titleCancelled", pushing))

        // 同步里的拉取在获取与拉取两步都是进行时，远端名后接远端分支
        let sync = RepositoryActivity(
            kind: .remote,
            repository: location,
            title: "Sync",
            target: .pull("origin", refspec: "refs/heads/main")
        )
        sync.state = "sync.step.fetch"
        #expect(sync.displayTitle == AppLocalization.text("activity.pullingNamed", "origin refs/heads/main"))

        // 获取全部远端时没有单一的远端名，只写动词
        let all = RepositoryActivity(kind: .remote, repository: location, title: "Auto Fetch", target: .fetch(nil))
        all.state = "activity.finished"
        #expect(all.displayTitle == AppLocalization.text("activity.fetched"))

        // 没有方向的旧 Remote 记录与 Repository 页写操作名称
        let old = RepositoryActivity(kind: .remote, repository: location, title: "Fetch")
        #expect(old.displayTitle == "Fetch")

        let checkout = RepositoryActivity(kind: .repository, repository: location, title: "Check Out “main”")
        #expect(checkout.displayTitle == "Check Out “main”")

        // 各页的行首图标
        expectTransferIcons()
        expectFolderIcons()
    }

    /// Remote 页进行中的行写 In Progress…，结束后换成开始的日期，今天与昨天写作相对的说法、更早的写完整日期，都不写时间；
    /// 其余两页写两位小数的耗时，进行中的算到当前时间。
    /// 最后一行写日志的最后一个非空行，行首的空白原样保留：stderr 有内容时取它的，否则取 stdout 的；
    /// 没有日志时写状态，同步进行中是步骤名。
    @Test("右上角的时间与最后一行的文字")
    func cornerAndStatus() {
        let now = Date()
        let fetch = RepositoryActivity(
            kind: .remote,
            repository: location,
            title: "Fetch",
            started: now,
            target: .fetch("origin")
        )
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

        let old = RepositoryActivity(
            kind: .remote,
            repository: location,
            title: "Push",
            started: started,
            target: .push("origin")
        )
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

        // 最后一行取 stderr 的最后一个非空行
        let push = RepositoryActivity(kind: .remote, repository: location, title: "Push", target: .push("origin"))
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
        let sync = RepositoryActivity(kind: .remote, repository: location, title: "Sync", target: .pull("origin"))
        #expect(ActivityRow(activity: sync).status == AppLocalization.text("activity.running"))

        sync.state = "sync.step.push"
        #expect(ActivityRow(activity: sync).status == AppLocalization.text("sync.step.push"))

        let request = RepositoryActivity(kind: .service, repository: nil, title: "Verify Account")
        request.state = "activity.finished"
        #expect(ActivityRow(activity: request).status == AppLocalization.text("activity.finished"))
    }

    /// 进度是几个阶段的平均：推送以外的操作算 Compressing、Receiving、Resolving、Unpacking 四个阶段，没出现过的算 0，
    /// 各阶段取回车刷新后最新的百分比；跨块的行拼成整行再认，不是这些阶段的输出与 stdout 不改动已有的值。
    @Test("进度条的进度")
    func progress() {
        let fetch = RepositoryActivity(kind: .remote, repository: location, title: "Fetch", target: .fetch("origin"))
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
        let push = RepositoryActivity(kind: .remote, repository: location, title: "Push", target: .push("origin"))
        let writing = "Compressing objects: 100% (2/2), done.\nWriting objects:  50% (1/2)\r"
        push.append(.standardError(Data(writing.utf8)))
        #expect(push.progress == 0.5)
    }

    /// 两位小数、按系统地区数字格式的耗时。
    private func elapsed(_ seconds: TimeInterval) -> String {
        AppLocalization.text("activity.elapsed", seconds.formatted(.number.precision(.fractionLength(2))))
    }

    /// 核对 Remote 页各传输方向的行首图标与侧边栏底部的图标；较早保存、没有方向的记录与拉取同用一个图标。
    private func expectTransferIcons() {
        let warning = ActivityIcon.symbol("exclamationmark.triangle.fill")
        let transfers: [(ActivityTransfer?, ActivityIcon)] = [
            (.fetch, .transfer(.fetch)),
            (.pull, .transfer(.pull)),
            (.push, .transfer(.push)),
            (nil, .transfer(.pull)),
        ]

        for (transfer, icon) in transfers {
            let target = transfer.map { ActivityTarget(transfer: $0, remote: "origin", refspec: nil) }
            let activity = RepositoryActivity(kind: .remote, repository: location, title: "Remote", target: target)
            #expect(ActivityRow(activity: activity).leadingIcon == icon)
            #expect(activity.transferIcon == icon)

            activity.state = "activity.cancelled"
            #expect(ActivityRow(activity: activity).leadingIcon == warning)

            activity.state = "activity.failed"
            #expect(ActivityRow(activity: activity).leadingIcon == warning)

            // 侧边栏底部的活动区按方向取图标，失败与取消不换
            #expect(activity.transferIcon == icon)
        }
    }

    /// 核对 Repository 与 Service 页的行首图标：取消时不换，失败时换成警告图标。
    private func expectFolderIcons() {
        let warning = ActivityIcon.symbol("exclamationmark.triangle.fill")
        let folders: [(ActivityKind, ActivityIcon)] = [
            (.repository, .symbol("folder")),
            (.service, .symbol("person.crop.circle")),
        ]

        for (kind, icon) in folders {
            let activity = RepositoryActivity(kind: kind, repository: location, title: "Other")

            activity.state = "activity.cancelled"
            #expect(ActivityRow(activity: activity).leadingIcon == icon)

            activity.state = "activity.failed"
            #expect(ActivityRow(activity: activity).leadingIcon == warning)
        }
    }
}
