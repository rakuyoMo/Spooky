import AppKit
import SwiftUI

// MARK: - CreateRepositoryDialog

/// 新建本机仓库：填写仓库名、选择所在目录；同名的文件已存在时不能新建。
///
/// 提交后对话框立即关闭，`git init` 随后执行，失败显示在窗口的错误 sheet 里。
struct CreateRepositoryDialog: View {
    /// 关闭对话框。
    let close: () -> Void

    /// 提交新仓库的绝对路径。
    let submit: (String) -> Void

    /// 仓库名，也是新建的目录名。
    @State
    private var name = ""

    /// 仓库所在的目录，默认是用户主目录。
    @State
    private var directory = FileManager.default.homeDirectoryForCurrentUser

    /// 名称、位置两行表单。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("bookmarks.create.title"),
            message: AppLocalization.text("bookmarks.create.message"),
            submitTitle: AppLocalization.text("bookmarks.create.submit"),
            error: error,
            canSubmit: !trimmedName.isEmpty && error == nil,
            cancel: close,
            submit: {
                close()
                submit(target.path)
            }
        ) {
            DialogForm {
                DialogFormRow(label: AppLocalization.text("bookmarks.create.name")) {
                    TextField("", text: $name)
                        .accessibilityIdentifier("create-repository-name")
                }

                DialogFormRow(label: AppLocalization.text("bookmarks.create.location")) {
                    HStack(spacing: 8) {
                        Text(directory.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(AppLocalization.text("bookmarks.create.choose"), action: chooseDirectory)
                    }
                }
            }
        }
    }
}

// MARK: - Private

extension CreateRepositoryDialog {
    /// 去掉首尾空白后的仓库名。
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 新仓库的目录。
    private var target: URL {
        directory.appending(path: trimmedName, directoryHint: .isDirectory)
    }

    /// 名称不能含路径分隔符，也不能与已有的文件重名；同名目录可以，Git 会在里面初始化。没有问题时为 nil。
    private var error: String? {
        guard !trimmedName.isEmpty else {
            return nil
        }

        if trimmedName.contains("/") || trimmedName == "." || trimmedName == ".." {
            return AppLocalization.text("bookmarks.create.invalidName")
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue ? AppLocalization.text("bookmarks.create.fileExists") : nil
    }

    /// 以 sheet 弹出目录选择器，可以在里面新建目录。
    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = directory
        panel.prompt = AppLocalization.text("bookmarks.create.choosePrompt")

        guard let window = NSApp.keyWindow else {
            return
        }

        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                directory = url
            }
        }
    }
}
