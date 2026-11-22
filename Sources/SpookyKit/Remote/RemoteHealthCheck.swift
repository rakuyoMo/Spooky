import Foundation

// MARK: - RemoteHealthCheck

/// 连接体检在 B 上一次执行完的各个步骤。
///
/// 脚本按顺序执行步骤，遇到第一个非零退出的检查就停下；读取环境失败不停，后面的检查仍给出具体错误。
/// 每步结束后，标准输出与标准错误里各写一个带随机标记的分隔帧，A 据此切回每步自己的输出与退出码，
/// 步骤的输出含任意字节都不会与分隔帧混淆。
struct RemoteHealthCheck {
    /// 体检的步骤，按执行顺序排列；主机连接只检查到 `gitVersion`。
    enum Step: Int, CaseIterable {
        /// 读取 B 的非交互环境。
        case environment

        /// 非交互环境能找到 Git。
        case gitPath

        /// 读取 Git 版本。
        case gitVersion

        /// 路径存在且是目录。
        case directory

        /// 当前登录用户能读取、搜索目录。
        case permission

        /// 系统的隐私保护允许 SSH 会话列出目录内容。
        case listing

        /// Git 认出这是工作区。
        case workTree

        /// 读取工作区状态。
        case status

        /// Git 确认的工作区根。
        case root
    }

    /// 一步的输出与结束状态。
    private struct Output {
        /// 这一步的标准输出。
        let standardOutput: Data

        /// 这一步的标准错误。
        let standardError: Data

        /// 这一步的结束状态。
        let terminationStatus: GitTerminationStatus?
    }

    /// 一路输出里的一个分隔帧。
    private struct Frame {
        /// 上一帧之后、这一帧之前的输出。
        let output: Data

        /// 帧里记录的退出码。
        let code: Int32

        /// 帧末尾之后的位置。
        let end: Data.Index
    }

    /// 两路输出都写完分隔帧的步骤。
    private let outputs: [Output]

    /// 最后一个完整步骤之后剩下的输出，带着通道的结束状态。
    private let remainder: Output

    /// 通道是否因任务取消而结束。
    private let isCancelled: Bool

    /// 按本次的分隔标记切开体检通道的输出。
    ///
    /// - Parameters:
    ///   - result: 体检通道的结果。
    ///   - marker: 本次经标准输入交给脚本的分隔标记。
    init(_ result: GitCommandResult, marker: String) {
        let marker = Data(marker.utf8)
        let output = Self.frames(in: result.standardOutput, marker: marker)
        let error = Self.frames(in: result.standardError, marker: marker)
        let count = min(output.count, error.count)

        outputs = (0 ..< count).map { index in
            Output(
                standardOutput: output[index].output,
                standardError: error[index].output,
                terminationStatus: .exited(output[index].code)
            )
        }

        // 没写完的那一步拿到最后一个完整帧之后的全部输出
        let outputEnd = count > 0 ? output[count - 1].end : result.standardOutput.startIndex
        let errorEnd = count > 0 ? error[count - 1].end : result.standardError.startIndex

        remainder = Output(
            standardOutput: Data(result.standardOutput[outputEnd...]),
            standardError: Data(result.standardError[errorEnd...]),
            terminationStatus: result.terminationStatus
        )
        isCancelled = result.isCancelled
    }

    /// 体检脚本：先从标准输入读出分隔标记，执行到 `last` 为止；仓库路径是脚本的第一个位置参数。
    ///
    /// - Parameter last: 最后一个要执行的步骤。
    static func script(through last: Step) -> String {
        let steps = Step.allCases.prefix { $0.rawValue <= last.rawValue }.map { step in
            // 读取环境失败不停，后面的检查仍给出具体错误
            let frame = step == .environment ? "spooky_frame $? || :" : "spooky_frame $? || exit 0"
            return command(for: step) + "\n" + frame
        }

        return """
            IFS= read -r spooky_marker || exit 1
            exec </dev/null

            spooky_frame() {
                printf '\\036%s:%s\\037' "$spooky_marker" "$1"
                printf '\\036%s:%s\\037' "$spooky_marker" "$1" >&2
                return "$1"
            }

            \(steps.joined(separator: "\n"))
            """
    }

