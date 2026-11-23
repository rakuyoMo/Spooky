import Foundation

// MARK: - RemoteHealthCheck

/// 连接体检在 B 上一次执行完的各个步骤。
///
/// 脚本先由 B 生成本次的随机标记，在标准输出与标准错误上各写一个宣告；之后按顺序执行步骤，
/// 遇到第一个非零退出的检查就停下，读取环境与新建会话失败不停。
/// 每步结束后两路输出各写一个带标记的分隔帧，A 据此切回每步自己的输出与退出码，
/// 步骤的输出含任意字节都不会与分隔帧混淆，见 ``Splitter``。
struct RemoteHealthCheck {
    /// 体检的步骤；工作区连接执行 ``RemoteHealthCheck/repositorySteps``，主机连接执行 ``RemoteHealthCheck/hostSteps``，
    /// 逐条执行时最后再加上 ``token``。
    enum Step {
        /// B 上已经装好这一版包装器时，用它新建会话，连接时不再部署；排在最前，A 读到它就开始准备会话。
        case session

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

        /// 不转成常驻通道时开始会话：会话已经新建且其余步骤全部成功时，令牌经脚本原来的标准输入交给包装器，
        /// 包装器写入令牌之后分出会话看守。
        case token
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

    /// 工作区连接的体检步骤，按执行顺序排列。
    static let repositorySteps: [Step] = [
        .session, .environment, .gitPath, .gitVersion,
        .directory, .permission, .listing, .workTree, .status, .root,
    ]

    /// 主机连接的体检步骤：没有工作区，新建会话之后只检查环境与 Git。
    static let hostSteps: [Step] = [.session, .environment, .gitPath, .gitVersion]

    /// 本次执行的步骤，按执行顺序排列。
    private let steps: [Step]

    /// 两路输出都写完分隔帧的步骤。
    private let outputs: [Output]

    /// 最后一个完整步骤之后剩下的输出，带着通道的结束状态。
    private let remainder: Output

    /// 通道是否因任务取消而结束。
    private let isCancelled: Bool

    /// 两路的宣告不一致，或宣告、分隔帧的格式不对；此时不认任何一步的结果。
    private let isMalformed: Bool

    /// 按两路各自宣告的标记切开体检的输出。
    ///
    /// - Parameters:
    ///   - result: 体检的结果。
    ///   - steps: 本次执行的步骤。
    init(_ result: GitCommandResult, steps: [Step]) {
        self.steps = steps

        var output = Splitter()
        var error = Splitter()
        let outputFrames = output.receive(result.standardOutput).frames
        let errorFrames = error.receive(result.standardError).frames

        let malformed = output.isMalformed || error.isMalformed || output.marker != error.marker
        let count = malformed ? 0 : min(outputFrames.count, errorFrames.count)

        outputs = (0 ..< count).map { index in
            Output(
                standardOutput: outputFrames[index].output,
                standardError: errorFrames[index].output,
                terminationStatus: .exited(outputFrames[index].code)
            )
        }

        // 没写完的那一步拿到最后一个完整帧之后的全部输出；一帧都没有时从宣告之后算起，格式不对时从头算起
        func start(_ frames: [Splitter.Frame], _ splitter: Splitter) -> Int {
            if count > 0 { return frames[count - 1].end }
            return malformed ? 0 : splitter.announcementEnd
        }

        remainder = Output(
            standardOutput: Data(result.standardOutput.dropFirst(start(outputFrames, output))),
            standardError: Data(result.standardError.dropFirst(start(errorFrames, error))),
            terminationStatus: result.terminationStatus
        )
        isCancelled = result.isCancelled
        isMalformed = malformed
    }

