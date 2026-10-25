import AppKit
import SpookyKit
import SwiftUI

// MARK: - ServerEnvironmentCheck

/// Environment 页底部的服务器检查：选一台主机，读出 B 上非交互 shell 的 PATH、找到的 Git 与 GIT_ 变量名。
///
/// 只读：服务器仓库在 B 上执行 Git，用的是 B 自己的环境，修复要在 B 的 shell 启动文件里进行。
struct ServerEnvironmentCheck: View {
    /// 要检查的主机别名。
    @State
    private var host = ""

    /// 读到的环境；还没检查或换了主机时为 nil。
    @State
    private var environment: RemoteHostEnvironment?

    /// 检查失败的说明与原文。
    @State
    private var failure: AppFailure?

    /// 正在检查。
    @State
    private var isChecking = false

    /// 主机一行与检查结果。
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.text("settings.environment.server"))

            HStack(spacing: 8) {
                TextField(AppLocalization.text("remote.host"), text: $host)
                    .frame(width: 220)
                    .onChange(of: host) {
                        environment = nil
                        failure = nil
                    }

                Menu(AppLocalization.text("settings.environment.server.hosts")) {
                    ForEach(knownHosts, id: \.self) { alias in
                        Button(alias) { host = alias }
                    }
                }
                .fixedSize()
                .disabled(knownHosts.isEmpty)

                Button(AppLocalization.text("settings.environment.server.check"), action: check)
                    .disabled(host.isEmpty || isChecking)

                if isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let environment {
                result(environment)
            }

            if let failure {
                FailureDetailsView(failure: failure)
            }
        }
    }
}

// MARK: - Private

extension ServerEnvironmentCheck {
    /// 书签里服务器仓库的主机。
    private var knownHosts: [String] {
        guard let coordinator = NSApp.delegate as? SpookyApplicationController else {
            return []
        }

        return ServerCloneDirectories.hosts(in: coordinator.bookmarks)
    }

    /// 检查结果：Git 的位置与版本、PATH 的每一段，以及会改变 Git 行为的变量名。
    private func result(_ environment: RemoteHostEnvironment) -> some View {
        let git = environment.gitPath.map { $0 + (environment.gitVersion.map { "  (" + $0 + ")" } ?? "") }
            ?? AppLocalization.text("settings.environment.server.noGit")

        return Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 4) {
            GridRow {
                Text(verbatim: "Git").foregroundStyle(.secondary)
                Text(git).textSelection(.enabled)
            }

            GridRow {
                Text(verbatim: "PATH").foregroundStyle(.secondary)
                Text(environment.searchPath.joined(separator: "\n")).textSelection(.enabled)
            }

            if !environment.gitVariables.isEmpty {
                GridRow {
                    Text(verbatim: "GIT_*").foregroundStyle(.secondary)
                    Text(environment.gitVariables.joined(separator: ", ")).textSelection(.enabled)
                }
            }
        }
        .font(.system(size: 11, design: .monospaced))
    }

    /// 连接这台主机并读出它的环境；凭据与口令经界面询问。
    private func check() {
        let alias = host
        isChecking = true
        failure = nil

        Task {
            do {
                environment = try await RemoteConnection.presentingHost(alias).connectHost()
            } catch {
                environment = nil
                failure = AppFailure(error: error, opening: true, location: .remote(host: alias, path: "/"))
            }

            isChecking = false
        }
    }
}
