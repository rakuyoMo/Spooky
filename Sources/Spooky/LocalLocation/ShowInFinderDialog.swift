import AppKit
import SpookyKit
import SwiftUI

// MARK: - ShowInFinderDialog

/// Show in Finder 的 sheet：连接、查找与挂载期间底栏左侧写进度，取消照常可用；没连上时错误区写出原因与原始输出，底栏只剩 Close；
/// 需要设置时换成本机位置表单。拿到本机位置后关闭，在 Finder 中选中目标。
struct ShowInFinderDialog: View {
    /// Show in Finder 的流程。
    let flow: ShowInFinderFlow

    /// 关闭 sheet。
    let close: () -> Void

    /// 按流程现在的一步显示；sheet 出现时开始流程。
    var body: some View {
        content
            .onAppear {
                flow.start { urls in
                    close()
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }
            }
    }

    /// 进行中与没连上时是对话框骨架，换成表单后是本机位置对话框。
    @ViewBuilder
    private var content: some View {
        switch flow.step {
        case .form(let form):
            LocalLocationDialog(form: form, close: finishForm)

        case .failed(let failure):
            DialogLayout(
                title: AppLocalization.text("action.revealFinder"),
                message: "",
                repository: flow.mounts.repository,
                submitTitle: AppLocalization.text("action.close"),
                error: AddRemoteRepositoryView.notice(for: failure),
                cancel: nil,
                submit: close
            )

        case .connecting, .searching, .mounting:
            #warning("TODO: 核实 Show in Finder 的 sheet 进行中与没连上时的说明与底栏；目前没有说明，进行中底栏只有 Cancel")
            DialogLayout(
                title: AppLocalization.text("action.revealFinder"),
                message: "",
                repository: flow.mounts.repository,
                submitTitle: AppLocalization.text("action.cancel"),
                progress: flow.progress,
                cancel: nil,
                submit: cancel
            )
        }
    }
}

// MARK: - Private

extension ShowInFinderDialog {
    /// 取消：关闭 sheet，进行中的连接、查找与挂载照常结束。
    private func cancel() {
        flow.cancel()
        close()
    }

    /// 本机位置表单关闭：设置成功时拿到本机位置后在 Finder 中选中目标。
    private func finishForm(saved: Bool) {
        close()

        guard saved else {
            return
        }

        Task {
            if let urls = await flow.savedLocation() {
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            }
        }
    }
}
