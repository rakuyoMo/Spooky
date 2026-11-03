import SpookyKit
import SwiftUI

// MARK: - AddRemoteRepositoryView

/// 添加服务器仓库的体检表单；失败时保留输入，错误区写出修复方向与原始输出。
///
/// 路径可以手填，也可以浏览 B 上的目录；路径不存在或还不是 Git 工作区时换成备选底栏，可以在那里新建仓库再打开。
struct AddRemoteRepositoryView: View {
    /// 验证成功后由窗口协调器保存记录并打开仓库。
    let opened: (RepositoryLocation) -> Void

    /// 关闭表单而不添加记录。
    let cancelled: () -> Void

    /// SSH 主机别名不拆解成用户、地址和端口。
    @State
    private var host = ""

    /// B 上工作区的绝对路径。
    @State
    private var path = ""

    /// 正在执行的体检任务，取消表单时一并取消。
    @State
    private var task: Task<Void, Never>?

    /// 体检失败的本地化说明和原始诊断。
    @State
    private var failure: AppFailure?

    /// 体检失败的原因：路径不存在或不是工作区时可以在那里新建仓库。
    @State
    private var failedKind: RemoteConnectionError.Kind?

    /// 正在浏览服务器上的目录。
    @State
    private var isBrowsing = false

    /// 第一次连接时要提醒的 GIT_ 变量；为 nil 时没有提醒。
    @State
    private var environmentWarning: EnvironmentWarning?

    /// 体检通过、等环境变量提醒关掉后再打开的仓库。
    @State
    private var checkedRepository: RepositoryLocation?

    /// 对话框骨架：主机别名与路径两行；体检中底栏左侧写出进度，主按钮与表单不可用，取消照常可用。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("remote.form.title"),
            message: AppLocalization.text("remote.form.help"),
            submitTitle: AppLocalization.text("action.open"),
            alternate: createAlternate,
            error: Self.notice(for: failure),
            progress: task == nil ? nil : AppLocalization.text("remote.checking"),
            canSubmit: !host.isEmpty && path.hasPrefix("/") && task == nil,
            cancel: cancel,
            submit: submit
        ) {
            form
        }
        .onDisappear { task?.cancel() }
        .sheet(isPresented: $isBrowsing) {
            ServerDirectoryBrowser(host: host, path: path) { chosen in
                isBrowsing = false

                if let chosen {
                    path = chosen
                }
            }
        }
        .sheet(item: $environmentWarning, onDismiss: openCheckedRepository) { warning in
            ServerEnvironmentNotice(host: warning.host, variables: warning.variables) {
                environmentWarning = nil
            }
        }
    }

    /// 主机别名与路径两行；路径可以浏览 B 上的目录。体检进行中禁用。
    private var form: some View {
        DialogForm {
            DialogFormRow(label: AppLocalization.text("remote.host")) {
                TextField("", text: $host)
                    .accessibilityIdentifier("remote-host")
            }

            DialogFormRow(label: AppLocalization.text("remote.path")) {
                HStack(spacing: 8) {
                    TextField("", text: $path)
                        .accessibilityIdentifier("remote-path")

                    Button(AppLocalization.text("clone.browse")) { isBrowsing = true }
                        .disabled(host.isEmpty)
                }
            }
        }
        .disabled(task != nil)
    }

    /// 路径不存在或还不是工作区时的备选按钮：在那里新建仓库；其余时候为 nil。
    private var createAlternate: (title: String, action: () -> Void)? {
        guard Self.canCreateRepository(after: failedKind) else {
            return nil
        }

        return (title: AppLocalization.text("bookmarks.noRepository.create"), action: createRepository)
    }

    /// 错误区的文字：体检失败的修复方向，空一行后是原始输出；没有失败时为 nil。
    static func notice(for failure: AppFailure?) -> String? {
        failure.map { $0.message + "\n\n" + $0.details }
    }

    /// 体检失败后能否在那个路径新建仓库：路径不存在或还不是 Git 工作区时可以。
    static func canCreateRepository(after kind: RemoteConnectionError.Kind?) -> Bool {
        kind == .pathUnavailable || kind == .notWorkingTree
    }

    /// 取消体检并关闭表单。
    private func cancel() {
        task?.cancel()
        cancelled()
    }

    /// 体检通过才加入最近记录；取消和失败会关闭本次连接。
    private func submit() {
        failure = nil
        failedKind = nil
        let location = RepositoryLocation.remote(host: host, path: path)

        // 服务器位置创建的执行器总带有 SSH 连接。
        guard let remote = GitRunner(location: location).remote else { return }

        task = Task {
            await remote.setCallbackHandler { request in
                await RemoteCallbackPresenter.shared.respond(to: request)
            }

            do {
                let repository = try await remote.open()
                let variables = await remote.environment?.gitVariables ?? []
                try Task.checkCancellation()
                task = nil

                // 第一次连接时先提醒 B 的非交互环境里会改变 Git 行为的变量，关掉提醒后再打开
                guard variables.isEmpty else {
                    checkedRepository = repository.location
                    environmentWarning = EnvironmentWarning(host: host, variables: variables)
                    return
                }

                opened(repository.location)
            } catch {
                await remote.close()
                guard !Task.isCancelled else { return }
                failure = AppFailure(error: error, opening: true, location: location)
                failedKind = (error as? RemoteConnectionError)?.kind
                task = nil
            }
        }
    }

    /// 环境变量提醒关掉后打开体检通过的仓库。
    private func openCheckedRepository() {
        guard let checkedRepository else {
            return
        }

        self.checkedRepository = nil
        opened(checkedRepository)
    }

    /// 在 B 上的这个路径执行 `git init`，目录不存在时一并建出，成功后照常体检并打开。
    private func createRepository() {
        let location = RepositoryLocation.remote(host: host, path: path)
        failure = nil
        failedKind = nil

        task = Task {
            _ = await RemoteConnection.presentingHost(host)

            do {
                try await RepositoryCreation.initialize(location)
                try Task.checkCancellation()
                task = nil
                submit()
            } catch {
                guard !Task.isCancelled else { return }
                failure = AppFailure(error: error, opening: false, location: location, writing: true)
                task = nil
            }
        }
    }
}

// MARK: - EnvironmentWarning

/// 环境变量提醒的内容：B 的非交互环境里设置的 GIT_ 变量。
private struct EnvironmentWarning: Identifiable {
    /// 每次提醒的独立标识。
    let id = UUID()

    /// 主机别名。
    let host: String

    /// 设置了的 GIT_ 变量名。
    let variables: [String]
}

// MARK: - ServerEnvironmentNotice

/// 服务器的非交互环境设置了 GIT_ 变量时的提醒：它们会改变 Spooky 在服务器上执行的每条 Git 命令查找仓库与读取配置的方式。
///
/// 提示版的对话框骨架，底栏只有 Close，↩ 与 ⎋ 都关掉它。
struct ServerEnvironmentNotice: View {
    /// 主机别名。
    let host: String

    /// 设置了的 GIT_ 变量名。
    let variables: [String]

    /// 关掉提醒。
    let close: () -> Void

    /// 标题与说明，说明写出主机与变量名。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("remote.environment.title"),
            message: AppLocalization.text(
                "remote.environment.message",
                host,
                variables.formatted(.list(type: .and))
            ),
            submitTitle: AppLocalization.text("action.close"),
            cancel: nil,
            submit: close
        )
    }
}
