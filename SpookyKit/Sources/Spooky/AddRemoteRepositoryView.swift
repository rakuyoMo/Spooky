import SpookyKit
import SwiftUI

/// 添加服务器仓库的体检表单；失败时保留输入和原始错误供修复。
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

    /// 标题、两列表单、错误区和底栏沿用统一 sheet 骨架。
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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
                }
            }

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
                    TextField("", text: $path)
                        .accessibilityLabel(AppLocalization.text("remote.path"))
                        .accessibilityIdentifier("remote-path")
                }
            }
            .disabled(task != nil)

            if let failure {
                FailureDetailsView(failure: failure)
            }

            Divider()

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
        .padding(20)
        .frame(width: 520)
        .onDisappear { task?.cancel() }
    }

    /// 体检通过才加入最近记录；取消和失败会关闭本次连接。
    private func submit() {
        failure = nil
        let location = RepositoryLocation.remote(host: host, path: path)
        let remote = GitRunner(location: location).remote!
        task = Task {
            await remote.setCallbackHandler { request in
                await RemoteCallbackPresenter.shared.respond(to: request)
            }

            do {
                let repository = try await remote.open()
                try Task.checkCancellation()
                task = nil
                opened(repository.location)
            } catch {
                await remote.close()
                guard !Task.isCancelled else { return }
                failure = AppFailure(error: error, opening: true, location: location)
                task = nil
            }
        }
    }
}
