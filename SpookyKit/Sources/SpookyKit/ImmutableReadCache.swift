import Foundation

// MARK: - ImmutableReadCache

/// 只由对象哈希决定的 Git 输出缓存；同一仓库重复查询时直接复用，减少服务器往返。
///
/// 总量按字节和条目数双重限制，超出时淘汰最久未使用的结果。
actor ImmutableReadCache {
    /// 一次查询的身份：仓库位置、子命令参数与标准输入共同决定输出。
    struct Key: Hashable, Sendable {
        /// 仓库位置，本机与服务器的同名路径互不混用。
        let location: RepositoryLocation

        /// 完整的子命令参数。
        let arguments: [String]

        /// 写入标准输入的内容，如历史分页的根哈希。
        let input: Data?
    }

    /// 应用进程内共享的缓存，最多占用 64 MiB 输出与 4096 条结果。
    static let shared = ImmutableReadCache(byteCapacity: 64 * 1024 * 1024, countCapacity: 4096)

    /// 输出字节总量上限。
    private let byteCapacity: Int

    /// 条目数量上限，限制键本身的占用。
    private let countCapacity: Int

    /// 已缓存的原始输出。
    private var entries: [Key: Data] = [:]

    /// 使用顺序，末尾为最近使用。
    private var order: [Key] = []

    /// 当前缓存的输出字节数。
    private var byteCount = 0

    /// 当前条目数量，供测试核对淘汰结果。
    var count: Int {
        entries.count
    }

    /// 以给定上限创建缓存，测试可使用较小的容量验证淘汰。
    init(byteCapacity: Int, countCapacity: Int) {
        self.byteCapacity = byteCapacity
        self.countCapacity = countCapacity
    }

    /// 读取缓存并标记为最近使用。
    func value(for key: Key) -> Data? {
        guard let value = entries[key] else {
            return nil
        }

        touch(key)
        return value
    }

    /// 保存成功的输出，超出上限时从最久未使用的条目开始淘汰。
    func store(_ value: Data, for key: Key) {
        // 单条超过四分之一容量的结果不缓存，避免一次大 Diff 清空其它条目。
        guard value.count <= byteCapacity / 4 else {
            return
        }

        if let previous = entries[key] {
            byteCount -= previous.count
            order.removeAll { $0 == key }
        }

        entries[key] = value
        order.append(key)
        byteCount += value.count

        while byteCount > byteCapacity || order.count > countCapacity, let oldest = order.first {
            order.removeFirst()
            byteCount -= entries.removeValue(forKey: oldest)?.count ?? 0
        }
    }

    /// 把命中的条目移到使用顺序末尾。
    private func touch(_ key: Key) {
        guard let index = order.firstIndex(of: key) else {
            return
        }

        order.remove(at: index)
        order.append(key)
    }
}

extension GitRunner {
    /// 执行输出完全由参数中对象哈希决定的只读查询；成功结果按仓库缓存，失败与取消不缓存。
    func immutableRun(_ arguments: [String], input: Data? = nil) async throws -> Data {
        let key = ImmutableReadCache.Key(location: location, arguments: arguments, input: input)

        if let cached = await ImmutableReadCache.shared.value(for: key) {
            return cached
        }

        let output = try await run(arguments, input: input)
        await ImmutableReadCache.shared.store(output, for: key)
        return output
    }
}