    /// 体检脚本：B 先生成本次的分隔标记并在两路输出上各写一个宣告，再依次执行 `steps`。
    ///
    /// 位置参数依次是仓库路径、包装器的文件名与字节数、会话看守的心跳容忍期与操作保留期。
    /// 标记取 B 的内核随机数，只放在不导出的变量里，不进参数与环境变量。
    /// 各步骤的标准输入都是 /dev/null，原来的标准输入另存在 3 号描述符：
    /// 转成常驻通道时留给 serve，逐条执行时留给 ``Step/token`` 读令牌。
    /// 启动外部程序的命令各自带上 `3<&-`，Git 与它启动的钩子、守护进程都拿不到这条请求流；
    /// 整段放进带 `3<&-` 的花括号不行：bash 为了事后恢复把 3 号描述符另存一份，子进程照样拿得到。
    ///
    /// 转成常驻通道时，会话已经新建且全部步骤成功之后，两路输出上各写一个转入通道的标记 `\036<标记>:channel\037`，
    /// 再 exec 到包装器的 serve 模式；之后经标准输入写进来的是通道的请求帧。
    ///
    /// - Parameters:
    ///   - steps: 要执行的步骤。
    ///   - entersChannel: 全部步骤成功之后是否转成常驻通道。
    static func script(_ steps: [Step], entersChannel: Bool) -> String {
        let commands = steps.map { step in
            // 读取环境与新建会话失败都不停：前者让后面的检查给出具体错误，后者在体检之后部署包装器
            let continues = step == .environment || step == .session
            return command(for: step) + "\n" + (continues ? "spooky_frame $? || :" : "spooky_frame $? || exit 0")
        }

        let channel = """


            test -n "$spooky_session" || exit 0
            printf '\\036%s:channel\\037' "$spooky_marker"
            printf '\\036%s:channel\\037' "$spooky_marker" >&2
            exec "$spooky_wrapper" serve "$spooky_session" <&3 3<&-
            """

        // 标记是 16 字节随机数的小写十六进制，读不到随机数时长度不对，脚本不写宣告就结束；
        // 工具用绝对路径，非交互环境的 PATH 不对时后面的步骤仍能给出具体错误
        return """
            exec 3<&0 </dev/null
            spooky_marker=$(/usr/bin/od -A n -t x1 -N 16 /dev/urandom 3<&- | /usr/bin/tr -d ' \\n' 3<&-)
            test ${#spooky_marker} -eq 32 || exit 1
            spooky_session=

            printf '\\036%s\\037' "$spooky_marker"
            printf '\\036%s\\037' "$spooky_marker" >&2

            spooky_frame() {
                printf '\\036%s:%s\\037' "$spooky_marker" "$1"
                printf '\\036%s:%s\\037' "$spooky_marker" "$1" >&2
                return "$1"
            }

            \(commands.joined(separator: "\n"))
            """ + (entersChannel ? channel : "")
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
    /// 正常退出或输出的格式不对说明输出不完整，其它退出码连同剩下的输出算作这一步的结果。
    func result(_ step: Step, argument: String) throws -> GitCommandResult {
        guard let index = steps.firstIndex(of: step), index < outputs.count else {
            let rest = Self.result(remainder, argument: argument, isCancelled: isCancelled)
            if rest.exitCode == 255 { throw RemoteConnectionError.ssh(rest) }

            guard rest.exitCode != 0, !isMalformed else {
                throw RemoteConnectionError(.protocolFailure, result: rest)
            }

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
            "(\n" + RemoteHostEnvironment.script + "\n) 3<&-"

        case .gitPath:
            // macOS 的 /usr/bin/git 是转发壳，每次执行都先查一遍开发者工具的位置；
            // xcode-select 指向的开发者目录里有 Git 时直接用它，之后的步骤都执行 spooky_git
            """
            spooky_git=$(command -v git) && {
                if test "$spooky_git" = /usr/bin/git &&
                    spooky_tools=$(/usr/bin/xcode-select -p 2>/dev/null 3<&-) &&
                    test -x "$spooky_tools/usr/bin/git"
                then
                    spooky_git=$spooky_tools/usr/bin/git
                fi

                printf '%s\\n' "$spooky_git"
            }
            """

        case .gitVersion:
            "\"$spooky_git\" --version 3<&-"

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
                + " -- \"$1\" 3<&-"

        case .workTree:
            "\"$spooky_git\" -C \"$1\" rev-parse --is-inside-work-tree 3<&-"

        case .status:
            "\"$spooky_git\" -C \"$1\" "
                + (GitRunner.globalOptions + ["status", "--porcelain=v2", "-z", "--branch", "--untracked-files=normal"])
                .map(GitRunner.shellQuoted)
                .joined(separator: " ")
                + " 3<&-"

        case .root:
            "\"$spooky_git\" -C \"$1\" rev-parse --show-toplevel 3<&-"

        case .session:
            // 包装器与全部回调入口都可执行、字节数与本机一致时才用它；BSD 的 wc 在数字前补空格，不加引号让 shell 去掉
            // 包装器路径与会话目录留在脚本的变量里，写入令牌与转成常驻通道时用得到
            """
            spooky_wrapper="$HOME/.spooky/bin/$2"
            (for spooky_entry in '' \(RemoteConnection.callbackLinks.map { "-" + $0 }.joined(separator: " ")); do
                test -x "$spooky_wrapper$spooky_entry" || exit 1
            done
            test $(wc -c < "$spooky_wrapper") -eq "$3") 3<&- &&
            spooky_session=$("$spooky_wrapper" create-session 3<&-) &&
            printf '%s\\n%s\\n' "$spooky_wrapper" "$spooky_session"
            """

        case .token:
            // 会话没有新建时不写令牌，脚本就此结束
            """
            test -n "$spooky_session" || exit 0
            "$spooky_wrapper" start-session "$spooky_session" "$4" "$5" <&3 3<&-
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
}
