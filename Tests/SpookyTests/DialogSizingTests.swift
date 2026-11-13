import AppKit
import SpookyKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky

// MARK: - DialogSizingTests

/// 经 `DialogWindow` 挂成 sheet 的对话框：窗口尺寸由骨架报上的理想尺寸驱动，显示前就排成理想尺寸，
/// 显示期间内容变高、变矮时窗口跟着变到新的理想尺寸；可以拉大的对话框收起选项区时减去它的高度，再展开时回到收起前的高度。
/// 打开后高度会变的弹窗都经 `DialogWindow` 呈现，才能用上这套尺寸跟随。
@MainActor
struct DialogSizingTests {
    /// 挂上时的尺寸、错误区出现与内容区加行后的尺寸，以及可以拉大的窗口切换选项区。
    @Test("对话框窗口的尺寸跟随内容")
    func windowFollowsContent() async throws {
        let parent = Self.parentWindow()
        defer { parent.close() }

        // 挂上时已是理想尺寸
        let model = Model()
        DialogWindow.present(on: parent) { _ in ProbeDialog(model: model) }

        let sheet = try await PromptDialogTests.attachedSheet(of: parent)

        #expect(Self.contentSize(of: sheet) == Self.idealSize(of: model))

        // 错误区出现由骨架带上动画，内容区加行经 `DialogAnimation`；窗口最后都停在新的理想尺寸
        model.error = "The name is already in use."

        let withError = Self.idealSize(of: model)

        await until { Self.contentSize(of: sheet) == withError }

        DialogAnimation.perform { model.rows = 3 }

        let withRows = Self.idealSize(of: model)

        #expect(withRows.height > withError.height)

        await until { Self.contentSize(of: sheet) == withRows }

        parent.endSheet(sheet)
        await until { parent.attachedSheet == nil }

        // 可以拉大的窗口：收起时减去选项区的高度，展开时回到收起前的高度
        let resizable = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )

        let sizing = DialogSizing(window: resizable)

        sizing.toggleOptions(expanded: false, optionsHeight: 150)

        #expect(Self.contentSize(of: resizable).height == 250)

        sizing.toggleOptions(expanded: true, optionsHeight: 150)

        #expect(Self.contentSize(of: resizable).height == 400)
    }

    /// 应用级模态窗口里改尺寸不做动画：调用返回时窗口已是新的尺寸。
    @Test("应用级模态窗口里尺寸一次到位")
    func modalWindowResizesAtOnce() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false

        let sizing = DialogSizing(window: window)
        let session = NSApp.beginModalSession(for: window)

        defer {
            NSApp.endModalSession(session)
            window.close()
        }

        // 模态期间窗口在前且可见，对话框的动画为空
        #expect(window.isVisible)
        #expect(DialogAnimation.current == nil)

        sizing.fit(CGSize(width: 480, height: 320))

        #expect(Self.contentSize(of: window).height == 320)
    }

    /// 账号、身份档案、应用图标与仓库设置的值：打开后错误区或表单行会出现，都经对话框窗口挂成 sheet。
    @Test("打开后会变高的弹窗经对话框窗口呈现")
    func growingDialogsUseDialogWindow() async throws {
        let parent = Self.parentWindow()
        defer { parent.close() }

        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 账号：偏好是没有内容的临时域，令牌存在内存里
        let defaults = try #require(UserDefaults(suiteName: "spooky-dialog-sizing-" + UUID().uuidString))
        let accounts = HostingAccounts(defaults: defaults, credentials: MemoryCredentials())

        AccountDialog.present(.add(.github), accounts: accounts, in: parent)

        try await Self.expectDialogWindow(on: parent)

        // 身份档案：不在已有档案里，是新建
        UserProfileEditor.present(
            UserProfile(title: "Work", name: "", email: ""),
            profiles: [],
            keys: [],
            in: parent,
            save: { _ in },
            closed: { }
        )

        try await Self.expectDialogWindow(on: parent)

        // 应用图标：控制器指向临时 App
        let controller = try AppIconController(
            defaults: defaults,
            bundle: #require(Bundle(url: AppIconControllerTests.makeApp(in: directory))),
            restartDock: { }
        )

        AppIconPickerDialog.present(controller: controller, in: parent)

        try await Self.expectDialogWindow(on: parent)

        // 仓库设置的值：设置与概况从临时仓库读出
        let repository = directory.appending(path: "repository", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: repository.path))
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        let general = try await RepositoryGeneralSettings(
            session: session,
            settings: runner.repositorySettings(),
            summary: runner.repositorySummary()
        )

        general.edit(.lineLimit, in: parent)

        try await Self.expectDialogWindow(on: parent)
    }
}

// MARK: - Helpers

extension DialogSizingTests {
    /// 挂 sheet 用的发起窗口；调用方负责关闭。
    private static func parentWindow() -> NSWindow {
        let parent = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        parent.isReleasedWhenClosed = false
        parent.orderFront(nil)

        return parent
    }

    /// 等 sheet 挂上，核对它是对话框窗口，再取下。
    ///
    /// 对话框窗口的内容控制器以 `DialogWindowContent` 为根视图；它的内容类型各不相同，按类型名的前缀认。
    private static func expectDialogWindow(on parent: NSWindow) async throws {
        let sheet = try await PromptDialogTests.attachedSheet(of: parent)
        let controller = try #require(sheet.contentViewController)

        #expect(String(describing: type(of: controller)).hasPrefix("NSHostingController<DialogWindowContent<"))

        parent.endSheet(sheet)
        await until { parent.attachedSheet == nil }
    }

    /// 窗口内容区的尺寸。
    private static func contentSize(of window: NSWindow) -> CGSize {
        window.contentRect(forFrameRect: window.frame).size
    }

    /// 对话框内容按理想尺寸排出的大小。
    private static func idealSize(of model: Model) -> CGSize {
        NSHostingController(rootView: ProbeDialog(model: model)).sizeThatFits(in: DialogSizing.unconstrained)
    }
}

// MARK: - Model

/// 测试对话框的状态：错误与内容区的行数。
@MainActor
@Observable
private final class Model {
    /// 错误区的文字；为 nil 时错误区收起。
    var error: String? = nil

    /// 内容区的行数。
    var rows = 1
}

// MARK: - ProbeDialog

/// 内容区是若干 30 pt 高的行的对话框。
private struct ProbeDialog: View {
    /// 对话框的状态。
    let model: Model

    /// 骨架的表单版。
    var body: some View {
        DialogLayout(
            title: "Rename",
            message: "Enter a new name.",
            submitTitle: "Rename",
            error: model.error,
            cancel: { },
            submit: { },
            content: {
                VStack(spacing: 0) {
                    ForEach(0 ..< model.rows, id: \.self) { index in
                        Text(verbatim: "Row \(index)")
                            .frame(height: 30)
                    }
                }
            }
        )
    }
}
