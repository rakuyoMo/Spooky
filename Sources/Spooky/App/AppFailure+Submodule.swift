import Foundation
import SpookyKit

// MARK: - Submodule

extension AppFailure {
    /// 子模块失败的文案键、类别与恢复说明：都是仓库状态问题，Git 没有输出。
    static func classification(of submodule: SubmoduleError) -> (key: String, kind: FailureKind, recoveryKey: String) {
        switch submodule {
        case .gitDirectoryExists:
            ("submodule.error.gitDirectoryExists", .repository, "submodule.error.gitDirectoryExists.help")

        case .localModifications:
            ("submodule.error.localModifications", .repository, "submodule.error.localModifications.help")

        case .nameInUse:
            ("submodule.error.nameInUse", .repository, "submodule.error.nameInUse.help")

        case .missingRemoteURL:
            ("submodule.error.missingRemoteURL", .repository, "submodule.error.missingRemoteURL.help")
        }
    }
}
