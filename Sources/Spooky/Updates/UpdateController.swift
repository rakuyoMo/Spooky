import AppKit
import Sparkle

// MARK: - UpdateChannel

/// 更新通道：稳定、测试与开发，对应更新清单里条目的 `sparkle:channel`。
///
/// 稳定版的条目不带通道，所有用户都能收到；测试通道另外接收 `beta` 条目，开发通道再接收 `development` 条目。
enum UpdateChannel: String, CaseIterable, Identifiable {
    /// 只接收稳定版。
    case stable

    /// 接收稳定版与测试版。
    case beta

    /// 接收稳定版、测试版与开发版。
    case development

    /// 偏好键，保存 `rawValue`。
    static let key = "updateChannel"

    /// SwiftUI 列表以 `rawValue` 作为稳定身份。
    var id: String { rawValue }

    /// Updates 页中显示的名称。
    var title: String {
        switch self {
        case .stable: AppLocalization.text("updates.channel.stable")
        case .beta: AppLocalization.text("updates.channel.beta")
        case .development: AppLocalization.text("updates.channel.development")
        }
    }

    /// 除不带通道的稳定版条目外，这个通道还接收的 `sparkle:channel`。
    var allowedChannels: Set<String> {
        switch self {
        case .stable: []
        case .beta: ["beta"]
        case .development: ["beta", "development"]
        }
    }

    /// 当前保存的通道；没有记录或记录无法识别时为稳定通道。
    static func current(in defaults: UserDefaults = .standard) -> Self {
        defaults.string(forKey: key).flatMap(Self.init) ?? .stable
    }
}

// MARK: - UpdateController

/// App 的更新器：按所选通道检查更新清单，下载后校验 EdDSA 签名再安装。
///
/// 主菜单的 “Check for Updates…” 与 Settings → Updates 共用这一个更新器；
/// 检查、下载与安装的窗口由 Sparkle 的标准界面负责，失败时不替换当前安装。
@MainActor
final class UpdateController: NSObject {
    /// App 唯一的更新器。
    static let shared = UpdateController()

    /// Sparkle 的更新器：设置页读写它的自动检查、自动下载、检查间隔与最近一次检查的时间。
    private(set) lazy var updater = SPUUpdater(
        hostBundle: .main,
        applicationBundle: .main,
        userDriver: UpdateUserDriver(hostBundle: .main, delegate: nil),
        delegate: self
    )

    /// 只经 `shared` 创建。
    override private init() {
        super.init()
    }

    /// 启动更新器，开始按计划检查；启动失败时弹窗说明原因。
    ///
    /// 只在 App Bundle 中启动：`swift run` 的可执行文件不在 Bundle 里，Sparkle 无法安装更新，
    /// 此时 “Check for Updates…” 保持禁用。
    func start() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }

        do {
            try updater.start()
        } catch {
            NSApp.presentError(error)
        }
    }

    /// App 菜单的 “Check for Updates…”：立即检查，结果与进度由 Sparkle 的窗口显示。
    @objc
    func checkForUpdates(_: Any?) {
        updater.checkForUpdates()
    }
}

// MARK: NSMenuItemValidation

extension UpdateController: NSMenuItemValidation {
    /// 更新器未启动，或检查、下载正在进行时禁用 “Check for Updates…”。
    func validateMenuItem(_: NSMenuItem) -> Bool {
        updater.canCheckForUpdates
    }
}

// MARK: SPUUpdaterDelegate

extension UpdateController: SPUUpdaterDelegate {
    /// 按 Updates 页所选的通道决定还接收哪些带通道的条目。
    nonisolated func allowedChannels(for _: SPUUpdater) -> Set<String> {
        UpdateChannel.current().allowedChannels
    }
}

// MARK: - UpdateUserDriver

/// Sparkle 的标准更新界面，出错时另外显示原始错误。
///
/// 标准界面只显示 “获取更新信息时出错” 这类概括的说明，网络错误等原始原因放在 `NSUnderlyingErrorKey` 里不显示；
/// 这里把原始原因放进恢复建议，标准界面把它显示为提示框的说明文字。
final class UpdateUserDriver: SPUStandardUserDriver {
    /// 把错误的直接原因写进恢复建议；已有恢复建议或没有直接原因时原样返回。
    nonisolated static func revealingUnderlyingError(_ error: any Error) -> any Error {
        let error = error as NSError

        guard
            error.localizedRecoverySuggestion == nil,
            let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
        else {
            return error
        }

        var userInfo = error.userInfo
        userInfo[NSLocalizedRecoverySuggestionErrorKey] = underlying.localizedDescription

        return NSError(domain: error.domain, code: error.code, userInfo: userInfo)
    }

    /// 显示更新失败的提示框，说明文字是原始错误。
    override func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        super.showUpdaterError(Self.revealingUnderlyingError(error), acknowledgement: acknowledgement)
    }
}
