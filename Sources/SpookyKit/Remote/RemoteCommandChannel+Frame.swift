import Foundation

// MARK: - RemoteCommandChannel.Frame

extension RemoteCommandChannel {
    /// 发给包装器 serve 模式的帧。
    ///
    /// 两个方向的帧都是 “长度（其后的字节数）、类型、请求标识、负载”，长度与标识是大端 32 位整数，类型占 1 字节。
    enum Frame {
        /// 执行请求的类型。
        private static let requestType: UInt8 = 1

        /// 放弃请求的类型：B 不再为这个请求发帧。
        private static let abortType: UInt8 = 2

        /// 执行一个包装器模式的请求帧。
        ///
        /// - Parameters:
        ///   - identifier: 请求标识。
        ///   - arguments: 包装器的模式与它的参数。
        ///   - input: 请求的标准输入。
        /// - Returns: 负载依次是参数个数、逐个参数的长度与内容，其余字节是标准输入。
        static func request(identifier: UInt32, arguments: [String], input: Data) -> Data {
            var payload = Data()
            append(UInt32(arguments.count), to: &payload)

            for argument in arguments {
                let bytes = Data(argument.utf8)
                append(UInt32(bytes.count), to: &payload)
                payload.append(bytes)
            }

            payload.append(input)
            return frame(type: requestType, identifier: identifier, payload: payload)
        }

        /// 请求帧编码后的字节数：帧头 9 字节，参数个数 4 字节，每个参数 4 字节的长度加内容，再加标准输入。
        ///
        /// - Parameters:
        ///   - arguments: 包装器的模式与它的参数。
        ///   - input: 请求的标准输入。
        static func requestSize(arguments: [String], input: Data) -> Int {
            arguments.reduce(9 + 4 + input.count) { $0 + 4 + $1.utf8.count }
        }

        /// 放弃一个请求的帧，没有负载。
        ///
        /// - Parameter identifier: 请求标识。
        static func abort(identifier: UInt32) -> Data {
            frame(type: abortType, identifier: identifier, payload: Data())
        }

        /// 给负载加上帧头。
        private static func frame(type: UInt8, identifier: UInt32, payload: Data) -> Data {
            var frame = Data(capacity: 9 + payload.count)
            append(UInt32(5 + payload.count), to: &frame)
            frame.append(type)
            append(identifier, to: &frame)
            frame.append(payload)
            return frame
        }

        /// 以大端字节序追加一个 32 位整数。
        private static func append(_ value: UInt32, to data: inout Data) {
            withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
        }
    }
}

// MARK: - RemoteCommandChannel.FrameReader

extension RemoteCommandChannel {
    /// 逐块切开 serve 模式发回的字节流；负载跨块时分段交出，大段输出不在这里攒着。
    struct FrameReader {
        /// 切出的一件事。
        enum Event: Equatable {
            /// 通道就绪，带协议版本。
            case ready(version: UInt32)

            /// 一个请求的一段输出。
            case output(identifier: UInt32, isError: Bool, data: Data)

            /// 一个请求的命令已结束；被信号结束时退出码是 128 加信号值。
            case exit(identifier: UInt32, code: UInt8)
        }

        /// 帧的长度或类型不对，通道不能再用。
        struct InvalidFrame: Error { }

        /// 一块输出的上限，与包装器每次读取的大小相同。
        static let chunkLimit = 64 * 1024

        /// 还没凑齐的帧头。
        private var header: [UInt8] = []

        /// 当前帧的类型。
        private var type: UInt8 = 0

        /// 当前帧的请求标识。
        private var identifier: UInt32 = 0

        /// 当前帧还没读到的负载字节数。
        private var remaining = 0

        /// 切开一块字节流。
        ///
        /// - Parameter data: 新到的字节。
        /// - Returns: 这块字节里切出的事件，按到达顺序排列。
        mutating func receive(_ data: Data) throws -> [Event] {
            var events: [Event] = []
            var index = data.startIndex

            while index < data.endIndex {
                // 帧头凑齐 9 字节之前只攒帧头
                if header.count < 9 {
                    let count = min(9 - header.count, data.endIndex - index)
                    header.append(contentsOf: data[index ..< index + count])
                    index += count

                    if header.count == 9 {
                        try begin(into: &events)
                    }

                    continue
                }

                let count = min(remaining, data.endIndex - index)
                let segment = data[index ..< index + count]
                index += count
                remaining -= count

                // 退出帧的负载只有 1 字节，读到就结束这一帧
                if type == 3 {
                    events.append(.exit(identifier: identifier, code: segment[segment.startIndex]))
                } else {
                    events.append(.output(identifier: identifier, isError: type == 2, data: Data(segment)))
                }

                if remaining == 0 {
                    header = []
                }
            }

            return events
        }

        /// 解开凑齐的帧头，核对长度与类型；没有负载的帧在这里就结束。
        private mutating func begin(into events: inout [Event]) throws {
            let length = header[0 ..< 4].reduce(0) { $0 << 8 | Int($1) }
            type = header[4]
            identifier = header[5 ..< 9].reduce(0) { $0 << 8 | UInt32($1) }
            remaining = length - 5

            switch type {
            case 0:
                guard remaining == 0 else { throw InvalidFrame() }
                events.append(.ready(version: identifier))

            case 1, 2:
                guard (0 ... Self.chunkLimit).contains(remaining) else { throw InvalidFrame() }

            case 3:
                guard remaining == 1 else { throw InvalidFrame() }

            default:
                throw InvalidFrame()
            }

            if remaining == 0 {
                header = []
            }
        }
    }
}
