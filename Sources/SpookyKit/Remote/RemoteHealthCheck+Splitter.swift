import Foundation

// MARK: - RemoteHealthCheck.Splitter

extension RemoteHealthCheck {
    /// 按分隔标记切开体检脚本的一路输出：先找宣告取得标记，再依次切出各步的分隔帧，读到转入通道的标记为止。
    ///
    /// 脚本先在这一路写一个宣告 `\036<标记>\037`，标记是 32 个小写十六进制字符；
    /// 之后每步结束写一个分隔帧 `\036<标记>:<退出码>\037`，转成常驻通道之前写 `\036<标记>:channel\037`。
    /// 宣告之前的字节是登录 shell 自己打印的内容，不算进任何一步。
    ///
    /// 输出可以分块收下：体检通道边收边切，切完整的结果时一次收下全部输出。
    struct Splitter {
        /// 一个分隔帧。
        struct Frame {
            /// 上一帧之后、这一帧之前的输出；第一帧从宣告之后算起。
            let output: Data

            /// 帧里记录的退出码。
            let code: Int32

            /// 帧末尾之后在这一路输出里的位置。
            let end: Int
        }

        /// 收下一块输出的结果。
        struct Scan {
            /// 按收到的顺序交出的原始字节；可能是分隔帧开头的末尾几个字节留到下一块再交，转入通道的标记及其之后的字节不交。
            var released = Data()

            /// 这一块里切出的分隔帧。
            var frames: [Frame] = []

            /// 读到转入通道的标记时，标记之后的字节；之后的输出都属于通道。
            var channel: Data? = nil
        }

        /// 宣告的字节数：开头、32 个十六进制字符与结尾。
        private static let announcementLength = 34

        /// 分隔帧在标记之后、结尾之前最多的字节数，超过仍没有结尾就是格式不对。
        private static let bodyLimit = 16

        /// 转入通道的标记在标记之后、结尾之前的字节。
        private static let channelBody = Data(":channel".utf8)

        /// 宣告里的标记；还没读到宣告时为 nil。
        private(set) var marker: Data? = nil

        /// 宣告或分隔帧的格式不对；之后不再切分，剩下的输出原样交出。
        private(set) var isMalformed = false

        /// 宣告末尾之后在这一路输出里的位置。
        private(set) var announcementEnd = 0

        /// 上一帧之后、宣告之后的输出，切出下一帧时交给它。
        private var output = Data()

        /// 收下了、还没交出的字节，下标从 0 开始。
        private var pending = Data()

        /// 已经交出的字节数。
        private var offset = 0

        /// 收下一块输出，切出其中完整的分隔帧；读到转入通道的标记之后不再收下。
        mutating func receive(_ data: Data) -> Scan {
            var scan = Scan()
            var cursor = 0
            pending.append(data)

            // 每切出一段就接着看剩下的字节，要等下一块或读到转入通道的标记时停下
            while scan.channel == nil, advance(from: &cursor, into: &scan) { }

            pending = scan.channel == nil ? Data(pending[cursor...]) : Data()
            return scan
        }

        /// 这一路读完：交出留着待看的字节。
        mutating func finish() -> Data {
            defer {
                offset += pending.count
                pending = Data()
            }

            return pending
        }
    }
}

// MARK: - Private

extension RemoteHealthCheck.Splitter {
    /// 从 `cursor` 起切下一段。
    ///
    /// - Returns: 是否还能接着切；要等下一块时为 false。
    private mutating func advance(from cursor: inout Int, into scan: inout Scan) -> Bool {
        guard !isMalformed else {
            release(upTo: pending.endIndex, from: &cursor, into: &scan)
            return false
        }

        guard let marker else { return findAnnouncement(from: &cursor, into: &scan) }

        return findFrame(marker, from: &cursor, into: &scan)
    }

    /// 找宣告：第一个 0x1E 之前都是登录 shell 的输出，之后必须是 32 个小写十六进制字符与 0x1F。
    private mutating func findAnnouncement(from cursor: inout Int, into scan: inout Scan) -> Bool {
        guard let start = pending[cursor...].firstIndex(of: 0x1E) else {
            release(upTo: pending.endIndex, from: &cursor, into: &scan)
            return false
        }

        release(upTo: start, from: &cursor, into: &scan)
        guard pending.endIndex - start >= Self.announcementLength else { return false }

        let candidate = pending[start + 1 ..< start + Self.announcementLength - 1]
        let isHex = candidate.allSatisfy { (0x30 ... 0x39).contains($0) || (0x61 ... 0x66).contains($0) }

        guard isHex, pending[start + Self.announcementLength - 1] == 0x1F else {
            isMalformed = true
            return true
        }

        marker = Data(candidate)
        release(upTo: start + Self.announcementLength, from: &cursor, into: &scan)
        announcementEnd = offset
        return true
    }

    /// 找下一个分隔帧或转入通道的标记，它之前的字节是当前这一步的输出。
    private mutating func findFrame(_ marker: Data, from cursor: inout Int, into scan: inout Scan) -> Bool {
        let opening = Data([0x1E]) + marker

        guard let head = pending.range(of: opening, in: cursor ..< pending.endIndex) else {
            // 末尾不到一个开头长的字节可能是下一个分隔帧的开头，留到下一块再看
            let kept = max(cursor, pending.endIndex - (opening.count - 1))
            release(upTo: kept, from: &cursor, into: &scan, asOutput: true)
            return false
        }

        release(upTo: head.lowerBound, from: &cursor, into: &scan, asOutput: true)

        // 结尾还没到时等下一块；超出最长的帧仍没有结尾就是格式不对
        let window = head.upperBound ..< min(pending.endIndex, head.upperBound + Self.bodyLimit)

        guard let tail = pending[window].firstIndex(of: 0x1F) else {
            isMalformed = window.count == Self.bodyLimit
            return isMalformed
        }

        let body = pending[head.upperBound ..< tail]

        if body == Self.channelBody {
            scan.channel = Data(pending[(tail + 1)...])
            return false
        }

        guard
            body.first == UInt8(ascii: ":"),
            let code = Int32(String(decoding: body.dropFirst(), as: UTF8.self))
        else {
            isMalformed = true
            return true
        }

        let frameOutput = output
        output = Data()
        release(upTo: tail + 1, from: &cursor, into: &scan)

        scan.frames.append(Frame(output: frameOutput, code: code, end: offset))
        return true
    }

    /// 交出 `cursor` 到 `end` 之间的字节；`asOutput` 时它们同时记作当前这一步的输出。
    private mutating func release(upTo end: Int, from cursor: inout Int, into scan: inout Scan, asOutput: Bool = false) {
        guard end > cursor else { return }

        let bytes = pending[cursor ..< end]
        scan.released.append(bytes)

        if asOutput {
            output.append(bytes)
        }

        offset += end - cursor
        cursor = end
    }
}
