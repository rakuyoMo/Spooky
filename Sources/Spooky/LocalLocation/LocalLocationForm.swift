import Foundation
import Observation
import SpookyKit

// MARK: - LocalLocationForm

/// 本机位置对话框的表单：选方式与方式带的文件夹，按主按钮时挂载、核对或直接保存，通过后记下本机位置。
///
/// 只经仓库的本机位置状态读写，不依赖仓库窗口的会话。
@MainActor
@Observable
final class LocalLocationForm {
    /// 方式弹出菜单的一项。
    enum Item: Hashable {
        /// 一种方式。
        case method(ServerLocalLocation.Method)

        /// 还在检测可用条件时，占着挂载方式位置的不可选项。
        case checking
    }

    /// 仓库的本机位置状态。
    let mounts: RepositoryMountState

    /// 主机别名。
    let host: String

    /// 仓库的执行器，核对用的标记文件经它写进 B 的 Git 目录。
    let runner: GitRunner

    /// 从 Show in Finder 换过来时不能直接打开的原因，写在说明前面；其余为 nil。
    let reason: String?

    /// 选中的方式。
    var method: ServerLocalLocation.Method

    /// 指定的文件夹；还没有选时为 nil。
    var chosenFolder: URL? = nil

    /// sshfs 挂载到的文件夹；还没有选时为 nil。
    private(set) var mountFolder: URL? = nil

    /// 选了不空的挂载文件夹时的说明。
    private(set) var mountFolderProblem: String? = nil

    /// 这台 Mac 现在可用的挂载方式；还在检测时为 nil。
    private(set) var methods: Set<RemoteMountMethod>? = nil

    /// 挂载或核对的进度；没有进行时为 nil。
    private(set) var progress: String? = nil

    /// 上次挂载或核对失败的说明。
    private(set) var failure: String? = nil

    /// 对话框已取消：进行中的挂载或核对照常结束，结果不再采用。
    @ObservationIgnored
    private var isCancelled = false

    /// 最近一次挂载或核对。
    @ObservationIgnored
    private var checking: Task<Result<ServerLocalLocation, LocalLocationFailure>, Never>? = nil

    /// 弹出菜单的各项：自动查找与指定文件夹总在；挂载方式可用或是现在的方式时列出，检测中在它们的位置放一个 “正在检测”。
    var items: [Item] {
        var items: [Item] = []

        for method in ServerLocalLocation.Method.allCases {
            guard let mounting = method.mounting, method != mounts.location.method else {
                items.append(.method(method))
                continue
            }

            if let methods {
                if methods.contains(mounting) {
                    items.append(.method(method))
                }
            } else if !items.contains(.checking) {
                items.append(.checking)
            }
        }

        return items
    }

    /// 主按钮的标题：挂载方式为 Mount，其余为 Save。
    var submitTitle: String {
        AppLocalization.text(method.mounting == nil ? "localLocation.save" : "localLocation.mount")
    }

    /// 错误区的说明：选 sshfs 挂载、挂载文件夹不空时说明它，否则是上次失败的说明。
    var error: String? {
        (method == .sshfsMount ? mountFolderProblem : nil) ?? failure
    }

    /// 主按钮能不能按：没有进行中的挂载或核对，该选的文件夹选了且能用。
    var canSubmit: Bool {
        progress == nil
            && selectedLocation != nil
            && (method != .sshfsMount || mountFolderProblem == nil)
    }

    /// 按仓库现在的本机位置填好表单。
    ///
    /// - Parameters:
    ///   - mounts: 仓库的本机位置状态。
    ///   - host: 主机别名。
    ///   - runner: 仓库的执行器。
    ///   - reason: 从 Show in Finder 换过来时不能直接打开的原因。
    ///   - failure: 从 Show in Finder 换过来时挂载失败的说明，一开始就写在错误区。
    init(
        mounts: RepositoryMountState,
        host: String,
        runner: GitRunner,
        reason: String? = nil,
        failure: String? = nil
    ) {
        self.mounts = mounts
        self.host = host
        self.runner = runner
        self.reason = reason
        self.failure = failure
        method = mounts.location.method

        switch mounts.location {
        case .sshfsMount(let folder):
            mountFolder = folder

        case .chosenFolder(let folder):
            chosenFolder = folder

        case .automatic, .smbMount:
            break
        }
    }

    /// sshfs 挂载到的文件夹不能用的说明：不空时说明它；能用时为 nil。添加服务器仓库的挂载选项共用。
    ///
    /// - Parameter folder: 选定的本机文件夹。
    static func problem(ofMountFolder folder: URL) -> String? {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []

        return contents.isEmpty
            ? nil
            : AppLocalization.text("localLocation.notEmpty", HomePath.abbreviated(folder.path))
    }

    /// 检测这台 Mac 现在可用的挂载方式；对话框打开时调用。
    func detect() async {
        methods = await mounts.mounter.methods(host)
    }

    /// 选定 sshfs 挂载到的文件夹；不空时说明原因，不能用。
    ///
    /// - Parameter folder: 选定的本机文件夹。
    func selectMountFolder(_ folder: URL) {
        mountFolder = folder
        mountFolderProblem = Self.problem(ofMountFolder: folder)
    }

    /// 按主按钮：自动查找保存后重新查找；挂载方式挂载并核对，SMB 总是从共享列表选共享；指定文件夹经标记文件核对。
    ///
    /// - Returns: 记下了本机位置时为 true，对话框随之关闭；失败或已取消时为 false，原来的设置不变。
    func submit() async -> Bool {
        guard canSubmit, let location = selectedLocation, let path = mounts.repository?.path else {
            return false
        }

        failure = nil

        // 自动查找不用挂载或核对，保存后仓库目录重新查找
        if location == .automatic {
            mounts.save(.automatic)
            mounts.locate([path], host: host, runner: runner, refreshes: true)
            return true
        }

        progress = AppLocalization.text(method == .chosenFolder ? "localLocation.verifying" : "localLocation.mounting")

        // 记下进行中的这次，对话框取消后 Show in Finder 的流程等它结束
        let task = Task { await check(location) }
        checking = task

        let result = await task.value
        progress = nil

        guard !isCancelled else {
            return false
        }

        switch result {
        case .success(let accepted):
            mounts.save(accepted)
            return true

        case .failure(let failure):
            self.failure = failure.message
            return false
        }
    }

    /// 取消对话框：进行中的挂载或核对照常结束，结果不再采用。
    func cancel() {
        isCancelled = true
    }

    /// 等进行中的挂载或核对结束；没有时立即返回。
    func waitForCheck() async {
        _ = await checking?.value
    }
}

// MARK: - Private

extension LocalLocationForm {
    /// 表单现在选定的本机位置；该选的文件夹没选时为 nil。
    private var selectedLocation: ServerLocalLocation? {
        switch method {
        case .automatic: .automatic
        case .smbMount: .smbMount(share: nil)
        case .sshfsMount: mountFolder.map(ServerLocalLocation.sshfsMount)
        case .chosenFolder: chosenFolder.map(ServerLocalLocation.chosenFolder)
        }
    }

    /// 挂载方式挂载并核对；指定文件夹只核对。
    private func check(_ location: ServerLocalLocation) async -> Result<ServerLocalLocation, LocalLocationFailure> {
        guard case .chosenFolder(let folder) = location else {
            return await mounts.mount(location, host: host, runner: runner, interactive: true)
        }

        if let failure = await mounts.verify(folder, runner: runner) {
            return .failure(failure)
        }

        return .success(location)
    }
}
