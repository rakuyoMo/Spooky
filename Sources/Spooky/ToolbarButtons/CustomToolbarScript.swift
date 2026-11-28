import Foundation
import SpookyKit

// MARK: - CustomToolbarScriptError

/// 自定义按钮的脚本没能启动，或没有正常结束。
struct CustomToolbarScriptError: Error {
    /// 启动失败的系统说明，或脚本的输出与结束的状态。
    let diagnostic: String
}

// MARK: - CustomToolbarScript

/// 在本机运行自定义按钮的脚本。
///
/// 脚本先写进临时目录里的一个文件再执行：第一行以 `#!` 开头时由系统按这一行选解释器，否则交给 `/bin/zsh`。
/// 本机仓库在仓库根目录运行，服务器仓库在家目录运行；标准输入是空的，标准输出与标准错误合在一起，只在失败时显示。
enum CustomToolbarScript {
    /// 交给脚本、描述仓库的环境变量；没有值的不设。
    enum Variable: String, CaseIterable {
        /// 工作区根目录的路径：本机仓库是这台 Mac 上的，服务器仓库是服务器上的。
        case repositoryPath = "SPOOKY_REPOSITORY_PATH"

        /// 工作区根目录的名字。
        case repositoryName = "SPOOKY_REPOSITORY_NAME"

        /// 服务器仓库的主机别名，可以直接交给 ssh。
        case sshHost = "SPOOKY_SSH_HOST"

        /// 当前分支；HEAD 分离时不设。
        case branch = "SPOOKY_BRANCH"

        /// HEAD 指向的提交的完整哈希；还没有提交时不设。
        case head = "SPOOKY_HEAD"

        /// 当前分支的上游，如 `origin/main`。
        case upstream = "SPOOKY_UPSTREAM"

        /// 上游所在的远端；当前分支没有远端上游时取 `origin`。
        case remote = "SPOOKY_REMOTE"

        /// 这个远端的获取地址。
        case remoteURL = "SPOOKY_REMOTE_URL"
    }

    /// 失败时留下的输出上限：只留最后这么多字节。
    private static let outputLimit = 64 * 1024

    /// 描述仓库的变量：位置取自仓库，分支、HEAD 与上游取自最近一次读到的状态，远端与地址取自仓库的远端配置。
    ///
    /// - Parameters:
    ///   - location: 窗口里的仓库。
    ///   - branch: 最近一次读到的分支状态；还没有读到时为 nil。
    ///   - remotes: 仓库的远端配置；没有读到时为空。
    static func variables(
        location: RepositoryLocation,
        branch: BranchStatus?,
        remotes: [RemoteConfiguration]
    ) -> [Variable: String] {
        var values: [Variable: String] = [
            .repositoryPath: location.path,
            .repositoryName: URL(fileURLWithPath: location.path).lastPathComponent,
        ]

        values[.sshHost] = location.host
        values[.branch] = branch?.head
        values[.head] = branch?.oid
        values[.upstream] = branch?.upstream

        // 上游写成 “远端/分支”，远端名里也可能有 “/”，取对得上的最长的远端名；没有远端上游时按 Git 的默认取 origin
        let upstream = branch?.upstream ?? ""

        let remote = remotes
            .filter { upstream.hasPrefix($0.name + "/") }
            .max { $0.name.count < $1.name.count }
            ?? remotes.first { $0.name == "origin" }

        values[.remote] = remote?.name
        values[.remoteURL] = remote?.url

        return values
    }

    /// 脚本的环境：继承的环境，加上本机执行 Git 时设置的变量，再写入描述仓库的变量。
    ///
    /// - Parameters:
    ///   - inherited: Spooky 继承到的环境。
    ///   - local: 本机执行 Git 时设置的变量，见 `LocalExecutionSettings.variables`。
    ///   - variables: 描述仓库的变量。
    static func environment(
        inherited: [String: String],
        local: [String: String],
        variables: [Variable: String]
    ) -> [String: String] {
        var environment = inherited.merging(local) { $1 }

        // 继承来的同名变量可能描述的是别的仓库，这次没有值的一并去掉
        for variable in Variable.allCases {
            environment[variable.rawValue] = variables[variable]
        }

        return environment
    }

