import CoreServices
import Foundation

/// 本机工作区的递归文件事件监听，Git 目录与新建子目录同样触发刷新。
@MainActor
final class RepositoryFileMonitor {
    /// FSEvents 持有的流，由本对象负责停止和释放。
    private var stream: FSEventStreamRef? = nil

    /// 合并短时间内的事件，避免保存文件时连续执行 Git。
    private var debounce: Task<Void, Never>? = nil

    /// 事件到达后的会话刷新入口。
    private let changed: @MainActor () -> Void

    /// 流在主队列交付，回调只调度刷新，不读取文件内容。
    init(path: String, changed: @escaping @MainActor () -> Void) {
        self.changed = changed
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        stream = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info else { return }
                MainActor.assumeIsolated {
                    Unmanaged<RepositoryFileMonitor>.fromOpaque(info).takeUnretainedValue().schedule()
                }
            },
            &context,
            [path] as CFArray,

            // FSEvents 的系统名称写作 Id，格式化的缩写规则不能改动这一行
            // swiftformat:disable:next acronyms
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream {
            FSEventStreamSetDispatchQueue(stream, .main)
            FSEventStreamStart(stream)
        }
    }

    /// 关闭仓库时先撤销回调，防止事件命中已经释放的会话。
    func stop() {
        debounce?.cancel()
        debounce = nil

        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    /// 一轮保存事件只触发一次刷新。
    private func schedule() {
        debounce?.cancel()
        debounce = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) }
            catch { return }
            self?.changed()
        }
    }
}
