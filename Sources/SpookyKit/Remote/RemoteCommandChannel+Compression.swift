import Compression
import Foundation

// MARK: - Compression

extension RemoteCommandChannel {
    /// 就绪帧的能力标志里表示 B 能压缩的一位。
    static let compressionCapability: UInt8 = 1

    /// 往返时间不短于这个值时要求压缩输出：回环与有线局域网的往返比它短，在那里压缩只会更慢。
    static let compressionRoundTrip = Duration.milliseconds(3)

    /// 量往返时间时发的探测次数，取最短的一次。
    static let probeCount = 3

    /// 经通道的请求是否要求 B 压缩标准输出。
    ///
    /// - Parameters:
    ///   - roundTrip: 量到的最短往返时间；没有量时为 nil。
    ///   - capable: B 能否压缩。
    ///   - mode: 压缩的设置。
    static func compressesOutput(
        roundTrip: Duration?,
        capable: Bool,
        mode: SSHConfiguration.OutputCompression
    ) -> Bool {
        guard capable else { return false }

        switch mode {
        case .automatic:
            guard let roundTrip else { return false }
            return roundTrip >= compressionRoundTrip

        case .always:
            return true

        case .never:
            return false
        }
    }
}

// MARK: - RemoteCommandChannel.Inflater

extension RemoteCommandChannel {
    /// 解开一个请求的压缩输出：B 为这个请求压缩的各块连起来是一条 raw deflate 流，每块以同步刷新结尾，
    /// 喂进一整块就能解出这一块的全部内容。
    ///
    /// 只在发起请求的任务里使用，不跨任务共享。
    final class Inflater {
        /// 压缩流解不开，通道的字节流已经错乱。
        struct Failure: Error { }

        /// 每次解出的字节数上限。
        private static let bufferSize = 64 * 1024

        /// 系统解压流的状态。
        private let stream: UnsafeMutablePointer<compression_stream>

        /// 解出内容的缓冲区。
        private let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        /// 系统解压流是否建立起来了；没建起来时解压一律失败。
        private let isInitialized: Bool

        /// 建立系统的 raw deflate 解压流。
        init() {
            let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
            isInitialized = compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
                == COMPRESSION_STATUS_OK
            self.stream = stream
        }

        deinit {
            if isInitialized {
                compression_stream_destroy(stream)
            }

            stream.deallocate()
            buffer.deallocate()
        }

        /// 解开压缩流里新到的一段。
        ///
        /// - Parameter data: 压缩流里新到的字节，不必是 B 发出的一整块。
        /// - Returns: 解出的内容。
        /// - Throws: 内容解不开时抛出 ``Failure``。
        func inflate(_ data: Data) throws -> Data {
            guard isInitialized else { throw Failure() }

            var output = Data()

            try data.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
                guard let base = input.bindMemory(to: UInt8.self).baseAddress else { return }

                stream.pointee.src_ptr = base
                stream.pointee.src_size = input.count

                // 输入用完、缓冲区也没填满时，新到的这一段能解出的内容都已解出
                repeat {
                    let remaining = stream.pointee.src_size
                    stream.pointee.dst_ptr = buffer
                    stream.pointee.dst_size = Self.bufferSize

                    // 流不会正常结束：B 从不写最后一块，结束或出错都说明字节流错乱
                    guard compression_stream_process(stream, 0) == COMPRESSION_STATUS_OK else { throw Failure() }

                    let produced = Self.bufferSize - stream.pointee.dst_size

                    // 还有输入，却既没用掉也没解出内容时，再处理也不会有进展
                    guard produced > 0 || remaining == 0 || stream.pointee.src_size < remaining else {
                        throw Failure()
                    }

                    output.append(buffer, count: produced)
                } while stream.pointee.src_size > 0 || stream.pointee.dst_size == 0
            }

            return output
        }
    }
}
