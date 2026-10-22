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

/// 错误界面统一展示的类别：连接断开、Git 退出失败、输出解析失败、用户取消和版本不支持彼此区分。
enum FailureKind: String, CaseIterable {
    /// SSH 主连接不可用或中断，以及连接体检中的指纹、认证和部署失败。
    case connection

    /// Git 以调用方未接受的状态退出。
    case git

    /// Git 输出不符合约定格式，或超过读取上限。
    case output

    /// 用户主动取消。
    case cancelled

    /// 本机或服务器的 Git 低于最低版本。
    case version

    /// 仓库位置、工作区状态或所选内容不满足操作条件。
    case repository

    /// 进程启动、管道、文件访问或外部程序失败。
    case environment
}

/// 错误 sheet 与内嵌错误共用的本地化说明、类别、仓库位置和可复制原文。
struct AppFailure: Identifiable {
    /// 每次错误的独立标识。
    let id = UUID()

    /// 用户可理解的错误类别。
    let kind: FailureKind

    /// 错误标题。
    let title: String

    /// 用户可采取的恢复步骤。
    let message: String

    /// Git 输出或进程错误原文。
    let details: String

    /// 出错的仓库位置；服务器位置带主机前缀，打开前的校验失败也记录所选位置。
    let location: RepositoryLocation?

    /// 打开失败时允许重新选择目录，刷新失败时允许重试读取。
    let isOpeningFailure: Bool

    /// 服务器失败的恢复入口仍打开服务器表单。
    let isRemoteFailure: Bool

    /// 类别与仓库位置两行说明，错误 sheet 和内嵌错误使用同一格式。
    var context: String {
        [
            AppLocalization.text("failure.category", AppLocalization.text("failure.kind." + kind.rawValue)),
            location.map { AppLocalization.text("failure.location", $0.displayPath) },
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    /// 根据错误类别选择译文，外部工具的原始输出保持原样。
    ///
    /// - Parameters:
    ///   - error: 核心库或界面层抛出的错误。
    ///   - opening: 是否发生在打开仓库的校验阶段。
    ///   - location: 出错的仓库位置。
    ///   - writing: 是否为写操作；写操作失败使用写入的恢复说明，写入期间断线时提示先核对仓库，而不是直接重试。
    init(error: Error, opening: Bool, location: RepositoryLocation?, writing: Bool = false) {
        isOpeningFailure = opening
        isRemoteFailure = error is RemoteConnectionError
        self.location = location
        var key = "error.command"
        var kind = FailureKind.environment
        var output: GitCommandResult?
        var diagnostic: String?
        var exceededOutputLimit = false
        var recoveryKey: String?

        switch error {
        case is RepositoryReadError:
            key = "error.parse"
            kind = .output

        case let sync as RepositorySyncError:
            kind = .repository

            switch sync {
            case .dirtyWorkingCopy: key = "sync.error.dirty"
            case .requiresBranch: key = "sync.error.branch"
            case .missingRemote: key = "sync.error.remote"
            }

        case let working as WorkingCopyError:
            kind = .repository

            switch working {
            case .staleSnapshot: key = "working.error.stale"
            case .invalidSelection: key = "working.error.selection"
            case .unsupportedFile: key = "working.error.file"
            case .malformedDiff:
                key = "error.parse"
                kind = .output
            }

        case let file as RepositoryFileError:
            switch file {
            case .unsupportedPath:
                key = "working.error.path"
                kind = .repository

            case .tooLarge:
                key = "error.outputLimit"
                kind = .output
                exceededOutputLimit = true
            }

        case let remote as RemoteConnectionError:
            // 写入中途断线的结果未知，统一提示先核对仓库，不能引导用户直接重试。
            let interrupted = writing && [.unavailable, .protocolFailure].contains(remote.kind)
            let remoteKind = interrupted ? .interruptedWrite : remote.kind
            key = "remoteError." + remoteKind.rawValue
            recoveryKey = key + ".help"
            kind = Self.kind(of: remoteKind)
            output = remote.result
            diagnostic = remote.diagnostic

        case let terminal as TerminalLaunchError:
            key = "error.terminal"
            recoveryKey = "error.terminalHelp"
            diagnostic = terminal.diagnostic

        case let git as GitError:
            output = git.result
            diagnostic = git.diagnostic
            kind = .git

            switch git.category {
            case .pushRejected: key = "sync.error.rejected"
            case .authenticationFailed: key = "sync.error.authentication"
            case .remoteNotFound: key = "sync.error.remote"
            case .connectionTimedOut: key = "sync.error.timeout"
            case .connectionUnavailable: key = "sync.error.connection"
            case .noUpstream: key = "sync.error.upstream"
            case .branchNotMerged: key = "branch.error.unmerged"
            case .localChanges: key = "sync.error.dirty"
            case .indexLocked: key = "error.indexLocked"
            case .commandFailed: key = "error.command"
            case .launchFailed:
                key = "error.launch"
                kind = .environment
            case .processIOFailed:
                key = "error.process"
                kind = .environment
            case .notRepository:
                key = "error.notRepository"
                kind = .repository
            case .notWorkingTree:
                key = "error.notWorkingTree"
                kind = .repository
            case .pathUnavailable:
                key = "error.path"
                kind = .repository
            case .unsafeRepository:
                key = "error.ownership"
                kind = .repository
            case .cancelled:
                key = "error.cancelled"
                kind = .cancelled
            case .outputLimitExceeded:
                key = "error.outputLimit"
                kind = .output
                exceededOutputLimit = true
            }

        case let problem as RepositoryOpenError:
            switch problem {
            case .requiresLocalAbsolutePath:
                key = "error.path"
                kind = .repository

            case .invalidGitVersion(let result), .unsupportedGitVersion(let result):
                key = "error.version"
                kind = .version
                output = result

            case .invalidWorktreeResponse(let result):
                key = "error.notWorkingTree"
                kind = .repository
                output = result
            }

        case let parse as StatusParseError:
            key = "error.parse"
            kind = .output
            diagnostic = parse.record

        case is CancellationError:
            key = "error.cancelled"
            kind = .cancelled

        default:
            diagnostic = String(describing: error)
        }

        self.kind = kind
        title = AppLocalization.text(key)

        // 写操作失败后仓库状态可能已部分变化，恢复说明引导用户看原文后刷新核对。
        let fallbackKey = opening ? "error.openHelp" : (writing ? "error.writeHelp" : "error.refreshHelp")
        let recovery = AppLocalization.text(recoveryKey ?? fallbackKey)
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

    /// 服务器体检与连接错误按阶段归类：版本、仓库位置与输出格式各自独立，其余属于连接。
    private static func kind(of remote: RemoteConnectionError.Kind) -> FailureKind {
        switch remote {
        case .gitVersion:
            return .version

        case .invalidHost, .absolutePathRequired, .pathUnavailable, .pathPermission, .notWorkingTree:
            return .repository

        case .statusFormat:
            return .output

        case .gitUnavailable:
            return .environment

        case .unknownHostKey, .changedHostKey, .authentication, .unavailable, .deployment,
            .protocolFailure, .cancellationUnconfirmed, .interruptedWrite:
            return .connection
        }
    }
}
