import AppKit

// MARK: - ExternalToolRequest

/// 交给外部工具的一次比较或合并，路径都在本机。
enum ExternalToolRequest: Equatable {
    /// 比较左右两个文件或两个目录。
    case diff(left: URL, right: URL)

    /// 三方合并：我方、对方、共同祖先，结果写进 merged；没有共同祖先时 base 是空文件。
    case merge(local: URL, remote: URL, base: URL, merged: URL, hasBase: Bool)
}

// MARK: - ExternalToolInvocation

/// 启动外部工具的命令行。
struct ExternalToolInvocation: Equatable {
    /// 可执行文件。
    let executable: URL

    /// 参数，逐个传递，不经 shell 解释。
    let arguments: [String]
}

// MARK: - ExternalTool

/// 可选的外部比较与合并工具：都在本机启动，命令行按各工具的约定由 Spooky 组装。
enum ExternalTool: String, CaseIterable, Identifiable {
    /// Visual Studio Code。
    case visualStudioCode = "vscode"

    /// Araxis Merge。
    case araxisMerge = "araxismerge"

    /// Beyond Compare。
    case beyondCompare = "beyondcompare"

    /// BBEdit。
    case bbEdit = "bbedit"

    /// Changes。
    case changes

    /// DeltaWalker。
    case deltaWalker = "deltawalker"

    /// DiffMerge。
    case diffMerge = "diffmerge"

    /// FileMerge，随 Xcode 安装，经 `opendiff` 启动。
    case fileMerge = "filemerge"

    /// Kaleidoscope。
    case kaleidoscope

    /// P4Merge。
    case p4Merge = "p4merge"

    /// TextMate。
    case textMate = "textmate"

    /// TextWrangler。
    case textWrangler = "textwrangler"

    /// DiffFork。
    case diffFork = "difffork"

    /// 偏好：比较工具的标识。
    static let diffToolKey = "diffToolIdentifier"

    /// 偏好：多个文件时比较两个目录，只对支持目录对比的工具有效。
    static let compareDirectoryKey = "diffToolCompareDirectory"

    /// 偏好：合并工具的标识。
    static let mergeToolKey = "mergeToolIdentifier"

    /// 偏好：合并工具写回结果时，把被覆盖的冲突文件留作 `<文件>.orig`。
    static let keepBackupsKey = "keepMergeBackups"

    /// 偏好里保存的标识。
    var id: String { rawValue }

    /// 产品名不翻译。
    var displayName: String {
        switch self {
        case .visualStudioCode: "Visual Studio Code"
        case .araxisMerge: "Araxis Merge"
        case .beyondCompare: "Beyond Compare"
        case .bbEdit: "BBEdit"
        case .changes: "Changes"
        case .deltaWalker: "DeltaWalker"
        case .diffMerge: "DiffMerge"
        case .fileMerge: "FileMerge"
        case .kaleidoscope: "Kaleidoscope"
        case .p4Merge: "P4Merge"
        case .textMate: "TextMate"
        case .textWrangler: "TextWrangler"
        case .diffFork: "DiffFork"
        }
    }

    /// 能作为合并工具。
    var supportsMerge: Bool {
        switch self {
        case .visualStudioCode, .araxisMerge, .beyondCompare, .deltaWalker,
             .diffMerge, .fileMerge, .kaleidoscope, .p4Merge:
            true

        case .bbEdit, .changes, .textMate, .textWrangler, .diffFork:
            false
        }
    }

    /// 能比较两个目录。
    var supportsDirectoryDiff: Bool {
        [.visualStudioCode, .kaleidoscope, .p4Merge].contains(self)
    }

    /// 命令行入口在合并窗口关闭之前就退出：`opendiff` 打开 FileMerge 的窗口后即退出，
    /// 退出时结果可能还没有保存，要等用户说明合并已完成。
    var exitsBeforeMergeFinishes: Bool {
        self == .fileMerge
    }

    /// 按系统注册信息找应用，不假定装在 /Applications；没有安装时为 nil。
    @MainActor
    var applicationURL: URL? {
        bundleIdentifiers.lazy
            .compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            .first
    }

    /// 已选为比较工具或合并工具的工具；没有选过或标识无效时为 nil。
    ///
    /// - Parameters:
    ///   - merge: 取合并工具；否则取比较工具。
    ///   - defaults: 读取偏好的域。
    static func selected(merge: Bool, in defaults: UserDefaults = .standard) -> Self? {
        let tool = defaults.string(forKey: merge ? mergeToolKey : diffToolKey).flatMap(Self.init(rawValue:))

        guard let tool, !merge || tool.supportsMerge else {
            return nil
        }

        return tool
    }

    /// 启动这次比较或合并的命令行；这个工具不能合并时为 nil。
    ///
    /// - Parameters:
    ///   - request: 比较或合并的文件。
    ///   - application: 工具的应用包位置，命令行入口在包内。
    func invocation(_ request: ExternalToolRequest, application: URL) -> ExternalToolInvocation? {
        #warning("TODO: 只在装有 FileMerge 的 Mac 上实际启动过；其余工具的命令行按各自的命令行约定组装，需在装有对应工具的 Mac 上逐个核对比较、合并与目录对比；只影响选了这些工具时的启动")

        switch request {
        case .diff(let left, let right):
            return diffInvocation(left.path, right.path, application: application)

        case .merge(let local, let remote, let base, let merged, let hasBase):
            guard supportsMerge else { return nil }

            return mergeInvocation(
                local: local.path,
                remote: remote.path,
                base: base.path,
                merged: merged.path,
                hasBase: hasBase,
                application: application
            )
        }
    }
}