    /// 运行脚本并等它结束。
    ///
    /// - Parameters:
    ///   - script: 脚本的内容。
    ///   - variables: 描述仓库的变量。
    ///   - location: 窗口里的仓库，决定脚本的工作目录。
    /// - Throws: 脚本没能启动或没有以 0 退出时抛出 ``CustomToolbarScriptError``。
    static func run(
        _ script: String,
        variables: [Variable: String],
        location: RepositoryLocation
    ) async throws {
        let environment = environment(
            inherited: ProcessInfo.processInfo.environment,
            local: LocalExecutionSettings.current.variables,
            variables: variables
        )

        // 本机仓库在仓库根目录运行；服务器仓库的目录不在这台 Mac 上，在家目录运行
        let directory = location.localURL ?? FileManager.default.homeDirectoryForCurrentUser

        try await Task.detached {
            try execute(script, environment: environment, directory: directory)
        }.value
    }
}

// MARK: - Private

extension CustomToolbarScript {
    /// 把脚本写进只有自己能读的临时目录，执行并等它结束，最后删掉临时目录。
    ///
    /// - Parameters:
    ///   - script: 脚本的内容。
    ///   - environment: 脚本的环境。
    ///   - directory: 脚本的工作目录。
    private static func execute(_ script: String, environment: [String: String], directory: URL) throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Spooky-" + UUID().uuidString)

        defer {
            try? FileManager.default.removeItem(at: folder)
        }

        let file = folder.appending(path: "script")

        do {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )

            try Data(script.utf8).write(to: file)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        } catch {
            throw CustomToolbarScriptError(diagnostic: error.localizedDescription)
        }

        let process = Process()

        // 以 #! 开头的脚本直接执行，由系统按这一行选解释器
        if script.hasPrefix("#!") {
            process.executableURL = file
        } else {
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [file.path]
        }

        process.currentDirectoryURL = directory
        process.environment = environment
        process.standardInput = FileHandle.nullDevice

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        do {
            try process.run()
        } catch {
            // 解释器不存在时系统报的是脚本文件找不到，写出 #! 这一行才看得出是哪个解释器
            let shebang = script.hasPrefix("#!") ? String(script.prefix { !$0.isNewline }) + "\n" : ""

            throw CustomToolbarScriptError(diagnostic: shebang + error.localizedDescription)
        }

        // 先读到管道关闭再等进程结束：输出写满管道时脚本会停下等读
        var text = String(decoding: tail(of: output.fileHandleForReading), as: UTF8.self)
        process.waitUntilExit()

        guard process.terminationReason != .exit || process.terminationStatus != 0 else {
            return
        }

        let status = process.terminationReason == .uncaughtSignal
            ? AppLocalization.text("toolbarButtons.error.signal", process.terminationStatus)
            : AppLocalization.text("toolbarButtons.error.status", process.terminationStatus)

        // 结束的状态与输出之间空一行
        while let last = text.last, last.isNewline {
            text.removeLast()
        }

        throw CustomToolbarScriptError(diagnostic: text.isEmpty ? status : text + "\n\n" + status)
    }

    /// 读到管道关闭，只留最后 ``outputLimit`` 字节。
    ///
    /// - Parameter handle: 管道的读取端。
    private static func tail(of handle: FileHandle) -> Data {
        var data = Data()

        while let chunk = try? handle.read(upToCount: outputLimit), !chunk.isEmpty {
            data.append(chunk)

            if data.count > outputLimit {
                data.removeFirst(data.count - outputLimit)
            }
        }

        return data
    }
}
