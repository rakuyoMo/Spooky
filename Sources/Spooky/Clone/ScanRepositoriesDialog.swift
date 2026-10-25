import SpookyKit
import SwiftUI

// MARK: - ScanRepositoriesDialog

/// 在选定的目录里寻找仓库并加入书签：本机或一台服务器上的目录，只扫描用户选的这个目录。
///
/// 服务器只在 B 上扫描，结果边找边显示，按主机分组；已有书签的仓库不列出。可以多次扫描不同的机器，结果累加。
struct ScanRepositoriesDialog: View {
    /// 菜单里列出的服务器主机别名。
    let hosts: [String]

    /// 已有书签的仓库，不再列出。
    let existing: Set<RepositoryLocation>

    /// 关闭对话框。
    let close: () -> Void

    /// 把勾选的仓库加入书签。
    let add: ([RepositoryLocation]) -> Void

    /// 要扫描的目录。
    @State
    private var directory = RepositoryLocation.local(path: NSHomeDirectory())

    /// 找到的仓库，按找到的顺序。
    @State
    private var results: [RepositoryLocation] = []

    /// 勾选的仓库。
    @State
    private var selected: Set<RepositoryLocation> = []

    /// 正在进行的扫描。
    @State
    private var scan: Task<Void, Never>?

    /// 扫描失败的说明与原文。
    @State
    private var failure: AppFailure?

    /// 目录、结果列表与状态行。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("scan.title"),
            message: AppLocalization.text("scan.message"),
            submitTitle: AppLocalization.text("scan.add", selected.count),
            error: nil,
            canSubmit: !selected.isEmpty,
            cancel: {
                scan?.cancel()
                close()
            },
            submit: {
                scan?.cancel()
                close()
                add(results.filter(selected.contains))
            }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                DialogForm {
                    HostDirectoryPicker(label: AppLocalization.text("scan.in"), hosts: hosts, directory: $directory)

                    DialogFormRow(label: "") {
                        Button(AppLocalization.text(scan == nil ? "scan.start" : "scan.stop"), action: toggleScan)
                            .disabled(scan == nil && !directory.path.hasPrefix("/"))
                    }
                }

                resultList

                if let failure {
                    FailureDetailsView(failure: failure)
                        .padding(.horizontal, 20)
                }

                statusRow
            }
            .onDisappear { scan?.cancel() }
        }
    }
}

// MARK: - Layout

extension ScanRepositoriesDialog {
    /// 按主机分组的结果，每行一个勾选框、仓库名与路径。
    private var resultList: some View {
        List {
            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.locations, id: \.self) { location in
                        Toggle(isOn: binding(for: location)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.name)
                                    .font(.system(size: 13))

                                Text(location.path)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
        .frame(height: 200)
        .padding(.horizontal, 20)
    }

    /// 全选、扫描中的转圈与找到的数量。
    private var statusRow: some View {
        HStack(spacing: 8) {
            Button(AppLocalization.text("scan.selectAll")) { selected = Set(results) }
                .controlSize(.small)
                .disabled(results.isEmpty)

            if scan != nil {
                ProgressView()
                    .controlSize(.small)

                Text(AppLocalization.text("scan.searching"))
            } else if !results.isEmpty {
                Text(AppLocalization.text("scan.found", results.count))
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    /// 结果按机器分组：本机在前，服务器按主机别名排序。
    private var groups: [(title: String, locations: [RepositoryLocation])] {
        let grouped = Dictionary(grouping: results) { $0.host ?? "" }

        return grouped.keys.sorted().map { host in
            let title = host.isEmpty ? AppLocalization.text("clone.machine.local") : host
            return (title, grouped[host] ?? [])
        }
    }
}

// MARK: - Private

extension ScanRepositoriesDialog {
    /// 一个结果的勾选状态。
    private func binding(for location: RepositoryLocation) -> Binding<Bool> {
        Binding(
            get: { selected.contains(location) },
            set: { isOn in
                if isOn {
                    selected.insert(location)
                } else {
                    selected.remove(location)
                }
            }
        )
    }

    /// 开始扫描选定的目录，或停止正在进行的扫描；找到的仓库默认勾选。
    private func toggleScan() {
        if let scan {
            scan.cancel()
            self.scan = nil
            return
        }

        failure = nil
        let target = directory

        scan = Task {
            // 服务器的主机连接先装上询问凭据与口令的处理器
            if let host = target.host {
                _ = await RemoteConnection.presentingHost(host)
            }

            do {
                for try await location in RepositoryScan.repositories(in: target)
                    where !existing.contains(location) && !results.contains(location)
                {
                    results.append(location)
                    selected.insert(location)
                }
            } catch {
                failure = AppFailure(error: error, opening: false, location: target)
            }

            scan = nil
        }
    }
}
