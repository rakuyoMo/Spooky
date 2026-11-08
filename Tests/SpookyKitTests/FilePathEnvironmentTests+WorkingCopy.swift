import Foundation
import Testing

@testable import SpookyKit

extension FilePathEnvironmentTests {
    /// 路径环境污染不能把大小写不同的索引文件或重建的旧路径加入按行写入。
    @Test("路径环境隔离覆盖工作区写入", arguments: [false, true])
    func workingCopyEnvironment(custom: Bool) async throws {
        let fixture = try WorkingCopyScopeFixture()
        defer { fixture.repository.remove() }

        try await fixture.prepare()
        try fixture.change()

        // 旧路径重建为未跟踪文件，索引里另有一个只差大小写的 NEW
        let protected = Data([0, 0xFE, 0xFF])
        try fixture.write(protected, path: "old")

        let output = try await fixture.runner.run(["hash-object", "-w", "--stdin"], input: protected)
        let blob = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
        _ = try await fixture.runner.run(["update-index", "--add", "--cacheinfo", "100644", blob, "NEW"])
        let originalIndex = try await fixture.runner.run(["ls-files", "--stage", "-z", "--", "NEW"])

        let runner = Self.pollutedRunner(path: fixture.repository.directory.path, custom: custom)
        let service = WorkingCopyOperations(runner: runner)
        let snapshot = try await service.diff(for: try await fixture.entry(), side: .unstaged)
        #expect(snapshot.diff?.files.count == 1)

        // 非法选择被拒绝，旧路径不受影响
        await #expect(throws: WorkingCopyError.invalidSelection) {
            try await service.apply(snapshot, file: 0, hunk: 0, lines: [999])
        }

        try await fixture.verifyIndependent(protected)

        // 整块暂存只写入所选文件
        try await service.apply(snapshot, file: 0, hunk: 0)
        try await fixture.verifyIndependent(protected)
        #expect(try await fixture.runner.run(["ls-files", "--stage", "-z", "--", "NEW"]) == originalIndex)
        #expect(try await fixture.runner.run(["show", ":new"]) != Data(WorkingCopyScopeFixture.original.utf8))
    }
}
