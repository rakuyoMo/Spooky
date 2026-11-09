import AppKit
import ApplicationServices
import Foundation
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Drop Targets

extension OperationWiringTests {
    /// Working Copy 行与 HEAD 分支行是不同落点：按住 ⌥ 拖远端分支只在 HEAD 分支行设为上游，在 Working Copy 行没有动作、不回退为拉取；
    /// 拖动影像上的动作名随落点与 ⌥ 切换；本地分支拖到远端分支打开预选了这两个分支的 Push Branch 对话框，不经通用推送表单。
    @Test("引用落点：Working Copy 与 HEAD、动作名与 Push Branch 请求")
    func dropTargets() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let session = fixture.session
        let upstream = try fixture.payload(.remote, "refs/remotes/origin/main")
        let side = try fixture.payload(.local, "refs/heads/side")
        let commit = try fixture.payload(.commit, try #require(fixture.ids["D"]))

        // Working Copy 行：远端分支是拉取，按住 ⌥ 没有动作；提交仍是摘取
        #expect(fixture.dropTitle(upstream, on: .workingCopy) == AppLocalization.text("sync.pull"))
        #expect(fixture.dropTitle(upstream, on: .workingCopy, alternate: true) == nil)
        #expect(fixture.dropTitle(commit, on: .workingCopy) == AppLocalization.text("rewrite.cherryPick"))

        // HEAD 分支行：动作名随 ⌥ 在 Pull 与 Track 之间切换，⌥ 时设为当前分支的上游
        #expect(fixture.dropTitle(upstream, on: .head) == AppLocalization.text("sync.pull"))

        let track = ReferenceDropAction(payloads: [upstream], destination: .head, alternate: true, session: session)

        guard case .upstream(let remote, let branch) = track else {
            Issue.record("按住 ⌥ 拖到 HEAD 分支行应设为上游")
            return
        }

        #expect([remote.id, branch.id] == ["refs/remotes/origin/main", "refs/heads/main"])
        #expect(track?.title == AppLocalization.text("branch.dragTrack"))

        // 拖到 Branches 写 Track，拖到远端写 Publish
        #expect(fixture.dropTitle(upstream, on: .branches) == AppLocalization.text("branch.dragTrack"))
        #expect(fixture.dropTitle(side, on: .remote("origin")) == AppLocalization.text("branch.dragPublish"))

        // 非 HEAD 的本地分支拖到远端分支：请求只带这两个分支
        var requests: [PushBranchRequest] = []
        session.onPushBranchRequest = { requests.append($0) }

        let push = ReferenceDropAction(
            payloads: [side],
            destination: .remoteBranch("origin", "refs/remotes/origin/main"),
            alternate: false,
            session: session
        )

        push?.perform(in: session) { _ in Issue.record("不应打开通用的推送表单") }

        #expect(requests.map(\.localBranch) == ["refs/heads/side"])
        #expect(requests.map(\.remoteBranch) == ["refs/remotes/origin/main"])
    }

    /// 徽标加在来源影像的右侧并竖直居中；换动作名时替换而不叠加，去掉时只剩来源给出的组件；
    /// 落点在拖动离开时去掉自己加上的徽标，拖到无效位置时影像上不留动作名。
    @Test("拖动影像上的徽标")
    func dragBadge() throws {
        let item = NSDraggingItem(pasteboardWriter: NSPasteboardItem())
        let icon = NSDraggingImageComponent(key: .icon)
        let label = NSDraggingImageComponent(key: .label)

        icon.frame = NSRect(x: 0, y: 0, width: 22, height: 22)
        label.frame = NSRect(x: 24, y: 3, width: 150, height: 16)
        item.imageComponentsProvider = { [icon, label] }

        /// 拖动项当前的组件。
        func components() -> [NSDraggingImageComponent] {
            item.imageComponentsProvider?() ?? []
        }

        DragBadge.apply("Track", to: item)

        let tracked = try #require(components().last)

        #expect(components().map(\.key) == [.icon, .label, DragBadge.key])
        #expect(tracked.frame.minX == 184)
        #expect(tracked.frame.midY == 11)

        // 换成更长的动作名：仍只有一个徽标，宽度随文字变化
        DragBadge.apply("Publish Something", to: item)

        #expect(components().map(\.key) == [.icon, .label, DragBadge.key])
        #expect((components().last?.frame.width ?? 0) > tracked.frame.width)

        // 无效落点去掉徽标，来源组件的位置不变
        DragBadge.apply(nil, to: item)

        #expect(components().map(\.key) == [.icon, .label])
        #expect(components().map(\.frame) == [icon.frame, label.frame])

        // 落点：进入时加上动作名，离开时去掉
        let target = DropTargetView(type: .string)
        let info = DraggingInfoStub(item: item)

        target.resolve = { _ in DropBadgeAction(title: "Publish") { true } }

        #expect(target.draggingEntered(info) == .copy)
        #expect(components().map(\.key) == [.icon, .label, DragBadge.key])

        target.draggingExited(info)

        #expect(components().map(\.key) == [.icon, .label])
    }

