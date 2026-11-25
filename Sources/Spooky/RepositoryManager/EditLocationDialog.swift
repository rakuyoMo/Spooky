import SpookyKit
import SwiftUI

// MARK: - EditLocationDialog

/// 编辑书签的位置：本机仓库选文件夹；服务器仓库填主机别名与路径，可以只改其中一项。
///
/// 提交后验证新位置，通过了对话框才关闭；没通过时保留输入，错误区写出原因。
struct EditLocationDialog: View {
    /// 书签现在的位置。
    let location: RepositoryLocation

    /// 关闭对话框。
    let close: () -> Void

    /// 验证新位置并让书签改指过去；返回没能改的说明，改好时为 nil。
    let relocate: (RepositoryLocation) async -> String?

    /// SSH 主机别名；本机仓库没有。
    @State
    private var host: String

    /// 工作区的绝对路径。
    @State
    private var path: String

    /// 正在执行的验证，取消对话框时一并取消。
    @State
    private var task: Task<Void, Never>?

    /// 没能改的说明。
    @State
    private var error: String?

    /// 正在浏览服务器上的目录。
    @State
    private var isBrowsing = false

    /// 对话框骨架；验证中表单与主按钮不可用，取消照常可用，服务器仓库在底栏左侧写出进度。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("bookmarks.location.edit"),
            message: AppLocalization.text(isRemote ? "remote.form.help" : "bookmarks.location.message"),
            submitTitle: AppLocalization.text("action.ok"),
            error: error,
            progress: isRemote && task != nil ? AppLocalization.text("remote.checking") : nil,
            canSubmit: canSubmit,
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
    }

    /// 预填书签现在的位置。
    ///
    /// - Parameters:
    ///   - location: 书签现在的位置。
    ///   - close: 关闭对话框。
    ///   - relocate: 验证新位置并让书签改指过去。
    init(
        location: RepositoryLocation,
        close: @escaping () -> Void,
        relocate: @escaping (RepositoryLocation) async -> String?
    ) {
        self.location = location
        self.close = close
        self.relocate = relocate
        _host = State(initialValue: location.host ?? "")
        _path = State(initialValue: location.path)
    }
}

// MARK: - Private

extension EditLocationDialog {
    /// 书签指向的是不是服务器仓库。
    private var isRemote: Bool { location.host != nil }

    /// 表单里填的位置。
    private var edited: RepositoryLocation {
        isRemote ? .remote(host: host, path: path) : .local(path: path)
    }

    /// 位置改过、主机别名不空、路径是绝对路径，且没有在验证时才能提交。
    private var canSubmit: Bool {
        edited != location
            && (!isRemote || !host.isEmpty)
            && path.hasPrefix("/")
            && task == nil
    }

    /// 本机仓库是文件夹一行；服务器仓库是主机别名与路径两行，路径可以浏览服务器上的目录。
    private var form: some View {
        DialogForm {
            if isRemote {
                DialogFormRow(label: AppLocalization.text("remote.host")) {
                    TextField("", text: $host)
                        .accessibilityIdentifier("bookmark-location-host")
                }

                DialogFormRow(label: AppLocalization.text("remote.path")) {
                    HStack(spacing: 8) {
                        TextField("", text: $path)
                            .accessibilityIdentifier("bookmark-location-path")

                        Button(AppLocalization.text("clone.browse")) { isBrowsing = true }
                            .disabled(host.isEmpty)
                    }
                }
            } else {
                LocalLocationDialog.folderRow("bookmarks.create.location", folder: URL(fileURLWithPath: path)) {
                    LocalLocationDialog.chooseDirectory(from: URL(fileURLWithPath: path), canCreate: false) {
                        path = $0.path
                    }
                }
            }
        }
        .disabled(task != nil)
    }

    /// 取消验证并关闭对话框。
    private func cancel() {
        task?.cancel()
        close()
    }

    /// 验证填的位置：通过后关闭对话框，没通过时在错误区写出原因。
    private func submit() {
        error = nil
        let edited = edited

        task = Task {
            let problem = await relocate(edited)

            // 取消时对话框已经关闭
            guard !Task.isCancelled else {
                return
            }

            task = nil

            if let problem {
                error = problem
            } else {
                close()
            }
        }
    }
}