    /// 一步的结果，参数记为 `argument`。
    ///
    /// 脚本没写完这一步就结束时按通道的结束状态处理：SSH 的 255 按连接诊断识别，
    /// 正常退出说明输出不完整，其它退出码连同剩下的输出算作这一步的结果。
    func result(_ step: Step, argument: String) throws -> GitCommandResult {
        guard step.rawValue < outputs.count else {
            let rest = Self.result(remainder, argument: argument, isCancelled: isCancelled)
            if rest.exitCode == 255 { throw RemoteConnectionError.ssh(rest) }
            guard rest.exitCode != 0 else { throw RemoteConnectionError(.protocolFailure, result: rest) }
            return rest
        }

        return Self.result(outputs[step.rawValue], argument: argument, isCancelled: isCancelled)
    }

    /// 要求一步成功：255 按连接诊断识别，其它非零退出归入 `kind`。
    func require(_ step: Step, kind: RemoteConnectionError.Kind) throws -> GitCommandResult {
        let result = try result(step, argument: kind.rawValue)
        if result.exitCode == 255 { throw RemoteConnectionError.ssh(result) }
        guard result.exitCode == 0 else { throw RemoteConnectionError(kind, result: result) }
        return result
    }

    /// 与 ``require(_:kind:)`` 相同，但 stderr 含 “Operation not permitted” 时归为磁盘访问权限问题。
    func requireAccess(_ step: Step, kind: RemoteConnectionError.Kind) throws -> GitCommandResult {
        do {
            return try require(step, kind: kind)
        } catch let error as RemoteConnectionError where error.kind == kind {
            let message = error.result.map { String(decoding: $0.standardError, as: UTF8.self) } ?? ""

            guard message.contains("Operation not permitted") else { throw error }
            throw RemoteConnectionError(.diskAccess, result: error.result)
        }
    }
}

// MARK: - Private

extension RemoteHealthCheck {
    /// 一步在脚本里的命令；路径只作为位置参数进入命令。
    private static func command(for step: Step) -> String {
        switch step {
        case .environment:
            // 环境脚本最后 exec 到 Perl，放进子 shell 才不会结束整个体检
            "(\n" + RemoteHostEnvironment.script + "\n)"

        case .gitPath:
            "command -v git"

        case .gitVersion:
            "git --version"

        case .directory:
            "(if ! test -d \"$1\"; then printf '%s\\n' 'Directory does not exist' >&2; exit 2; fi)"

        case .permission:
            """
            (if ! test -r "$1" || ! test -x "$1"; then
                printf '%s\\n' 'Directory is not readable or searchable' >&2
                exit 3
            fi)
            """

        case .listing:
            // 权限位允许时，B 的隐私保护仍可能在读取目录内容时拒绝 SSH 会话
            "/usr/bin/perl -e "
                + GitRunner.shellQuoted("opendir(my $directory, $ARGV[0]) or do { print STDERR \"$!\\n\"; exit 3 }")
                + " -- \"$1\""

        case .workTree:
            "git -C \"$1\" rev-parse --is-inside-work-tree"

        case .status:
            "git -C \"$1\" "
                + (GitRunner.globalOptions + ["status", "--porcelain=v2", "-z", "--branch", "--untracked-files=all"])
                .map(GitRunner.shellQuoted)
                .joined(separator: " ")

        case .root:
            "git -C \"$1\" rev-parse --show-toplevel"
        }
    }

    /// 用一步的输出建立结果。
    private static func result(_ output: Output, argument: String, isCancelled: Bool) -> GitCommandResult {
        GitCommandResult(
            arguments: [argument],
            standardOutput: output.standardOutput,
            standardError: output.standardError,
            terminationStatus: output.terminationStatus,
            isCancelled: isCancelled
        )
    }

    /// 按分隔标记切开一路输出，返回其中完整的分隔帧；格式不对的帧及其后的输出不算。
    private static func frames(in data: Data, marker: Data) -> [Frame] {
        let opening = Data([0x1E]) + marker + Data(":".utf8)
        var frames: [Frame] = []
        var start = data.startIndex

        while
            let head = data.range(of: opening, in: start ..< data.endIndex),
            let tail = data[head.upperBound...].firstIndex(of: 0x1F),
            let code = Int32(String(decoding: data[head.upperBound ..< tail], as: UTF8.self))
        {
            let end = data.index(after: tail)

            frames.append(Frame(
                output: Data(data[start ..< head.lowerBound]),
                code: code,
                end: end
            ))
            start = end
        }

        return frames
    }
}
