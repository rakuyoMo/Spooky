import CoreFoundation

// MARK: - until

/// 等到主线程上的状态满足条件，不轮询、不设上限。
///
/// 主线程的 run loop 每处理完一批事件、开始下一批或进入休眠之前，都重新判断一次条件。
/// 条件只能读主线程上的状态，如会话、窗口与视图：后台线程或子进程改变的状态不会唤醒 run loop，
/// 那类事件改等产生它的任务，或用 ``ProcessGate`` 让子进程报到。
///
/// - Parameter condition: 要等到成立的条件；在主线程上判断，不能挂起，也不能转动 run loop。
@MainActor
public func until(_ condition: @escaping @MainActor () -> Bool) async {
    guard !condition() else {
        return
    }

    let waiter = RunLoopWaiter(condition: condition)

    await withTaskCancellationHandler {
        await withCheckedContinuation { waiter.start($0) }
    } onCancel: {
        Task { @MainActor in waiter.finish() }
    }
}

// MARK: - untilFinished

/// 等到任务全部结束：每等完一个就重新取一次，等待期间新起的任务一并等完。
///
/// 适合 “读取期间又收到的请求在读完时另起任务” 这类接力的读取：前一个任务结束前已经起好下一个，
/// 等完时不会漏掉。
///
/// - Parameter tasks: 取出当前进行中的任务。
@MainActor
public func untilFinished(_ tasks: @MainActor () -> [Task<Void, Never>]) async {
    var finished = Set<Task<Void, Never>>()

    while let task = tasks().first(where: { !finished.contains($0) }) {
        await task.value
        finished.insert(task)
    }
}

// MARK: - runLoopTurns

/// 让主线程的 run loop 转过若干圈，每圈执行一次动作。
///
/// 只用在没有状态可等、又要让 SwiftUI 把接连几轮更新做完的地方，如每圈排一次版；
/// 圈数与机器快慢无关，不靠延时。有状态可等时用 ``until(_:)``。
///
/// - Parameters:
///   - count: 圈数。
///   - action: 每圈执行的动作。
@MainActor
public func runLoopTurns(_ count: Int, each action: @escaping @MainActor () -> Void = { }) async {
    let turns = TurnCounter()

    await until {
        action()
        turns.value += 1

        guard turns.value > count else {
            // 没有别的事件时 run loop 转完这圈就会休眠；圈数没到就唤醒它，接着转下一圈
            CFRunLoopWakeUp(CFRunLoopGetMain())
            return false
        }

        return true
    }
}

// MARK: - TurnCounter

/// 已经转过的圈数。
@MainActor
private final class TurnCounter {
    /// 判断条件的次数，第一次在开始等待之前。
    var value = 0
}

// MARK: - RunLoopWaiter

/// 一次等待：在主线程的 run loop 上挂一个观察者，条件成立或任务取消时摘下并继续。
@MainActor
private final class RunLoopWaiter {
    /// 处理完一批事件之后与进入休眠之前各判断一次。
    private static let activities = CFRunLoopActivity.beforeSources.rawValue | CFRunLoopActivity.beforeWaiting.rawValue

    /// 要等到成立的条件。
    private let condition: @MainActor () -> Bool

    /// 等待中的测试；继续之后清空，保证只继续一次。
    private var continuation: CheckedContinuation<Void, Never>? = nil

    /// 挂在主线程 run loop 上的观察者。
    private var observer: CFRunLoopObserver? = nil

    /// 记下要等的条件。
    ///
    /// - Parameter condition: 要等到成立的条件。
    init(condition: @escaping @MainActor () -> Bool) {
        self.condition = condition
    }

    /// 挂上观察者开始等待；任务已被取消时直接继续。
    ///
    /// - Parameter continuation: 等待中的测试。
    func start(_ continuation: CheckedContinuation<Void, Never>) {
        guard !Task.isCancelled else {
            continuation.resume()
            return
        }

        self.continuation = continuation

        // 排在同一时机的其它观察者之后，SwiftUI 与 Core Animation 当次的更新已经做完
        let observer = CFRunLoopObserverCreateWithHandler(nil, Self.activities, true, CFIndex.max) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.check() }
        }

        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer
    }

    /// 条件成立时结束等待。
    func check() {
        guard condition() else {
            return
        }

        finish()
    }

    /// 摘下观察者，让等待中的测试继续。
    func finish() {
        if let observer {
            CFRunLoopObserverInvalidate(observer)
            self.observer = nil
        }

        continuation?.resume()
        continuation = nil
    }
}