// MARK: - Private

extension ExternalTool {
    /// 判断是否安装与定位应用用的 Bundle Identifier，按优先顺序。
    private var bundleIdentifiers: [String] {
        switch self {
        case .visualStudioCode: ["com.microsoft.VSCode"]
        case .araxisMerge: ["com.araxis.merge"]
        case .beyondCompare: ["com.ScooterSoftware.BeyondCompare"]
        case .bbEdit: ["com.barebones.bbedit"]
        case .changes: ["com.skorpiostech.Changes"]
        case .deltaWalker: ["com.deltopia.deltawalker"]
        case .diffMerge: ["com.sourcegear.DiffMerge"]
        case .fileMerge: ["com.apple.FileMerge"]
        case .kaleidoscope: ["app.kaleidoscope.v4", "com.blackpixel.kaleidoscope"]
        case .p4Merge: ["com.perforce.p4merge"]
        case .textMate: ["com.macromates.TextMate", "com.macromates.textmate"]
        case .textWrangler: ["com.barebones.textwrangler"]
        case .diffFork: ["com.dotfork.DiffFork"]
        }
    }

    /// 应用包内的命令行入口。
    ///
    /// - Parameter path: 相对应用包的路径。
    private static func executable(_ application: URL, _ path: String) -> URL {
        application.appending(path: path)
    }

    /// 比较两个文件或目录的命令行。
    private func diffInvocation(_ left: String, _ right: String, application: URL) -> ExternalToolInvocation {
        let (executable, arguments): (URL, [String]) =
            switch self {
            case .visualStudioCode:
                (Self.executable(application, "Contents/Resources/app/bin/code"), ["--wait", "--diff", left, right])

            case .araxisMerge:
                (Self.executable(application, "Contents/Utilities/compare"), ["-wait", left, right])

            case .beyondCompare:
                (Self.executable(application, "Contents/MacOS/bcomp"), [left, right])

            case .bbEdit:
                (Self.executable(application, "Contents/Helpers/bbdiff"), ["--wait", "--resume", left, right])

            case .changes:
                (Self.executable(application, "Contents/Resources/chdiff"), [left, right])

            case .deltaWalker:
                (Self.executable(application, "Contents/MacOS/DeltaWalker"), [left, right, "-nosplash", "-mi"])

            case .diffMerge:
                (Self.executable(application, "Contents/MacOS/DiffMerge"), ["-nosplash", left, right])

            case .fileMerge:
                (URL(fileURLWithPath: "/usr/bin/opendiff"), [left, right])

            case .kaleidoscope:
                (Self.executable(application, "Contents/MacOS/ksdiff"), ["--diff", left, right])

            case .p4Merge:
                (Self.executable(application, "Contents/MacOS/p4merge"), [left, right])

            case .textMate:
                // TextMate 没有比较模式：统一补丁经管道交给 mate 显示，路径作为位置参数传入，不拼进脚本
                (
                    URL(fileURLWithPath: "/bin/sh"),
                    [
                        "-c", "/usr/bin/diff -u \"$1\" \"$2\" | \"$3\" -a",
                        "sh", left, right,
                        Self.executable(application, "Contents/SharedSupport/Support/bin/mate").path,
                    ]
                )

            case .textWrangler:
                (Self.executable(application, "Contents/Helpers/twdiff"), ["--wait", "--resume", left, right])

            case .diffFork:
                (Self.executable(application, "Contents/SharedSupport/Support/bin/difffork"), [left, right, "-w"])
            }

        return ExternalToolInvocation(executable: executable, arguments: arguments)
    }

    /// 三方合并的命令行；不能合并的工具为 nil。
    private func mergeInvocation(
        local: String,
        remote: String,
        base: String,
        merged: String,
        hasBase: Bool,
        application: URL
    ) -> ExternalToolInvocation? {
        let invocation: (URL, [String])? =
            switch self {
            case .visualStudioCode:
                (
                    Self.executable(application, "Contents/Resources/app/bin/code"),
                    ["--wait", "--merge", local, remote, base, merged]
                )

            case .araxisMerge:
                (Self.executable(application, "Contents/Utilities/compare"), ["-wait", local, base, remote, merged])

            case .beyondCompare:
                (Self.executable(application, "Contents/MacOS/bcomp"), [local, remote, base, merged])

            case .deltaWalker:
                (
                    Self.executable(application, "Contents/MacOS/DeltaWalker"),
                    [local, remote, base, "-merged=" + merged, "-nosplash", "-mi"]
                )

            case .diffMerge:
                (
                    Self.executable(application, "Contents/MacOS/DiffMerge"),
                    ["-nosplash", "-merge", "-result=" + merged, local, base, remote]
                )

            case .fileMerge:
                // 没有共同祖先时不传 -ancestor，FileMerge 按两方比较
                (
                    URL(fileURLWithPath: "/usr/bin/opendiff"),
                    [local, remote] + (hasBase ? ["-ancestor", base] : []) + ["-merge", merged]
                )

            case .kaleidoscope:
                (
                    Self.executable(application, "Contents/MacOS/ksdiff"),
                    ["--merge", "--output", merged, "--base", base, "--", local, "--snapshot", remote, "--snapshot"]
                )

            case .p4Merge:
                (Self.executable(application, "Contents/MacOS/p4merge"), [base, local, remote, merged])

            case .bbEdit, .changes, .textMate, .textWrangler, .diffFork:
                nil
            }

        return invocation.map { ExternalToolInvocation(executable: $0.0, arguments: $0.1) }
    }
}
