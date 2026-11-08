import Darwin
import Dispatch
import Foundation
import Synchronization

// MARK: - ProcessGate

/// 让测试脚本里的命令停在闸门上，等测试放行后再继续。
///
/// 脚本走到闸门时先往报到管道写一个字节，再从放行管道读一行。两条命名管道的读写两端都由测试一直打开，
/// 脚本打开管道时不会阻塞；测试等的是脚本真正走到闸门，不轮询文件，也不靠延时。
public final class ProcessGate: Sendable {
    /// 写进脚本的一行 shell：报到，然后等放行。
    public let command: String

    /// 报到管道的读写端。
    private let arrivalPipe: Int32

    /// 放行管道的读写端。
    private let releasePipe: Int32

    /// 监听报到管道的读事件。
    private let source: any DispatchSourceRead

    /// 还没被认领的报到次数与等待报到的测试。
    private let state = Mutex(State())

    /// 在目录里建两条命名管道并打开它们。
    ///
    /// - Parameters:
    ///   - directory: 放管道的目录，由测试负责删除。
    ///   - name: 管道的名字前缀；同一目录里有几道闸门时用它区分。
    public init(in directory: URL, name: String = "gate") throws {
        let arrival = directory.appending(path: name + "-arrival")
        let release = directory.appending(path: name + "-release")

        for url in [arrival, release] where mkfifo(url.path, 0o600) != 0 {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        // 以读写方式打开命名管道不会阻塞；管道两端始终有人，脚本打开它时也不会阻塞
        arrivalPipe = Darwin.open(arrival.path, O_RDWR | O_NONBLOCK | O_CLOEXEC)
        releasePipe = Darwin.open(release.path, O_RDWR | O_CLOEXEC)

        guard arrivalPipe >= 0, releasePipe >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        command = "printf x > \(Self.quoted(arrival.path)) && read -r _ < \(Self.quoted(release.path))"
        source = DispatchSource.makeReadSource(fileDescriptor: arrivalPipe, queue: .global())

        source.setEventHandler { [weak self] in
            self?.receiveArrivals()
        }

        source.resume()
    }

    /// 停止监听，关闭管道。
    deinit {
        source.cancel()
        close(arrivalPipe)
        close(releasePipe)
    }

    /// 等到下一次报到；之前已经报到、还没被认领的，直接认领。
    public func arrival() async {
        await withCheckedContinuation { continuation in
            let arrived = state.withLock { $0.claim(continuation) }

            if arrived {
                continuation.resume()
            }
        }
    }

    /// 放行一次：已经停在闸门上的脚本，或之后第一个走到闸门的脚本，继续执行。
    public func release() {
        let line: [UInt8] = [0x0A]
        _ = line.withUnsafeBytes { write(releasePipe, $0.baseAddress, 1) }
    }
}

// MARK: ProcessGate.State

extension ProcessGate {
    /// 报到与等待的配对。
    private struct State {
        /// 还没被认领的报到次数。
        var unclaimed = 0

        /// 按先后等待报到的测试。
        var waiters: [CheckedContinuation<Void, Never>] = []

        /// 记下若干次报到，返回因此可以继续的测试。
        ///
        /// - Parameter count: 报到的次数。
        mutating func arrive(_ count: Int) -> [CheckedContinuation<Void, Never>] {
            let resumed = Array(waiters.prefix(count))
            waiters.removeFirst(resumed.count)
            unclaimed += count - resumed.count
            return resumed
        }

        /// 认领一次报到；没有可认领的报到时排进等待，返回 false。
        ///
        /// - Parameter continuation: 等待报到的测试。
        mutating func claim(_ continuation: CheckedContinuation<Void, Never>) -> Bool {
            guard unclaimed > 0 else {
                waiters.append(continuation)
                return false
            }

            unclaimed -= 1
            return true
        }
    }
}

// MARK: - Private

extension ProcessGate {
    /// 按 POSIX shell 的规则给路径加单引号。
    private static func quoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// 读出报到管道里的字节：每个字节是一次报到，有测试在等就交给最早的一个，没有就记下来。
    private func receiveArrivals() {
        var bytes = [UInt8](repeating: 0, count: 64)
        let count = read(arrivalPipe, &bytes, bytes.count)

        guard count > 0 else {
            return
        }

        let resumed = state.withLock { $0.arrive(count) }

        for continuation in resumed {
            continuation.resume()
        }
    }
}
