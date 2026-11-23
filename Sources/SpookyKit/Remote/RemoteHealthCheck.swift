import Foundation

// MARK: - RemoteHealthCheck

/// 连接体检在 B 上一次执行完的各个步骤。
///
/// 脚本按顺序执行步骤，遇到第一个非零退出的检查就停下；读取环境失败不停，后面的检查仍给出具体错误。
/// 每步结束后，标准输出与标准错误里各写一个带随机标记的分隔帧，A 据此切回每步自己的输出与退出码，
/// 步骤的输出含任意字节都不会与分隔帧混淆。
struct RemoteHealthCheck {
    /// 体检的步骤，按执行顺序排列；工作区连接执行全部步骤，主机连接执行 ``RemoteHealthCheck/hostSteps``。
    enum Step: CaseIterable {
        /// 读取 B 的非交互环境。
        case environment

        /// 非交互环境能找到 Git，输出之后各步执行的 Git 的路径，见 ``RemoteHealthCheck/gitExecutable(in:)``。
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

        /// B 上已经装好这一版包装器时，用它新建会话，连接时不再部署。
        case session
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

    /// 主机连接的体检步骤：没有工作区，检查 Git 之后直接新建会话。
    static let hostSteps: [Step] = [.environment, .gitPath, .gitVersion, .session]

    /// 本次执行的步骤，按执行顺序排列。
    private let steps: [Step]

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
    ///   - steps: 本次执行的步骤。
    init(_ result: GitCommandResult, marker: String, steps: [Step]) {
        self.steps = steps

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

    /// 体检脚本：先从标准输入读出分隔标记与新建会话的报文，再依次执行 `steps`。
    ///
    /// 位置参数依次是仓库路径、包装器的文件名与字节数、会话看守的心跳容忍期与操作保留期。
    /// 报文带着中继的令牌，只放在不导出的变量里，经管道交给包装器。
    ///
    /// 转成常驻通道时，会话步骤成功之后在两路输出上各写一个 ``channelMarker(_:)``，再 exec 到包装器的 serve 模式，
    /// 标准输入换回读完两行之后另存的那一个；之后经标准输入写进来的是通道的请求帧。
    ///
    /// - Parameters:
    ///   - steps: 要执行的步骤。
    ///   - entersChannel: 会话步骤成功之后是否转成常驻通道。
    static func script(_ steps: [Step], entersChannel: Bool) -> String {
        let commands = steps.map { step in
            // 读取环境失败不停，后面的检查仍给出具体错误
            let frame = step == .environment ? "spooky_frame $? || :" : "spooky_frame $? || exit 0"
            return command(for: step) + "\n" + frame
        }

        // 各步骤的标准输入都是 /dev/null；转成通道时原来的标准输入另存在 3 号描述符，留给 serve
        let input = entersChannel ? "exec 3<&0 </dev/null" : "exec </dev/null"

        let channel = """

            printf '\\036%s\\037' "$spooky_marker"
            printf '\\036%s\\037' "$spooky_marker" >&2
            exec "$spooky_wrapper" serve "$spooky_session" <&3 3<&-
            """

        return """
            IFS= read -r spooky_marker || exit 1
            IFS= read -r spooky_request || exit 1
            \(input)

            spooky_frame() {
                printf '\\036%s:%s\\037' "$spooky_marker" "$1"
                printf '\\036%s:%s\\037' "$spooky_marker" "$1" >&2
                return "$1"
            }

            \(commands.joined(separator: "\n"))
            """ + (entersChannel ? channel : "")
    }

    /// 体检会话转成常驻通道时，两路输出在前导与通道之间的分隔标记；与步骤的分隔帧不同，标记之后没有冒号与退出码。
    ///
    /// - Parameter marker: 本次经标准输入交给脚本的分隔标记。
    static func channelMarker(_ marker: String) -> Data {
        Data([0x1E]) + Data(marker.utf8) + Data([0x1F])
    }

    /// 找到 Git 那一步输出的绝对路径；输出不是一行以 “/” 开头的路径时为 nil。
    ///
    /// - Parameter output: ``Step/gitPath`` 的标准输出。
    static func gitExecutable(in output: Data) -> String? {
        guard
            let text = String(data: output, encoding: .utf8),
            text.hasPrefix("/"),
            text.hasSuffix("\n")
        else { return nil }

        let path = text.dropLast()
        return path.contains("\n") ? nil : String(path)
    }

    /// 一步的结果，参数记为 `argument`。
    ///
    /// 脚本没写完这一步就结束时按通道的结束状态处理：SSH 的 255 按连接诊断识别，
    /// 正常退出说明输出不完整，其它退出码连同剩下的输出算作这一步的结果。
    func result(_ step: Step, argument: String) throws -> GitCommandResult {
        guard let index = steps.firstIndex(of: step), index < outputs.count else {
            let rest = Self.result(remainder, argument: argument, isCancelled: isCancelled)
            if rest.exitCode == 255 { throw RemoteConnectionError.ssh(rest) }
            guard rest.exitCode != 0 else { throw RemoteConnectionError(.protocolFailure, result: rest) }
            return rest
        }

        return Self.result(outputs[index], argument: argument, isCancelled: isCancelled)
    }

    /// 写完分隔帧的一步的结果；脚本没有执行完这一步时返回 nil。
    func completed(_ step: Step, argument: String) -> GitCommandResult? {
        guard let index = steps.firstIndex(of: step), index < outputs.count else { return nil }
        return Self.result(outputs[index], argument: argument, isCancelled: isCancelled)
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
            // macOS 的 /usr/bin/git 是转发壳，每次执行都先查一遍开发者工具的位置；
            // xcode-select 指向的开发者目录里有 Git 时直接用它，之后的步骤都执行 spooky_git
            """
            spooky_git=$(command -v git) && {
                if test "$spooky_git" = /usr/bin/git &&
                    spooky_tools=$(/usr/bin/xcode-select -p 2>/dev/null) &&
                    test -x "$spooky_tools/usr/bin/git"
                then
                    spooky_git=$spooky_tools/usr/bin/git
                fi

                printf '%s\\n' "$spooky_git"
            }
            """

        case .gitVersion:
            "\"$spooky_git\" --version"

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
            "\"$spooky_git\" -C \"$1\" rev-parse --is-inside-work-tree"

        case .status:
            "\"$spooky_git\" -C \"$1\" "
                + (GitRunner.globalOptions + ["status", "--porcelain=v2", "-z", "--branch", "--untracked-files=normal"])
                .map(GitRunner.shellQuoted)
                .joined(separator: " ")

        case .root:
            "\"$spooky_git\" -C \"$1\" rev-parse --show-toplevel"

        case .session:
            // 包装器与全部回调入口都可执行、字节数与本机一致时才用它；BSD 的 wc 在数字前补空格，不加引号让 shell 去掉
            // 包装器路径与会话目录留在脚本的变量里，转成常驻通道时 exec 用得到
            """
            spooky_wrapper="$HOME/.spooky/bin/$2"
            (for spooky_entry in '' \(RemoteConnection.callbackLinks.map { "-" + $0 }.joined(separator: " ")); do
                test -x "$spooky_wrapper$spooky_entry" || exit 1
            done
            test $(wc -c < "$spooky_wrapper") -eq "$3") &&
            spooky_session=$(printf '%s\\n' "$spooky_request" | "$spooky_wrapper" create-session "$4" "$5") &&
            printf '%s\\n%s\\n' "$spooky_wrapper" "$spooky_session"
            """
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
