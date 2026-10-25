import AppKit
import SpookyKit
import SwiftUI

/// 添加服务器仓库的体检表单；失败时保留输入和原始错误供修复。
///
/// 路径可以手填，也可以浏览 B 上的目录；路径不存在或还不是 Git 工作区时，可以在那里新建仓库再打开。
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

    /// 标题、两列表单、错误区和底栏沿用统一 sheet 骨架。
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            form

            if let failure {
                FailureDetailsView(failure: failure)
            }

            // 路径不存在或还不是工作区时，可以在那里新建仓库
            if failedKind == .pathUnavailable || failedKind == .notWorkingTree {
                Button(AppLocalization.text("bookmarks.noRepository.create"), action: createRepository)
                    .disabled(task != nil)
                    .accessibilityIdentifier("remote-create")
            }

            Divider()

            footer
        }
        .padding(20)
        .frame(width: 520)
        .onDisappear { task?.cancel() }
        .sheet(isPresented: $isBrowsing) {
            ServerDirectoryBrowser(host: host, path: path) { chosen in
                isBrowsing = false

                if let chosen {
                    path = chosen
                }
            }
        }
    }

    /// 主机别名与路径两行；路径可以浏览 B 上的目录。体检进行中禁用。
    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 12) {
            GridRow {
                Text(AppLocalization.text("remote.host"))
                    .gridColumnAlignment(.trailing)
                TextField("", text: $host)
                    .accessibilityLabel(AppLocalization.text("remote.host"))
                    .accessibilityIdentifier("remote-host")
            }

            GridRow {
                Text(AppLocalization.text("remote.path"))

                HStack(spacing: 8) {
                    TextField("", text: $path)
                        .accessibilityLabel(AppLocalization.text("remote.path"))
                        .accessibilityIdentifier("remote-path")

                    Button(AppLocalization.text("clone.browse")) { isBrowsing = true }
                        .disabled(host.isEmpty)
                }
            }
        }
        .disabled(task != nil)
    }

    /// 服务器图标、表单标题与填写说明。
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text("action.addRemote"))
                    .font(.system(size: 14, weight: .bold))

                Text(AppLocalization.text("remote.form.help"))
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 底栏：体检进度、取消与打开按钮。
    private var footer: some View {
        HStack(spacing: 8) {
            if task != nil {
                ProgressView(AppLocalization.text("remote.checking"))
                    .controlSize(.small)
            }

            Spacer()

            Button(AppLocalization.text("action.cancel")) {
                task?.cancel()
                cancelled()
            }
            .keyboardShortcut(.cancelAction)

            Button(AppLocalization.text("action.open"), action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(host.isEmpty || !path.hasPrefix("/") || task != nil)
                .accessibilityIdentifier("remote-open")
        }
    }

    /// 提示 B 的非交互环境设置了 GIT_ 变量：它们会改变 Spooky 在 B 上执行的每条 Git 命令查找仓库与读取配置的方式。
    private static func warnAbout(_ variables: [String], on host: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppLocalization.text("remote.environment.title")
        alert.informativeText = AppLocalization.text(
            "remote.environment.message",
            host,
            variables.formatted(.list(type: .and))
        )
        alert.runModal()
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

                // 第一次连接时提示 B 的非交互环境里会改变 Git 行为的变量
                if !variables.isEmpty {
                    Self.warnAbout(variables, on: host)
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
