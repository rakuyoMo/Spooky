import Testing

@testable import Spooky

/// 服务器仓库两次轮询之间的间隔。
extension RepositorySessionTests {
    /// 读取快时按基础间隔轮询，服务器上的改动照常及时显示；
    /// 记满三次读取、三次都慢时，间隔按其中最短的一次拉长，偶发的一次慢读取不会让轮询停下很久。
    @Test(
        "轮询间隔随最近几次读取用时拉长",
        arguments: [
            // 还没有读取过
            (base: Duration.seconds(2), reads: [Duration](), expected: Duration.seconds(2)),

            // 没记满三次，读取再慢也按基础间隔
            (base: .seconds(2), reads: [.seconds(10), .seconds(10)], expected: .seconds(2)),

            // 三次都慢，按最短的一次算
            (base: .seconds(2), reads: [.seconds(3), .seconds(1), .seconds(2)], expected: .seconds(5)),

            // 三次里有一次快，按基础间隔
            (base: .seconds(2), reads: [.seconds(10), .milliseconds(100), .seconds(10)], expected: .seconds(2)),

            // 最短一次的五倍正好等于基础间隔
            (base: .seconds(2), reads: [.milliseconds(400), .seconds(1), .seconds(2)], expected: .seconds(2)),

            // 刚超过时按最短一次算
            (base: .seconds(2), reads: [.seconds(2), .milliseconds(401), .seconds(1)], expected: .milliseconds(2005)),

            // 后台同样的读取用时，仍按基础间隔
            (base: .seconds(10), reads: [.seconds(1), .seconds(2), .seconds(1)], expected: .seconds(10)),

            // 后台三次都更慢
            (base: .seconds(10), reads: [.seconds(4), .seconds(3), .seconds(5)], expected: .seconds(15)),
        ]
    )
    func pollInterval(base: Duration, reads: [Duration], expected: Duration) {
        #expect(RepositorySession.pollInterval(base: base, recentReads: reads) == expected)
    }
}
