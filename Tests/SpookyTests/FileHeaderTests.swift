import AppKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 文件详情头部的原生控件、目录动作与重命名显示。
@MainActor
struct FileHeaderTests {
    /// 比较侧整体禁用不改变所选侧，各段仍保留各自的可用性；动作分段使用瞬时动作，禁用段不会执行，刷新后使用新的闭包。
    @Test("比较侧与动作分段的原生控件")
    func controls() {
        let cases: [(Bool, Bool, Bool, DiffSide)] = [
            (false, true, true, .unstaged),
            (true, false, true, .staged),
            (true, true, true, .staged),
            (false, true, false, .unstaged),
        ]

        for (staged, unstaged, enabled, side) in cases {
            expectSides(staged: staged, unstaged: unstaged, enabled: enabled, side: side)
        }

        // 动作分段按标题布局
        var invoked = 0
        var focused = false

        let actions = [
            FileViewAction(title: "Blame", enabled: false) { invoked += 1 },
            FileViewAction(title: "File History") { invoked += 10 },
            FileViewAction(title: "Diff Tool") { invoked += 100 },
        ]

        let control = FileActionSegmentControl(actions: actions) { focused = $0 }
        #expect(control.segmentStyle == .texturedRounded)
        #expect(control.trackingMode == .momentary)
        #expect(control.controlSize == .regular)
        #expect((0 ..< 3).map { control.label(forSegment: $0) } == actions.map(\.title))
        #expect(!control.isEnabled(forSegment: 0))
        #expect(control.intrinsicContentSize.width > 0)

        // 瞬时控件只在鼠标事件派发期间保留选中段；直接派发测试先建立可保存的选中段。
        control.trackingMode = .selectOne
        control.selectedSegment = 0
        control.sendAction(control.action, to: control.target)
        #expect(invoked == 0)

        control.selectedSegment = 1
        control.sendAction(control.action, to: control.target)
        #expect(invoked == 10)

        // 键盘焦点通知
        #expect(control.becomeFirstResponder())
        #expect(focused)
        #expect(control.resignFirstResponder())
        #expect(!focused)

        // 刷新后使用新的闭包
        control.configure(actions: [FileViewAction(title: "Updated") { invoked += 1000 }], focusChanged: { _ in })
        control.selectedSegment = 0
        control.sendAction(control.action, to: control.target)
        #expect(invoked == 1010)
    }

    /// 重命名的完整旧路径在树形与平铺里都可见，复制不使用重命名箭头。
    @Test("重命名列表保留旧路径与新路径层级")
    func renamedPaths() {
        let entries = [
            StatusEntry(
                kind: .tracked,
                path: "src/new.swift",
                originalPath: "src/old.swift",
                staged: .renamed
            ),
            StatusEntry(
                kind: .tracked,
                path: "文档/新 文件.md",
                originalPath: "old/说明.md",
                unstaged: .renamed
            ),
        ]

        for entry in entries {
            let node = WorkingCopyFileList.Node(path: entry.path, entry: entry)
            let old = entry.originalPath ?? ""
            let name = RepositorySession.fileName(entry.path)
            #expect(WorkingCopyFileList.Coordinator.pathTitle(node, tree: false) == "\(old) → \(entry.path)")
            #expect(WorkingCopyFileList.Coordinator.pathTitle(node, tree: true) == "\(old) → \(name)")
            #expect(node.path == entry.path)
        }

        let copied = StatusEntry(kind: .tracked, path: "copy.txt", originalPath: "source.txt", staged: .copied)
        let node = WorkingCopyFileList.Node(path: copied.path, entry: copied)
        #expect(WorkingCopyFileList.Coordinator.pathTitle(node, tree: false) == "copy.txt")
        #expect(RepositorySession.fileName("文档 [v2]/目录/头部.swift") == "头部.swift")
        #expect(RepositorySession.fileName("文档 [v2]/目录/") == "目录")
    }

    /// 目录历史按字面路径限定提交，合成目录和末尾斜线条目使用同样的入口。
    @Test("目录头部只启用历史并排除目录外提交")
    func directoryActions() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)

        // 目录里的提交在前，目录外的提交在后
        let path = "文档 [v2]"
        try FileManager.default.createDirectory(at: directory.appending(path: path), withIntermediateDirectories: false)
        try Data("one\n".utf8).write(to: directory.appending(path: path + "/a.txt"))
        try Data("two\n".utf8).write(to: directory.appending(path: path + "/b.txt"))
        _ = try await runner.run(["add", "."])
        _ = try await runner.run(["commit", "-qm", "directory"])

        try Data("outside\n".utf8).write(to: directory.appending(path: "outside.txt"))
        _ = try await runner.run(["add", "."])
        _ = try await runner.run(["commit", "-qm", "outside"])

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()

        // 末尾斜线的目录只启用历史
        let actions = session.workingCopyFileActions(path + "/", entry: nil, isDirectory: true)
        #expect(actions.map(\.enabled) == [false, true, false])
        #expect(actions.map(\.title) == [
            AppLocalization.text("blame.title"),
            AppLocalization.text("fileHistory.title"),
            AppLocalization.text("externalTool.action.diffTool"),
        ])

        actions[1].perform()
        await until { session.fileHistory.totalCount != nil }
        #expect(session.fileHistory.path == path)
        #expect(session.fileHistory.commits.map(\.subject) == ["directory"])

        // 冲突文件不能交给外部 Diff 工具
        let conflict = StatusEntry(kind: .conflicted, path: "conflict.txt")
        #expect(!session.workingCopyFileActions(conflict.path, entry: conflict, isDirectory: false)[2].enabled)

        // 没有提交的目录
        session.showFileHistory("empty/")
        await until { session.fileHistory.totalCount != nil }
        #expect(session.fileHistory.commits.isEmpty)
    }

    /// 用比较侧选择器配置一个原生分段控件，核对样式、整体与各段可用性及所选侧。
    private func expectSides(staged: Bool, unstaged: Bool, enabled: Bool, side: DiffSide) {
        let picker = DiffSidePicker(side: .constant(side), staged: staged, unstaged: unstaged, enabled: enabled)

        let control = NSSegmentedControl(
            labels: ["Staged", "Unstaged"],
            trackingMode: .selectOne,
            target: nil,
            action: nil
        )

        picker.configure(control)
        #expect(control.segmentStyle == .rounded)
        #expect(control.controlSize == .regular)
        #expect(control.trackingMode == .selectOne)
        #expect(control.isEnabled == enabled)
        #expect(control.isEnabled(forSegment: 0) == staged)
        #expect(control.isEnabled(forSegment: 1) == unstaged)
        #expect(control.selectedSegment == (side == .staged ? 0 : 1))
    }
}
