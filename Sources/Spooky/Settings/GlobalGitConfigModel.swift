import Foundation
import Observation
import SpookyKit

// MARK: - GlobalGitConfigModel

/// Git Config 与 Integration 页共用的全局配置状态：读出的配置、本机的签名密钥与最近一次读写失败。
///
/// 每次写入后重新读取，页面显示的总是 Git 实际生效的值。
@MainActor
@Observable
final class GlobalGitConfigModel {
    /// 读写失败的标题与 Git 原文。
    struct Failure: Equatable {
        /// 读取还是写入失败。
        let title: String

        /// Git 的原始输出与退出码，可选中复制。
        let details: String
    }

    /// 最近一次读出的配置。
    private(set) var configuration = GlobalGitConfiguration()

    /// 已经读过一次；之前页面上的值都是空的。
    private(set) var isLoaded = false

    /// 本机可用的签名密钥。
    private(set) var keys: [SigningKey] = []

    /// 最近一次读写失败；成功读写后清空。
    private(set) var failure: Failure? = nil

    /// 执行读写的全局配置。
    private let config: GlobalGitConfig

    /// 创建状态；测试传入隔离的全局配置。
    init(config: GlobalGitConfig = GlobalGitConfig()) {
        self.config = config
    }

    /// 读出配置；失败时保留上一次的值并记下原因。
    func reload() async {
        do {
            configuration = try await config.read()
            isLoaded = true
            failure = nil
        } catch {
            failure = Failure(
                title: AppLocalization.text("gitConfig.error.read"),
                details: AppFailure(error: error, opening: false, location: nil).details
            )
        }
    }

    /// 列出本机的签名密钥；agent 里的密钥可能随时增减，每次打开页面重新列出。
    func reloadKeys() async {
        keys = await SigningKeys.local()
    }

    /// 写入一组键后重新读取；值为 nil 时删除这个键。
    ///
    /// - Parameter entries: 键与新值。
    func write(_ entries: [(key: String, value: String?)]) async {
        do {
            try await config.set(entries)
            await reload()
        } catch {
            failure = Failure(
                title: AppLocalization.text("gitConfig.error.write"),
                details: AppFailure(error: error, opening: false, location: nil, writing: true).details
            )
        }
    }
}