    /// 拖动结束时历史列表移除落点旁的动作名，结束的处理不交给 NSTableView：它没有实现这个方法，
    /// 交给它会抛出异常，经过列表的拖动来源之后再也拖不起来。
    @Test("拖动结束时历史列表的收尾")
    func historyDragEnded() {
        let table = HistoryCommitTable.CommitTableView()
        let rows = SingleRowSource()

        table.addTableColumn(NSTableColumn(identifier: .init("commit")))
        table.dataSource = rows
        table.reloadData()

        /// 表格里落点旁的动作名。
        func labels() -> [NSView] {
            table.subviews.filter { $0 is NSHostingView<DropActionLabel> }
        }

        table.dropLabel.show("Squash", row: 0, between: false, in: table)

        #expect(labels().count == 1)

        let item = NSDraggingItem(pasteboardWriter: NSPasteboardItem())

        table.draggingEnded(DraggingInfoStub(item: item))

        #expect(labels().isEmpty)
    }

    /// 打开时两个下拉按拖动源与落点预选；提交只把这个非 HEAD 本地分支推到这个远端分支，推送表单保存的全部标签与递归子模块
    /// 都开着也不带上，HEAD 不变；推到会回退远端分支的目标时 Git 照常按非快进拒绝。
    @Test("Push Branch 对话框的预选与单分支推送", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func pushBranchDialog() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let runner = fixture.runner
        let session = fixture.session
        let remote = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: remote) }

        // origin 换成单独的裸仓库：远端 main 是本地 main，topic 停在 A，本地 side 比它多一个提交 S
        let a = try #require(fixture.ids["A"])
        _ = try await runner.run(["init", "--bare", "-q", remote.path])
        _ = try await runner.run(["config", "--local", "remote.origin.url", remote.path])
        _ = try await runner.run(["push", "-q", "origin", "refs/heads/main:refs/heads/main", a + ":refs/heads/topic"])
        _ = try await runner.run(["fetch", "-q", "origin"])
        await Self.reloadReferences(session)

        let defaults = try #require(UserDefaults(suiteName: remote.appending(path: "defaults").path))
        defaults.set(true, forKey: "pushAllTags")
        defaults.set(true, forKey: "pushRecurseSubmodules")

        let request = PushBranchRequest(localBranch: "refs/heads/side", remoteBranch: "refs/remotes/origin/topic")
        let submit = AppLocalization.text("sync.pushBranch")
        var closed = false

        let elements = await AccessibilityProbe.elements(width: 450, pressing: [submit], until: { _ in closed }) {
            PushBranchDialog(session: session, request: request, close: { closed = true })
                .defaultAppStorage(defaults)
        }

        await session.writeTask?.value

        // 只有两个下拉，按请求预选；没有选项区
        let popUps = elements.filter { $0.role == "AXPopUpButton" }.sorted { $0.frame.minY < $1.frame.minY }

        #expect(popUps.map(\.value) == ["side", "origin/topic"])
        #expect(!elements.contains { $0.name == AppLocalization.text("dialog.options") })

        // 远端只多了 topic 的新版本，没有标签；HEAD 仍是 main
        let side = try await RepositoryReferences(runner: runner).resolve("refs/heads/side")
        let main = try await RepositoryReferences(runner: runner).resolve("refs/heads/main")
        let refs = try await runner.run(["ls-remote", remote.path])
        let listed = String(decoding: refs, as: UTF8.self)

        #expect(listed.contains(side + "\trefs/heads/topic"))
        #expect(listed.contains(main + "\trefs/heads/main"))
        #expect(!listed.contains("refs/tags/"))
        #expect(session.status?.branch.head == "main")

        // side 推到远端 main 会回退它：按非快进拒绝，远端 main 不变
        var failure: AppFailure? = nil
        session.onFailure = { failure = $0 }
        defer { session.onFailure = nil }

        await Self.reloadReferences(session)

        let branches = session.history.branches
        let local = try #require(branches.first { $0.id == "refs/heads/side" })
        let target = try #require(branches.first { $0.id == "refs/remotes/origin/main" })

        #expect(session.pushBranch(local, to: target))
        await session.writeTask?.value

        let after = String(decoding: try await runner.run(["ls-remote", remote.path, "refs/heads/main"]), as: UTF8.self)

        #expect(failure != nil)
        #expect(after.hasPrefix(main))
    }
}

