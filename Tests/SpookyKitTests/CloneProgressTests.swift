import Foundation
import Testing

@testable import SpookyKit

/// 克隆进度从 stderr 流式解析：阶段与百分比不能随数据块的切法变化。
///
/// 夹具 `clone-progress.txt` 由 Git 2.54 在忽略系统与用户配置的临时仓库中以 `clone --progress --recurse-submodules`
/// 经 file:// 传输生成，临时路径换成了固定写法；含主仓库与一个子模块各自的全部阶段。
struct CloneProgressTests {
    /// 整份夹具按不同大小切块，得到的进度序列必须相同，且覆盖主仓库与子模块的各个阶段。
    @Test("克隆进度夹具：切块方式不影响解析结果", arguments: [1, 7, 64, 4096, Int.max])
    func fixtureChunks(size: Int) throws {
        let data = try fixture("clone-progress.txt")
        let expected = try progressList(data, chunkSize: 1)
        let progress = try progressList(data, chunkSize: size)

        // 逐字节读入时每行都会被回调，其余切法只取每块最新的一条，最后一条必须一致
        #expect(progress.last == expected.last)
        #expect(Set(progress).isSubset(of: Set(expected)))

        let phases = expected.map(\.phase)
        #expect(phases.first == .enumerating)
        #expect(phases.contains(.counting) && phases.contains(.compressing))
        #expect(phases.contains(.receiving) && phases.contains(.resolving))

        // 子模块的克隆从头再经过一遍各阶段
        #expect(phases.filter { $0 == .enumerating }.count == 2)

        let received = try #require(expected.last { $0.phase == .receiving })
        #expect(received.percent == 100)
        #expect(received.completed == received.total)
        #expect(received.fraction == 1)
    }

    /// 带百分比与只有数量的两种进度行，以及不认识或格式不符的行。
    @Test("克隆进度：单行解析")
    func singleLines() {
        let receiving = CloneProgress.Parser.parse("Receiving objects:  45% (555/1234), 1.20 MiB | 2.30 MiB/s")
        #expect(receiving == CloneProgress(phase: .receiving, percent: 45, completed: 555, total: 1234))
        #expect(receiving?.fraction == 0.45)

        let enumerating = CloneProgress.Parser.parse("remote: Enumerating objects: 1234, done.        ")
        #expect(enumerating == CloneProgress(phase: .enumerating, percent: nil, completed: 1234, total: nil))
        #expect(enumerating?.fraction == nil)

        let filtering = CloneProgress.Parser.parse("Filtering content: 100% (3/3), 1.10 MiB | 4.00 MiB/s, done.")
        #expect(filtering?.phase == .filtering)

        let checkout = CloneProgress.Parser.parse("Updating files:  50% (1/2)")
        #expect(checkout?.phase == .checkingOut)

        #expect(CloneProgress.Parser.parse("Cloning into '/tmp/clone'...") == nil)
        #expect(CloneProgress.Parser.parse("Checking connectivity: 12, done.") == nil)
        #expect(CloneProgress.Parser.parse("Receiving objects: abc") == nil)
        #expect(CloneProgress.Parser.parse("fatal: repository '/tmp/missing' does not exist") == nil)
    }

    /// 多字节字符被块边界切开时，整行仍按完整的 UTF-8 解码；没有行尾的残片留到下一块。
    @Test("克隆进度：跨块的半行与多字节字符")
    func splitLines() {
        let parser = CloneProgress.Parser()
        let text = Data("Cloning into '/tmp/仓库'...\nReceiving objects:  10% (1/10)\r".utf8)
        let split = text.firstIndex(of: 0xE4).map { $0 + 1 } ?? 0

        #expect(parser.receive(text.prefix(split)) == nil)
        #expect(parser.receive(text.dropFirst(split).dropLast(3)) == nil)
        #expect(parser.receive(text.suffix(3))?.percent == 10)

        // 没有行尾的进度行不解析，等到 \r 才算完整
        #expect(parser.receive(Data("Receiving objects:  20% (2/10)".utf8)) == nil)
        #expect(parser.receive(Data("\r".utf8))?.percent == 20)
    }

    /// 把夹具按指定大小切块读入，返回每块最新的进度。
    private func progressList(_ data: Data, chunkSize: Int) throws -> [CloneProgress] {
        let parser = CloneProgress.Parser()
        var progress: [CloneProgress] = []
        var offset = data.startIndex

        while offset < data.endIndex {
            let end = data.index(offset, offsetBy: min(chunkSize, data.endIndex - offset))

            if let latest = parser.receive(data[offset ..< end]) {
                progress.append(latest)
            }

            offset = end
        }

        return progress
    }

    /// 读取随测试目标打包的夹具原始字节。
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
