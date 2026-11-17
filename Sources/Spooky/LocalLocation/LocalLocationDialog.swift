import AppKit
import SpookyKit
import SwiftUI

// MARK: - LocalLocationDialog

/// 本机位置对话框：表单选方式与方式带的文件夹，底栏是取消与 Mount 或 Save。
///
/// 对话框打开时检测可用的挂载方式；挂载与核对期间底栏左侧写进度，表单与主按钮不可用，取消照常可用；失败时不关，错误区写出原因。
struct LocalLocationDialog: View {
    /// 对话框的表单。
    let form: LocalLocationForm

    /// 关闭对话框；记下了本机位置时为 true，取消时为 false。
    let close: (_ saved: Bool) -> Void

    /// 方式一行，选 sshfs 挂载或指定文件夹时多出文件夹一行，出现与收起随对话框高度一起动画。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("localLocation.title"),
            message: message,
            submitTitle: form.submitTitle,
            error: form.error,
            progress: form.progress,
            canSubmit: form.canSubmit,
            cancel: cancel,
            submit: submit
        ) {
            DialogForm {
                DialogFormRow(label: AppLocalization.text("localLocation.method")) {
                    methodPicker
                }

                switch form.method {
                case .sshfsMount:
                    folderRow("localLocation.mountAt", folder: form.mountFolder, choose: chooseMountFolder)

                case .chosenFolder:
                    folderRow("localLocation.folder", folder: form.chosenFolder, choose: chooseFolder)

                case .automatic, .smbMount:
                    EmptyView()
                }
            }
            .disabled(form.progress != nil)
        }
        .task {
            await form.detect()
        }
    }

    /// 说明；从 Show in Finder 换过来时前面先写不能直接打开的原因。
    private var message: String {
        let message = AppLocalization.text("localLocation.message", form.mounts.repository?.displayPath ?? "")

        return form.reason.map { $0 + "\n" + message } ?? message
    }

    /// 方式弹出菜单；检测中的 “正在检测” 一项不可选。
    private var methodPicker: some View {
        Picker(
            "",
            selection: Binding(
                get: { LocalLocationForm.Item.method(form.method) },
                set: select
            )
        ) {
            ForEach(form.items, id: \.self) { item in
                switch item {
                case .method(let method):
                    Text(method.title)
                        .tag(item)

                case .checking:
                    Text(AppLocalization.text("localLocation.checking"))
                        .tag(item)
                        .disabled(true)
                }
            }
        }
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel(AppLocalization.text("localLocation.method"))
    }
}

// MARK: - Private

extension LocalLocationDialog {
    /// 文件夹一行：选定的文件夹（主目录缩写成 `~`，没有时是灰掉的 “None Selected”）与 Choose…。
    private func folderRow(_ label: String, folder: URL?, choose: @escaping () -> Void) -> some View {
        DialogFormRow(label: AppLocalization.text(label)) {
            HStack(spacing: 8) {
                Text(folder.map { HomePath.abbreviated($0.path) } ?? AppLocalization.text("submodule.path.none"))
                    .foregroundStyle(folder == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(AppLocalization.text("localLocation.choose"), action: choose)
            }
        }
    }

    /// 换方式时文件夹一行随对话框高度一起动画。
    private func select(_ item: LocalLocationForm.Item) {
        guard case .method(let method) = item else {
            return
        }

        DialogAnimation.perform {
            form.method = method
        }
    }

    /// 选 sshfs 挂载到的文件夹；可以在面板里新建空文件夹。
    private func chooseMountFolder() {
        chooseDirectory(from: form.mountFolder, canCreate: true) { form.selectMountFolder($0) }
    }

    /// 选指定的文件夹。
    private func chooseFolder() {
        chooseDirectory(from: form.chosenFolder, canCreate: false) { form.chosenFolder = $0 }
    }

    /// 以 sheet 在对话框上打开目录选择面板。
    private func chooseDirectory(from folder: URL?, canCreate: Bool, choose: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = canCreate
        panel.resolvesAliases = true
        panel.directoryURL = folder

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let url = panel.url {
                choose(url)
            }
        }

        guard let window = NSApp.keyWindow else {
            finish(panel.runModal())
            return
        }

        panel.beginSheetModal(for: window, completionHandler: finish)
    }

    /// 挂载、核对或保存；记下了本机位置时关闭。
    private func submit() {
        Task {
            if await form.submit() {
                close(true)
            }
        }
    }

    /// 关闭对话框，不改动设置。
    private func cancel() {
        form.cancel()
        close(false)
    }
}
