import AppKit
import SpookyKit

// MARK: - TerminalApplication

/// General 设置中受支持的终端，名称与 Bundle Identifier 按需求固定。
enum TerminalApplication: String, CaseIterable, Identifiable {
    /// macOS 自带终端。
    case terminal = "com.apple.Terminal"

    /// iTerm 2 / 3。
    case iTerm = "com.googlecode.iterm2"

    /// Warp 稳定版。
    case warp = "dev.warp.Warp-Stable"

    /// Ghostty。
    case ghostty = "com.mitchellh.ghostty"

    /// WezTerm。
    case wezTerm = "com.github.wez.wezterm"

    /// Otty。
    case otty = "io.appmakes.otty"

    /// SwiftUI 列表使用 Bundle Identifier 作为稳定身份。
    var id: String { rawValue }

    /// 第三方产品名不翻译。
    var displayName: String {
        switch self {
        case .terminal: "Terminal"
        case .iTerm: "iTerm"
        case .warp: "Warp"
        case .ghostty: "Ghostty"
        case .wezTerm: "WezTerm"
        case .otty: "Otty"
        }
    }

    /// 按系统注册信息找安装位置，不假定应用一定在 /Applications。
    @MainActor
    var applicationURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue)
    }
}

// MARK: - TerminalLaunchError

/// 外部终端启动失败的本地化边界。
struct TerminalLaunchError: Error {
    /// 原始系统诊断。
    let diagnostic: String
}

// MARK: - TerminalLauncher

/// 把统一的仓库终端命令交给用户选择的程序。
@MainActor
enum TerminalLauncher {
    /// Warp 启动配置只保留到本次 App 会话结束。
    private static var temporaryFiles: [URL] = []

    /// 本机进入目录，服务器在所选终端运行系统 SSH。
    static func open(_ location: RepositoryLocation) async throws {
        let selected = UserDefaults.standard.string(forKey: "terminalApplication")
            .flatMap(TerminalApplication.init(rawValue:)) ?? .terminal
        guard let application = selected.applicationURL else {
            throw TerminalLaunchError(diagnostic: AppLocalization.text("terminal.notInstalled", selected.displayName))
        }

        let command = location.terminalCommand

        switch selected {
        case .terminal:
            try await launch(
                URL(fileURLWithPath: "/usr/bin/osascript"),
                arguments: ["-e", terminalScript(command)]
            )

        case .iTerm:
            try await launch(
                URL(fileURLWithPath: "/usr/bin/osascript"),
                arguments: ["-e", iTermScript(command)]
            )

        case .otty:
            if let directory = location.localURL {
                _ = try await NSWorkspace.shared.open([directory], withApplicationAt: application, configuration: .init())
            } else {
                // Otty 1.5.4 的命令入口已由其 CLI 帮助与脚本字典确认。
                _ = try await NSWorkspace.shared.openApplication(at: application, configuration: .init())
                try await launch(
                    application.appending(path: "Contents/MacOS/otty-cli"),
                    arguments: ["open", "--command", command]
                )
            }

        case .wezTerm:
            let arguments = location.localURL.map { ["start", "--cwd", $0.path] }
                ?? ["start", "--", "/bin/sh", "-c", command]
            try await launch(application.appending(path: "Contents/MacOS/wezterm"), arguments: arguments)

        case .ghostty:
            if let directory = location.localURL {
                _ = try await NSWorkspace.shared.open([directory], withApplicationAt: application, configuration: .init())
            } else {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.createsNewApplicationInstance = true
                configuration.arguments = ["-e", "/bin/sh", "-c", command]
                _ = try await NSWorkspace.shared.openApplication(at: application, configuration: configuration)
            }

        case .warp:
            if let directory = location.localURL {
                _ = try await NSWorkspace.shared.open([directory], withApplicationAt: application, configuration: .init())
            } else {
                try await openWarp(command: command, application: application)
            }
        }
    }

    /// 退出时只移除 Spooky 创建的临时启动文件。
    static func cleanup() {
        for file in temporaryFiles { try? FileManager.default.removeItem(at: file) }
        temporaryFiles.removeAll()
    }

    /// 让 Terminal 执行命令的 AppleScript：已经开着至少两个窗口时，在最前面窗口的当前标签页里执行，否则新开窗口。
    ///
    /// - Parameter command: 要执行的 shell 命令。
    static func terminalScript(_ command: String) -> String {
        """
        tell application id "com.apple.Terminal"
            if (count of windows) > 1 and (exists front window) then
                do script \(appleString(command)) in front window
            else
                do script \(appleString(command))
            end if

            activate
        end tell
        """
    }

    /// 让 iTerm 执行命令的 AppleScript：已在运行且有窗口时，在第一个窗口里新建标签页；已在运行而没有窗口时新开窗口；
    /// 没有运行时启动它，在它打开的窗口里执行，它没有打开窗口时新开一个。
    ///
    /// 新的标签页或窗口要等一会儿才能接受输入，写入命令前先等 1 秒。
    ///
    /// - Parameter command: 要执行的 shell 命令。
    static func iTermScript(_ command: String) -> String {
        """
        set wasRunning to application id "com.googlecode.iterm2" is running

        tell application id "com.googlecode.iterm2"
            activate

            if (count of windows) is 0 then
                create window with default profile
            else
                select first window

                if wasRunning then
                    tell first window to create tab with default profile
                end if
            end if

            delay 1
            tell current session of first window to write text \(appleString(command))
        end tell
        """
    }

    /// AppleScript 字符串与 shell 参数分别转义，路径不能成为脚本源码。
    static func appleString(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r") + "\""
    }

    /// Warp 官方 Launch Configuration 协议允许在选定终端执行命令。
    private static func openWarp(command: String, application: URL) async throws {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".warp/launch_configurations")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "Spooky-" + UUID().uuidString
        let file = directory.appending(path: name + ".yaml")

        // JSON 是 YAML 的子集，交给编码器处理命令中的引号、换行与反斜杠。
        let configuration: [String: Any] = [
            "name": name,
            "windows": [["tabs": [["layout": ["cwd": "/", "commands": [["exec": command]]]]]]],
        ]
        try JSONSerialization.data(withJSONObject: configuration).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        temporaryFiles.append(file)
        let link = "warp://launch/" + name

        guard let url = URL(string: link) else {
            throw TerminalLaunchError(diagnostic: link)
        }

        _ = try await NSWorkspace.shared.open([url], withApplicationAt: application, configuration: .init())
    }

    /// 外部终端辅助进程在后台等待，不能阻塞窗口刷新。
    private static func launch(_ executable: URL, arguments: [String]) async throws {
        try await Task.detached {
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            process.standardInput = FileHandle.nullDevice
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw TerminalLaunchError(diagnostic: String(decoding: data, as: UTF8.self))
            }
        }.value
    }
}
