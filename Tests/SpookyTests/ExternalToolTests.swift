import Foundation
import Testing

@testable import Spooky

// MARK: - ExternalToolTests

/// 外部比较工具的命令行：TextMate 的命令行入口取应用包里实际存在的位置。
struct ExternalToolTests {
    /// TextMate 经管道接收统一补丁；`mate` 不在应用包的这个位置时管道静默失败，TextMate 根本不会打开。
    @Test("TextMate 的命令行入口")
    func textMateInvocation() throws {
        let request = ExternalToolRequest.diff(
            left: URL(fileURLWithPath: "/tmp/左 边"),
            right: URL(fileURLWithPath: "/tmp/right")
        )

        let application = URL(fileURLWithPath: "/Applications/TextMate.app")
        let invocation = try #require(ExternalTool.textMate.invocation(request, application: application))

        #expect(invocation.executable.path == "/bin/sh")

        #expect(
            invocation.arguments.suffix(3) == [
                "/tmp/左 边",
                "/tmp/right",
                "/Applications/TextMate.app/Contents/MacOS/mate",
            ]
        )
    }
}
