import Darwin
import Dispatch
import Foundation
import Synchronization

// MARK: - ProcessGate

/// 让测试脚本里的命令停在闸门上，等测试放行后再继续。
///
/// 脚本走到闸门时先往报到管道写一个字节，再从放行管道读一行。两条命名管道的读写两端都由测试一直打开，
/// 脚本打开管道时不会阻塞；测试等的是脚本真正走到闸门，不轮询文件，也不靠延时。
///
/// 只拦一次时先用 ``arm()`` 武装：脚本用 ``claim`` 把武装文件改名即认领，改名同时算作报到，认领后接 ``hold`` 停住。
/// 改名只是一次系统调用，认领与报到之间没有能被打断的空隙。
public final class ProcessGate: Sendable {
    /// 写进脚本的一行 shell：报到，然后等放行。
    public let command: String

    /// 武装文件还在时退出码为 0 的一行 shell：脚本据此决定要不要准备认领。
    public let armed: String

    /// 认领武装的一行 shell：把武装文件改名，成功时退出码为 0；改名的那一刻就算一次报到。
    public let claim: String

    /// 认领之后停在闸门上的一行 shell：只等放行，不再报到。
    public let hold: String

    /// 武装文件，被认领时改名为同目录的 `-claimed` 文件。
    private let armFile: URL

    /// 报到管道的读写端。
    private let arrivalPipe: Int32

    /// 放行管道的读写端。
    private let releasePipe: Int32

    /// 监听报到管道的读事件。
    private let source: any DispatchSourceRead

    /// 监听武装文件改名的事件，认领或闸门释放时取消。
    private let armSources = Mutex<[any DispatchSourceFileSystemObject]>([])

    /// 还没被认领的报到次数与等待报到的测试。
    private let state = Mutex(State())

    /// 在目录里建两条命名管道并打开它们。
    ///
    /// - Parameters:
    ///   - directory: 放管道与武装文件的目录，由测试负责删除。拦读取时不放在打开着的仓库里：
    ///     那里的文件变化会触发会话刷新，刷新重读时取消正在进行的读取。
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

        armFile = directory.appending(path: name + "-arm")
        let claimed = directory.appending(path: name + "-claimed")

        hold = "read -r _ < \(Self.quoted(release.path))"
        command = "printf x > \(Self.quoted(arrival.path)) && \(hold)"
        armed = "[ -f \(Self.quoted(armFile.path)) ]"
        claim = "mv \(Self.quoted(armFile.path)) \(Self.quoted(claimed.path)) 2>/dev/null"
        source = DispatchSource.makeReadSource(fileDescriptor: arrivalPipe, queue: .global())

        source.setEventHandler { [weak self] in
            self?.receiveArrivals()
        }

        source.resume()
    }

    /// 停止监听，关闭管道。
    deinit {
        source.cancel()

        for armSource in armSources.withLock({ $0 }) {
            armSource.cancel()
        }

        close(arrivalPipe)
        close(releasePipe)
    }

    /// 武装一次：建好武装文件并监听它被改名。
    ///
    /// 脚本用 ``claim`` 认领的那一刻算一次报到：认领的进程即使在停住之前就被结束（如取消的宽限期过后被 KILL），
    /// 等报到的测试也照样继续。上一次武装还没被认领时再武装会抛出错误。
    public func arm() throws {
        let descriptor = Darwin.open(armFile.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)

        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        let path = armFile.path
        let armSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .rename,
            queue: .global()
        )

        armSource.setEventHandler { [weak self] in
            self?.receiveClaim(armSource)
        }

        // 监听挂上之前就被认领的，改名事件不会再来：按路径上还是不是这个文件补报到
        armSource.setRegistrationHandler { [weak self] in
            var watched = stat()
            var current = stat()

            guard
                fstat(descriptor, &watched) == 0,
                stat(path, &current) != 0 || current.st_ino != watched.st_ino
            else { return }

            self?.receiveClaim(armSource)
        }

        armSource.setCancelHandler {
            close(descriptor)
        }

        armSources.withLock { $0.append(armSource) }
        armSource.resume()
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

    /// 读出报到管道里的字节：每个字节是一次报到。
    private func receiveArrivals() {
        var bytes = [UInt8](repeating: 0, count: 64)
        let count = read(arrivalPipe, &bytes, bytes.count)

        guard count > 0 else {
            return
        }

        arrive(count)
    }

    /// 武装文件被认领：改名事件与挂上监听时的补查都会走到这里，同一次武装只报到一次。
    ///
    /// - Parameter armSource: 监听这次武装的事件源；它的处理按顺序执行，取消后不再报到。
    private func receiveClaim(_ armSource: any DispatchSourceFileSystemObject) {
        guard !armSource.isCancelled else {
            return
        }

        armSource.cancel()
        arrive(1)
    }

    /// 记下若干次报到：有测试在等就交给最早的几个，没有就记下来。
    ///
    /// - Parameter count: 报到的次数。
    private func arrive(_ count: Int) {
        let resumed = state.withLock { $0.arrive(count) }

        for continuation in resumed {
            continuation.resume()
        }
    }
}
