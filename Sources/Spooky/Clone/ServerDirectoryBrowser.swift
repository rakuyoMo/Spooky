import SpookyKit
import SwiftUI

// MARK: - ServerDirectoryBrowser

/// 浏览服务器上的目录：路径栏、上一级、子目录列表与选择按钮。
///
/// 目录经这台主机的连接在 B 上列出；Git 工作区标出，不能读取的目录变淡、不能进入。列目录可以取消，失败时显示原文。
struct ServerDirectoryBrowser: View {
    /// 主机别名。
    let host: String

    /// 结束浏览：选中的目录，取消时为 nil。
    let finish: (String?) -> Void

    /// 正在查看的目录；空字符串表示还没取到 B 上用户的主目录。
    @State
    private var path: String

    /// 路径栏里正在编辑的文字。
    @State
    private var typedPath: String

    /// 目录里的子目录。
    @State
    private var entries: [HostDirectoryEntry] = []

    /// 选中的子目录。
    @State
    private var selection: String?

    /// 列目录失败的说明与原文。
    @State
    private var failure: AppFailure?

    /// 正在列目录。
    @State
    private var isLoading = false

    /// 路径栏、列表、错误与底栏，宽 480。
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalization.text("browse.title", host))
                .font(.system(size: 14, weight: .bold))

            pathBar

            list

            if let failure {
                FailureDetailsView(failure: failure)
            }

            footer
        }
        .padding(20)
        .frame(width: 480, height: 420)
        .task(id: path) { await load() }
    }

    /// 从给定目录开始浏览；没有给出时从 B 上用户的主目录开始。
    ///
    /// - Parameters:
    ///   - host: 主机别名。
    ///   - path: 开始浏览的目录。
    ///   - finish: 结束浏览。
    init(host: String, path: String, finish: @escaping (String?) -> Void) {
        self.host = host
        self.finish = finish
        _path = State(initialValue: path)
        _typedPath = State(initialValue: path)
    }

}

// MARK: - Layout

extension ServerDirectoryBrowser {
    /// 上一级按钮与可以手填的路径，回车跳转。
    private var pathBar: some View {
        HStack(spacing: 8) {
            Button {
                go(to: parent(of: path))
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(path == "/" || path.isEmpty)
            .accessibilityLabel(AppLocalization.text("browse.up"))

            TextField("", text: $typedPath)
                .onSubmit { go(to: typedPath) }
                .accessibilityLabel(AppLocalization.text("clone.directory"))
        }
    }

    /// 子目录列表：双击进入，Git 工作区带标记，不能读取的变淡。
    private var list: some View {
        List(entries, id: \.path, selection: $selection) { entry in
            HStack(spacing: 6) {
                Image(systemName: entry.isRepository ? "externaldrive" : "folder")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text(entry.name)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if entry.isRepository {
                    Text(AppLocalization.text("browse.repository"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(entry.isReadable ? 1 : 0.5)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if entry.isReadable {
                    go(to: entry.path)
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if entries.isEmpty, failure == nil, !path.isEmpty {
                Text(AppLocalization.text("browse.empty"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 取消与选择；选中子目录时选它，否则选正在查看的目录。
    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(AppLocalization.text("action.cancel")) { finish(nil) }
                .keyboardShortcut(.cancelAction)

            Button(AppLocalization.text("bookmarks.create.choosePrompt")) {
                finish(selection ?? path)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(path.isEmpty)
        }
    }
}

// MARK: - Private

extension ServerDirectoryBrowser {
    /// 上一级目录；根目录的上一级仍是根目录。
    private func parent(of path: String) -> String {
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        return parent.isEmpty ? "/" : parent
    }

    /// 跳到另一个目录；不是绝对路径时不跳。
    private func go(to directory: String) {
        guard directory.hasPrefix("/") else {
            typedPath = path
            return
        }

        selection = nil
        path = directory
    }

    /// 列出正在查看的目录；还不知道从哪里开始时先取 B 上用户的主目录。
    private func load() async {
        isLoading = true
        failure = nil
        defer { isLoading = false }

        let connection = await RemoteConnection.presentingHost(host)

        do {
            guard !path.isEmpty else {
                let home = try await connection.connectHost().homeDirectory
                go(to: home)
                return
            }

            let listed = try await HostDirectories.list(.remote(host: host, path: path))
            try Task.checkCancellation()

            entries = listed
            typedPath = path
        } catch {
            guard !Task.isCancelled else { return }

            entries = []
            typedPath = path
            failure = AppFailure(error: error, opening: false, location: .remote(host: host, path: path))
        }
    }
}
