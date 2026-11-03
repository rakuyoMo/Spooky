import SpookyKit
import SwiftUI

// MARK: - CloneRepositoryDialog

/// 克隆远端仓库：地址、克隆到的机器与目录，以及初始化子模块与 LFS 克隆两个勾选框。
///
/// 提交后对话框立即关闭，克隆在后台进行；服务器目标在 B 上克隆，并记住这台主机的克隆目录。
struct CloneRepositoryDialog: View {
    /// 菜单里列出的服务器主机别名。
    let hosts: [String]

    /// 关闭对话框。
    let close: () -> Void

    /// 开始克隆。
    let submit: (RepositoryClone) -> Void

    /// 远端地址。
    @State
    private var url: String

    /// 克隆到的目录，仓库在它下面以地址里的仓库名建目录。
    @State
    private var parent = RepositoryLocation.local(path: CloneDirectory.current)

    /// 克隆后初始化并检出子模块，默认勾上。
    @State
    private var submodules = true

    /// 克隆后取出 LFS 文件。
    @State
    private var lfs = false

    /// 地址、目标与两个勾选框。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("clone.title"),
            message: AppLocalization.text("clone.message"),
            submitTitle: AppLocalization.text("clone.submit"),
            error: problem,
            canSubmit: destination != nil && problem == nil,
            cancel: close,
            submit: start
        ) {
            DialogForm {
                DialogFormRow(label: AppLocalization.text("clone.url")) {
                    TextField("", text: $url)
                        .accessibilityIdentifier("clone-url")
                }

                HostDirectoryPicker(label: AppLocalization.text("clone.to"), hosts: hosts, directory: $parent)

                if let destination {
                    DialogFormRow(label: "") {
                        Text(AppLocalization.text("clone.destination", destination.displayPath))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }

                // 两个勾选框与上一行相隔 10，彼此相隔 8
                DialogFormOption(title: AppLocalization.text("clone.submodules"), isOn: $submodules)
                    .padding(.top, 2)

                DialogFormOption(title: AppLocalization.text("clone.lfs"), isOn: $lfs)
            }
        }
    }

    /// 预填地址，如拖进来的 URL。
    ///
    /// - Parameters:
    ///   - url: 预填的远端地址。
    ///   - hosts: 菜单里列出的服务器主机别名。
    ///   - close: 关闭对话框。
    ///   - submit: 开始克隆。
    init(url: String = "", hosts: [String], close: @escaping () -> Void, submit: @escaping (RepositoryClone) -> Void) {
        _url = State(initialValue: url)
        self.hosts = hosts
        self.close = close
        self.submit = submit
    }

}

// MARK: - Private

extension CloneRepositoryDialog {
    /// 克隆的目标：目录下以仓库名命名的新目录；地址取不出仓库名或目录不完整时为 nil。
    private var destination: RepositoryLocation? {
        CloneTarget.destination(url: url, parent: parent)
    }

    /// 地址或目标的问题；地址还没填时不提示。
    private var problem: String? {
        CloneTarget.problem(url: url, parent: parent)
    }

    /// 开始克隆并关闭对话框；服务器目标记住这台主机的克隆目录。
    private func start() {
        guard let destination else {
            return
        }

        if let host = parent.host {
            ServerCloneDirectories.remember(parent.path, for: host)
        }

        close()
        submit(RepositoryClone(
            url: url,
            destination: destination,
            options: CloneOptions(recurseSubmodules: submodules, lfs: lfs)
        ))
    }
}

// MARK: - CloneTarget

/// 克隆对话框的目标与校验，放在视图外便于测试。
enum CloneTarget {
    /// 目录下以地址里的仓库名命名的新目录；地址不合法、取不出仓库名、主机别名为空或目录不是绝对路径时为 nil。
    static func destination(url: String, parent: RepositoryLocation) -> RepositoryLocation? {
        guard
            (try? RepositoryReferences.validate(url: url)) != nil,
            let name = RepositoryClone.directoryName(for: url),
            parent.path.hasPrefix("/"),
            parent.host?.isEmpty != true
        else {
            return nil
        }

        let path = (parent.path.hasSuffix("/") ? parent.path : parent.path + "/") + name

        guard let host = parent.host else {
            return .local(path: path)
        }

        return .remote(host: host, path: path)
    }

    /// 地址或目标的问题：地址不合法、服务器目录不是绝对路径、本机目标已存在且不是空目录；地址还没填时为 nil。
    static func problem(url: String, parent: RepositoryLocation) -> String? {
        guard !url.isEmpty else {
            return nil
        }

        guard (try? RepositoryReferences.validate(url: url)) != nil, RepositoryClone.directoryName(for: url) != nil else {
            return AppLocalization.text("clone.error.invalidURL")
        }

        guard parent.path.isEmpty || parent.path.hasPrefix("/") else {
            return AppLocalization.text("hostError.absolutePath.help")
        }

        // 服务器上的目标由 B 上的 Git 检查，本机的在这里先拦下
        guard
            parent.host == nil,
            let destination = destination(url: url, parent: parent),
            let contents = try? FileManager.default.contentsOfDirectory(atPath: destination.path)
        else {
            return localFileProblem(url: url, parent: parent)
        }

        return contents.isEmpty ? nil : AppLocalization.text("clone.error.exists", destination.path)
    }

    /// 本机目标是已有的文件时的问题。
    private static func localFileProblem(url: String, parent: RepositoryLocation) -> String? {
        guard parent.host == nil, let destination = destination(url: url, parent: parent) else {
            return nil
        }

        return FileManager.default.fileExists(atPath: destination.path)
            ? AppLocalization.text("clone.error.exists", destination.path)
            : nil
    }
}
