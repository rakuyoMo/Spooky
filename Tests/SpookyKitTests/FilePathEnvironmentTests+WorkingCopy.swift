import Foundation
import Subprocess
import Testing

@testable import SpookyKit

extension FilePathEnvironmentTests {
    /// 路径环境污染不能把大小写不同的索引文件或重建的旧路径加入按行写入。
    @Test("路径环境隔离覆盖工作区写入", arguments: [
        ["GIT_LITERAL_PATHSPECS"], ["GIT_GLOB_PATHSPECS"], ["GIT_NOGLOB_PATHSPECS"], ["GIT_ICASE_PATHSPECS"],
        ["GIT_LITERAL_PATHSPECS", "GIT_GLOB_PATHSPECS", "GIT_NOGLOB_PATHSPECS", "GIT_ICASE_PATHSPECS"],
    ], [false, true])
    func workingCopyEnvironment(keys: [String], custom: Bool) async throws {
        let fixture = try WorkingCopyScopeFixture()
        defer { fixture.repository.remove() }
        try await fixture.prepare()
        try fixture.change()
        let protected = Data([0, 0xFE, 0xFF])
        try fixture.write(protected, path: "old")
        let blob = String(
            decoding: try await fixture.runner.run(["hash-object", "-w", "--stdin"], input: protected),
            as: UTF8.self
        )
        .trimmingCharacters(in: .newlines)
        _ = try await fixture.runner.run(["update-index", "--add", "--cacheinfo", "100644", blob, "NEW"])
        let originalIndex = try await fixture.runner.run(["ls-files", "--stage", "-z", "--", "NEW"])
        let variables = Dictionary(uniqueKeysWithValues: keys.map { ($0, "1") })
        var inherited: [Environment.Key: String?] = ["GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"]
        if !custom {
            for key in keys { inherited[Environment.Key(stringLiteral: key)] = "1" }
        }

        let runner = GitRunner(
            location: .local(path: fixture.repository.directory.path),
            settings: LocalExecutionSettings(
                loginShellVariables: custom ? variables : [:],
                customVariables: custom ? variables : [:]
            ),
            environment: .inherit.updating(inherited)
        )
        let service = WorkingCopyOperations(runner: runner)
        let snapshot = try await service.diff(for: try await fixture.entry(), side: .unstaged)
        #expect(snapshot.diff?.files.count == 1)
        await #expect(throws: WorkingCopyError.invalidSelection) {
            try await service.apply(snapshot, file: 0, hunk: 0, lines: [999])
        }
        try await fixture.verifyIndependent(protected)
        try await service.apply(snapshot, file: 0, hunk: 0)
        try await fixture.verifyIndependent(protected)
        #expect(try await fixture.runner.run(["ls-files", "--stage", "-z", "--", "NEW"]) == originalIndex)
        #expect(try await fixture.runner.run(["show", ":new"]) != Data(WorkingCopyScopeFixture.original.utf8))
    }
}
