import Foundation
import Testing

@testable import Spooky

// MARK: - ExternalToolTests

/// 外部比较工具：选择工具的弹出菜单按名称字母序列出；TextMate 的命令行入口取应用包里实际存在的位置。
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

    /// 比较工具与合并工具的弹出菜单都按声明顺序列出，新增工具时同样要放在字母序的位置上。
    @Test("工具按名称字母序列出")
    func alphabeticalOrder() {
        let names = ExternalTool.allCases.map(\.displayName)

        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }
}
