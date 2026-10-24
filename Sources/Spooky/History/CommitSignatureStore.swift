import Foundation
import Observation
import SpookyKit

// MARK: - CommitSignatureStore

/// 一个仓库窗口里校验过的提交签名：列表行与提交详情按需请求，同一轮的请求合并成一次查询。
///
/// 校验结果随密钥环与 allowed signers 变化，只在本窗口里保留，切换仓库或改变校验开关时清空。
@MainActor
@Observable
final class CommitSignatureStore {
    /// 列表开启签名校验的偏好键。
    static let verifiesKey = "historyVerifySignatures"

    /// 已校验的提交签名，键是提交的完整哈希。
    private(set) var signatures: [String: CommitSignature] = [:]

    /// 等待合并查询的提交。
    @ObservationIgnored
    private var pending = Set<String>()

    /// 已经请求过的提交，避免列表重绘时重复查询。
    @ObservationIgnored
    private var requested = Set<String>()

    /// 正在合并请求的任务。
    @ObservationIgnored
    private var batch: Task<Void, Never>? = nil

    /// 清空后递增，丢弃迟到的结果。
    @ObservationIgnored
    private var generation = 0

    /// 请求校验一个提交；已有结果或已在查询中时不重复请求。
    func request(_ commit: String, runner: GitRunner) {
        guard !requested.contains(commit) else {
            return
        }

        requested.insert(commit)
        pending.insert(commit)

        guard batch == nil else {
            return
        }

        let request = generation

        batch = Task { [weak self] in
            // 让同一轮布局里的其它行先登记，再一起查询
            await Task.yield()

            guard let self, generation == request else {
                return
            }

            let commits = Array(pending)
            pending = []
            batch = nil

            do {
                let result = try await RepositoryHistory(runner: runner).signatures(of: commits)

                guard generation == request else {
                    return
                }

                signatures.merge(result) { $1 }
            } catch {
                // 校验失败（如断线）时允许之后重新请求，界面不显示签名
                guard generation == request else {
                    return
                }

                requested.subtract(commits)
            }
        }
    }

    /// 清空全部结果与进行中的请求。
    func reset() {
        generation += 1
        batch?.cancel()
        batch = nil
        pending = []
        requested = []
        signatures = [:]
    }
}

// MARK: - Presentation

extension SignatureStatus {
    /// 签名弹窗与详情里显示的状态文字。
    var title: String {
        switch self {
        case .good: AppLocalization.text("signature.good")
        case .bad: AppLocalization.text("signature.bad")
        case .unknownValidity: AppLocalization.text("signature.unknownValidity")
        case .expiredSignature: AppLocalization.text("signature.expiredSignature")
        case .expiredKey: AppLocalization.text("signature.expiredKey")
        case .revokedKey: AppLocalization.text("signature.revokedKey")
        case .cannotCheck: AppLocalization.text("signature.cannotCheck")
        case .unsigned: AppLocalization.text("signature.unsigned")
        }
    }
}
