import Foundation
import Synchronization

// MARK: - CloneProgress

/// 克隆的进度：Git 在 stderr 里报告的当前阶段，以及这一阶段的百分比与数量。
public struct CloneProgress: Sendable, Hashable {
    /// 克隆经过的阶段，原始值是 Git 进度行的标题；子模块会从头再经过一遍。
    public enum Phase: String, Sendable, CaseIterable {
        /// 远端列举要发送的对象，只有数量。
        case enumerating = "Enumerating objects"

        /// 远端清点对象。
        case counting = "Counting objects"

        /// 远端压缩对象。
        case compressing = "Compressing objects"

        /// 接收对象。
        case receiving = "Receiving objects"

        /// 解析增量。
        case resolving = "Resolving deltas"

        /// 检出文件到工作区。
        case checkingOut = "Updating files"

        /// Git LFS 下载并替换大文件。
        case filtering = "Filtering content"
    }

    /// 当前阶段。
    public let phase: Phase

    /// 阶段内的百分比，0–100；只报数量的阶段为 nil。
    public let percent: Int?

    /// 已完成的数量。
    public let completed: Int

    /// 总数；只报数量的阶段为 nil。
    public let total: Int?

    /// 当前阶段的完成比例，0–1；没有百分比时为 nil，界面显示不确定进度。
    public var fraction: Double? { percent.map { Double(min($0, 100)) / 100 } }
}

// MARK: CloneProgress.Parser

extension CloneProgress {
    /// 把 stderr 的数据块还原成进度行：按 `\r` 与 `\n` 切行，跨块的半行留到下一块。
    ///
    /// 只解析完整的行，行内的多字节字符因此不会被块边界切开；Git 用 `\r` 原地刷新百分比。
    final class Parser: Sendable {
        /// 尚未遇到行尾的字节；输出回调可能来自不同线程，用锁保持顺序。
        private let pending = Mutex(Data())

        /// 读入一块 stderr，返回其中最新的一条进度；这一块没有完整的进度行时返回 nil。
        func receive(_ data: Data) -> CloneProgress? {
            pending.withLock { pending in
                pending.append(data)
                var latest: CloneProgress?

                // 每遇到 \r 或 \n 结束一行；行尾之后的残片留在缓冲里
                while let end = pending.firstIndex(where: { $0 == 13 || $0 == 10 }) {
                    let line = String(decoding: pending[pending.startIndex ..< end], as: UTF8.self)
                    pending.removeSubrange(pending.startIndex ... end)

                    if let progress = Self.parse(line) {
                        latest = progress
                    }
                }

                return latest
            }
        }

        /// 解析一行；标题不是已知阶段或格式不符时返回 nil。
        static func parse(_ line: String) -> CloneProgress? {
            // 带百分比的进度行，如 “Receiving objects:  45% (555/1234), 1.20 MiB | 2.30 MiB/s”
            let percentLine = /^(?:remote: )?([A-Za-z ]+): +(\d+)% \((\d+)\/(\d+)\)/

            // 只有数量的进度行，如 “remote: Enumerating objects: 1234, done.”
            let countLine = /^(?:remote: )?([A-Za-z ]+): +(\d+)(?:,|$)/

            if let match = line.firstMatch(of: percentLine) {
                guard
                    let phase = Phase(rawValue: String(match.1)),
                    let percent = Int(match.2),
                    let completed = Int(match.3),
                    let total = Int(match.4)
                else { return nil }

                return CloneProgress(phase: phase, percent: percent, completed: completed, total: total)
            }

            guard
                let match = line.firstMatch(of: countLine),
                let phase = Phase(rawValue: String(match.1)),
                let completed = Int(match.2)
            else { return nil }

            return CloneProgress(phase: phase, percent: nil, completed: completed, total: nil)
        }
    }
}