// MARK: - Drop Target Helpers

extension OperationWiringTests {
    /// 刷新会话，等引用与列表读完。
    private static func reloadReferences(_ session: RepositorySession) async {
        session.refresh(full: true)
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }
    }
}

extension OperationWiringTests.Fixture {
    /// 本仓库里这个来源的载荷。
    @MainActor
    func payload(_ kind: RepositoryDragPayload.Kind, _ reference: String) throws -> RepositoryDragPayload {
        RepositoryDragPayload(repository: try #require(session.repository), kind: kind, reference: reference)
    }

    /// 这个来源拖到落点时拖动影像上的动作名；没有动作时为 nil。
    @MainActor
    func dropTitle(
        _ payload: RepositoryDragPayload,
        on destination: RepositoryDropDestination,
        alternate: Bool = false
    ) -> String? {
        let action = ReferenceDropAction(
            payloads: [payload],
            destination: destination,
            alternate: alternate,
            session: session
        )

        return action?.title
    }
}

// MARK: - DraggingInfoStub

/// 只带一个拖动项的拖动信息，供直接调用落点的拖放方法。
@MainActor
private final class DraggingInfoStub: NSObject, @MainActor NSDraggingInfo {
    /// 唯一的拖动项。
    let item: NSDraggingItem

    /// 拖动的格式。
    var draggingFormation = NSDraggingFormation.default

    /// 落下后是否动画移到落点。
    var animatesToDestination = false

    /// 落点接受的拖动项个数。
    var numberOfValidItemsForDrop = 1

    /// 用到时才建的独立粘贴板，不碰系统的拖放粘贴板。
    lazy var draggingPasteboard = NSPasteboard.withUniqueName()

    /// 落点所在的窗口；直接调用落点的方法时没有窗口。
    var draggingDestinationWindow: NSWindow? { nil }

    /// 来源允许的操作。
    var draggingSourceOperationMask: NSDragOperation { .copy }

    /// 光标在落点窗口里的位置。
    var draggingLocation: NSPoint { .zero }

    /// 拖动影像的位置。
    var draggedImageLocation: NSPoint { .zero }

    /// 拖动影像。
    var draggedImage: NSImage? { nil }

    /// 拖动来源；别处拖来时为 nil。
    var draggingSource: Any? { nil }

    /// 拖动的序号。
    var draggingSequenceNumber: Int { 1 }

    /// 弹簧加载的高亮。
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }

    /// 建出只有这个拖动项的拖动信息。
    ///
    /// - Parameter item: 拖动项。
    init(item: NSDraggingItem) {
        self.item = item
    }

    /// 把唯一的拖动项交给回调。
    func enumerateDraggingItems(
        options _: NSDraggingItemEnumerationOptions = [],
        for _: NSView?,
        classes _: [AnyClass],
        searchOptions _: [NSPasteboard.ReadingOptionKey: Any] = [:],
        using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {
        var stop = ObjCBool(false)
        block(item, 0, &stop)
    }

    /// 不移动拖动影像。
    func slideDraggedImage(to _: NSPoint) { }

    /// 没有承诺的文件。
    override func namesOfPromisedFilesDropped(atDestination _: URL) -> [String]? { nil }

    /// 没有弹簧加载。
    func resetSpringLoading() { }
}

// MARK: - SingleRowSource

/// 只有一行的表格数据源，让落点旁的动作名有行可贴。
@MainActor
private final class SingleRowSource: NSObject, NSTableViewDataSource {
    /// 固定一行。
    func numberOfRows(in _: NSTableView) -> Int { 1 }
}
