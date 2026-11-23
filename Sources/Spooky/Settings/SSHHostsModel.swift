import Foundation
import Observation
import SpookyKit

// MARK: - SSHHostsModel

/// SSH Hosts 页的状态：读出的 SSH 配置、选中的别名与最近一次读写失败。
///
/// 配置文件也由终端里的 SSH 与别的程序读写：修改按列表里的位置找别名，写入前核对文件还是修改所依据的内容。
@MainActor
@Observable
final class SSHHostsModel {
    /// 读写失败的原因。
    enum Failure: Equatable {
        /// 读不出文件，带系统给出的原因。
        case read(String)

        /// 写不进文件，带系统给出的原因。
        case write(String)

        /// 文件已经不是修改所依据的内容，这次修改没有写入。
        case changed
    }

    /// 最近一次读出的配置。
    private(set) var file = SSHConfigFile()

    /// 选中的别名在列表里的位置。
    var selection: Int? = nil

    /// 最近一次读写失败；成功读写后清空。
    private(set) var failure: Failure? = nil

    /// 配置文件的位置。
    private let url: URL

    /// 创建状态。
    ///
    /// - Parameter url: 配置文件的位置；测试传入临时文件。
    init(url: URL = SSHConfigFile.userFile) {
        self.url = url
    }

    /// 读出文件；失败时保留上一次的内容并记下原因。
    ///
    /// 内容变了时取消选中：同一位置上可能已经是另一个别名。
    func reload() {
        do {
            let read = try SSHConfigFile(contentsOf: url)

            if read != file {
                selection = nil
            }

            file = read
            failure = nil
        } catch {
            failure = .read(error.localizedDescription)
        }
    }

    /// 把一次修改写进文件。
    ///
    /// 文件已经不是 `listed` 时不写入，列表换成新的内容。
    ///
    /// - Parameters:
    ///   - listed: 修改所依据的内容：打开对话框或点下删除时列表里的配置。
    ///   - change: 对配置的修改。
    /// - Returns: 是否已写入。
    @discardableResult
    func save(from listed: SSHConfigFile, _ change: (inout SSHConfigFile) -> Void) -> Bool {
        reload()

        guard failure == nil else {
            return false
        }

        guard file == listed else {
            failure = .changed
            return false
        }

        var edited = file
        change(&edited)

        do {
            try edited.write(to: url)
            file = edited
        } catch {
            failure = .write(error.localizedDescription)
            return false
        }

        return true
    }
}
