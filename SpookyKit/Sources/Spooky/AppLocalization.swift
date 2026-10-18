import Foundation
import SpookyKit

/// App 文案统一从资源包读取，语言由系统及应用的 AppleLanguages 偏好决定。
enum AppLocalization {
    /// 支持的语言；资源包的开发语言提供英文回退。
    static let languages = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]

    /// 应用的 SwiftPM 资源包。
    static let bundle = Bundle.module

    /// 读取并格式化当前语言的文案，不以键名作为回退文本。
    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        let localized = bundle.localizedString(forKey: key, value: nil, table: nil)
        let format: String

        // 英文兜底独立于当前系统语言，缺失的翻译不能直接暴露资源键。
        if localized == key,
           let url = bundle.url(forResource: "en", withExtension: "lproj"),
           let english = Bundle(url: url) {
            format = english.localizedString(forKey: key, value: "", table: nil)
        } else {
            format = localized
        }

        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}

/// 错误 sheet 的本地化说明与可复制原文。
struct AppFailure: Identifiable {
    /// 每次错误的独立标识。
    let id = UUID()

    /// 错误标题。
    let title: String

    /// 用户可采取的恢复步骤。
    let message: String

    /// Git 输出或进程错误原文。
    let details: String

    /// 打开失败时允许重新选择目录，刷新失败时允许重试读取。
    let isOpeningFailure: Bool

    /// 服务器失败的恢复入口仍打开服务器表单。
    let isRemoteFailure: Bool

    /// 根据错误类别选择译文，外部工具的原始输出保持原样。
    init(error: Error, opening: Bool) {
        isOpeningFailure = opening
        isRemoteFailure = error is RemoteConnectionError
        var key = "error.command"
        var output: GitCommandResult?
        var diagnostic: String?
        var exceededOutputLimit = false
        var recoveryKey: String?

        switch error {
        case let remote as RemoteConnectionError:
            key = "remoteError." + remote.kind.rawValue
            recoveryKey = key + ".help"
            output = remote.result
            diagnostic = remote.diagnostic

        case let terminal as TerminalLaunchError:
            key = "error.terminal"
            recoveryKey = "error.terminalHelp"
            diagnostic = terminal.diagnostic

        case let git as GitError:
            output = git.result
            diagnostic = git.diagnostic

            switch git.category {
            case .indexLocked: key = "error.indexLocked"
            case .launchFailed: key = "error.launch"
            case .notRepository: key = "error.notRepository"
            case .notWorkingTree: key = "error.notWorkingTree"
            case .pathUnavailable: key = "error.path"
            case .unsafeRepository: key = "error.ownership"
            case .cancelled: key = "error.cancelled"
            case .outputLimitExceeded:
                key = "error.outputLimit"
                exceededOutputLimit = true
            case .processIOFailed: key = "error.process"
            case .commandFailed: key = "error.command"
            }

        case let problem as RepositoryOpenError:
            switch problem {
            case .requiresLocalAbsolutePath:
                key = "error.path"

            case .invalidGitVersion(let result), .unsupportedGitVersion(let result):
                key = "error.version"
                output = result

            case .invalidWorktreeResponse(let result):
                key = "error.notWorkingTree"
                output = result
            }

        case let parse as StatusParseError:
            key = "error.parse"
            diagnostic = parse.record

        default:
            diagnostic = String(describing: error)
        }

        title = AppLocalization.text(key)
        let recovery = AppLocalization.text(recoveryKey ?? (opening ? "error.openHelp" : "error.refreshHelp"))
        message = exceededOutputLimit
            ? AppLocalization.text("error.outputLimitHelp") + "\n\n" + recovery
            : recovery

        // 同时保留 stderr 和 stdout；版本校验等失败的原因可能只出现在 stdout。
        let raw = [
            output.map { String(decoding: $0.standardError, as: UTF8.self) },
            output.map { String(decoding: $0.standardOutput, as: UTF8.self) },
            diagnostic,
            output?.exitCode.map { AppLocalization.text("error.exitCode", Int($0)) },
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        details = raw.isEmpty ? AppLocalization.text("error.noOutput") : raw
    }
}
