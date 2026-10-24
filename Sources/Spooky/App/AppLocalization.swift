import Foundation
import SpookyKit

// MARK: - AppLocalization

/// App 文案统一从资源包读取，语言由系统及应用的 AppleLanguages 偏好决定。
enum AppLocalization {
    /// 支持的语言；资源包的开发语言提供英文回退。
    static let languages = ["en", "zh-Hans", "zh-Hant", "ja", "ko", "de", "fr", "es"]

    /// 应用的 SwiftPM 资源包。
    static let bundle = Bundle.module

    /// 读取并格式化当前语言的文案，不以键名作为回退文本。
    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        let localized = bundle.localizedString(forKey: key, value: nil, table: nil)
        let format: String =

            // 英文兜底独立于当前系统语言，缺失的翻译不能直接暴露资源键。
            if
            localized == key,
                let url = bundle.url(forResource: "en", withExtension: "lproj"),
                let english = Bundle(url: url)
            {
                english.localizedString(forKey: key, value: "", table: nil)
            } else {
                localized
            }

        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}

// MARK: - FailureKind

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

// MARK: - AppFailure

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
            (key, kind) = Self.classification(of: sync)

        case let working as WorkingCopyError:
            (key, kind) = Self.classification(of: working)

        case let stash as StashError:
            (key, kind, recoveryKey, output, diagnostic) = Self.classification(of: stash)

        case let rewrite as RewriteError:
            (key, kind, recoveryKey, output) = Self.classification(of: rewrite)

        case let file as RepositoryFileError:
            (key, kind) = Self.classification(of: file)
            exceededOutputLimit = file == .tooLarge

        // 冲突向导的写入前提不满足属于仓库状态问题
        case is ConflictResolutionError:
            key = "conflict.error.version"
            kind = .repository

        case is FileViewError:
            key = "showFile.error.missing"
            kind = .repository

        case let remote as RemoteConnectionError:
            (key, kind, recoveryKey, output, diagnostic) = Self.classification(of: remote, writing: writing)

        case let terminal as TerminalLaunchError:
            key = "error.terminal"
            recoveryKey = "error.terminalHelp"
            diagnostic = terminal.diagnostic

        case let file as WorkingCopyFileError:
            kind = .repository
            (key, recoveryKey, diagnostic) = Self.classification(of: file)

        case let tool as DiffToolLaunchError:
            key = "files.error.diffTool"
            recoveryKey = "files.error.diffToolHelp"
            diagnostic = tool.diagnostic

        case let git as GitError:
            output = git.result
            diagnostic = git.diagnostic
            (key, kind) = Self.classification(of: git.category)
            exceededOutputLimit = git.category == .outputLimitExceeded

        case let problem as RepositoryOpenError:
            (key, kind, output) = Self.classification(of: problem)

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

    /// 服务器连接错误的文案键、类别、恢复说明与原文；写入中途断线的结果未知，统一提示先核对仓库，不能引导用户直接重试。
    private static func classification(
        of remote: RemoteConnectionError,
        writing: Bool
    ) -> (key: String, kind: FailureKind, recoveryKey: String, output: GitCommandResult?, diagnostic: String?) {
        let interrupted = writing && [.unavailable, .protocolFailure].contains(remote.kind)
        let remoteKind = interrupted ? .interruptedWrite : remote.kind
        let key = "remoteError." + remoteKind.rawValue

        return (key, kind(of: remoteKind), key + ".help", remote.result, remote.diagnostic)
    }

    /// 发起同步前仓库条件不满足时的文案键与类别，这类失败都属于仓库状态问题。
    private static func classification(of sync: RepositorySyncError) -> (key: String, kind: FailureKind) {
        switch sync {
        case .dirtyWorkingCopy: ("sync.error.dirty", .repository)
        case .requiresBranch: ("sync.error.branch", .repository)
        case .missingRemote: ("sync.error.remote", .repository)
        }
    }

    /// 补丁操作失败的文案键与类别：补丁格式错误属于输出问题，其余属于仓库状态问题。
    private static func classification(of working: WorkingCopyError) -> (key: String, kind: FailureKind) {
        switch working {
        case .staleSnapshot: ("working.error.stale", .repository)
        case .invalidSelection: ("working.error.selection", .repository)
        case .unsupportedFile: ("working.error.file", .repository)
        case .whitespaceMismatch: ("diff.error.whitespace", .repository)
        case .malformedDiff: ("error.parse", .output)
        }
    }

    /// 工作区文件操作失败的文案键、恢复说明与诊断：补丁前像不符时列出这些文件。
    private static func classification(
        of file: WorkingCopyFileError
    ) -> (key: String, recovery: String?, diagnostic: String?) {
        switch file {
        case .patchPreimageMismatch(let paths):
            ("files.error.preimage", "files.error.preimageHelp", paths.joined(separator: "\n"))

        case .destinationExists:
            ("files.error.destination", nil, nil)
        }
    }

    /// 文件访问失败的文案键与类别：路径不受支持属于仓库问题，超过读取上限属于输出问题。
    private static func classification(of file: RepositoryFileError) -> (key: String, kind: FailureKind) {
        switch file {
        case .unsupportedPath: ("working.error.path", .repository)
        case .tooLarge: ("error.outputLimit", .output)
        }
    }

    /// 服务器体检与连接错误按阶段归类：版本、仓库位置与输出格式各自独立，其余属于连接。
    private static func kind(of remote: RemoteConnectionError.Kind) -> FailureKind {
        switch remote {
        case .gitVersion:
            .version

        case .invalidHost, .absolutePathRequired, .pathUnavailable, .pathPermission, .notWorkingTree:
            .repository

        case .statusFormat:
            .output

        case .gitUnavailable:
            .environment

        case .unknownHostKey, .changedHostKey, .authentication, .unavailable, .deployment,
             .protocolFailure, .cancellationUnconfirmed, .interruptedWrite:
            .connection
        }
    }

    /// Git 失败按分类取文案键与类别：启动与管道问题属于环境，位置与所有权问题属于仓库，
    /// 取消与输出超限各自成类，其余属于 Git 失败。
    private static func classification(of category: GitError.Category) -> (key: String, kind: FailureKind) {
        switch category {
        case .pushRejected: ("sync.error.rejected", .git)
        case .authenticationFailed: ("sync.error.authentication", .git)
        case .remoteNotFound: ("sync.error.remote", .git)
        case .connectionTimedOut: ("sync.error.timeout", .git)
        case .connectionUnavailable: ("sync.error.connection", .git)
        case .noUpstream: ("sync.error.upstream", .git)
        case .branchNotMerged: ("branch.error.unmerged", .git)
        case .localChanges: ("sync.error.dirty", .git)
        case .signingFailed: ("signing.error", .git)
        case .indexLocked: ("error.indexLocked", .git)
        case .commandFailed: ("error.command", .git)
        case .launchFailed: ("error.launch", .environment)
        case .processIOFailed: ("error.process", .environment)
        case .notRepository: ("error.notRepository", .repository)
        case .notWorkingTree: ("error.notWorkingTree", .repository)
        case .pathUnavailable: ("error.path", .repository)
        case .unsafeRepository: ("error.ownership", .repository)
        case .cancelled: ("error.cancelled", .cancelled)
        case .outputLimitExceeded: ("error.outputLimit", .output)
        }
    }

    /// 打开工作区前置校验失败的文案键与类别，版本与工作区根目录的校验失败同时带回 Git 的原始结果。
    private static func classification(
        of problem: RepositoryOpenError
    ) -> (key: String, kind: FailureKind, output: GitCommandResult?) {
        switch problem {
        case .requiresLocalAbsolutePath:
            ("error.path", .repository, nil)

        case .invalidGitVersion(let result), .unsupportedGitVersion(let result):
            ("error.version", .version, result)

        case .invalidWorktreeResponse(let result):
            ("error.notWorkingTree", .repository, result)
        }
    }
}
