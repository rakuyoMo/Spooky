import Foundation
import Testing

@testable import SpookyKit

extension WorkingCopyOperationsTests {
    /// 四种新旧末尾 LF × 三种动作 × 删除 / 新增 / 配对，全部经预检和正式写入逐字节核对。
    @Test("末行选择补丁保持未选字节", arguments: [
        (false, false), (false, true), (true, false), (true, true),
    ], [
        ("stage", 45), ("stage", 43), ("stage", 0),
        ("unstage", 45), ("unstage", 43), ("unstage", 0),
        ("discard", 45), ("discard", 43), ("discard", 0),
    ])
    func lineEndings(endings: (Bool, Bool), operation: (String, Int)) async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()
        let file = repository.directory.appending(path: "末行 [*].txt")
        let old = "a\nold" + (endings.0 ? "\n" : "")
        let new = "a\nnew" + (endings.1 ? "\n" : "")
        try Data(old.utf8).write(to: file)
        let service = WorkingCopyOperations(runner: repository.runner)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")
        try Data(new.utf8).write(to: file)
        if operation.0 == "unstage" { try await service.stageAll(staged: true) }

        let entry = try #require(try await repository.runner.status().entries.first)
        let snapshot = try await service.diff(for: entry, side: operation.0 == "unstage" ? .staged : .unstaged)
        let hunk = try #require(snapshot.diff?.files.first?.hunks.first)
        let lines = Set(hunk.lines.filter { $0.isChange && (operation.1 == 0 || Int($0.prefix) == operation.1) }.map(\.id))
        #expect(lines.count == (operation.1 == 0 ? 2 : 1))
        try await service.apply(snapshot, file: 0, hunk: 0, lines: lines, discard: operation.0 == "discard")

        let result: String =
            if operation.1 == 0 {
                operation.0 == "stage" ? new : old
            } else if (operation.0 == "stage") == (operation.1 == 45) {
                "a\n"
            } else {
                old + "new" + (endings.1 ? "\n" : "")
            }

        let expectedIndex = operation.0 == "discard" ? old : result
        let expectedWorking = operation.0 == "discard" ? result : new
        #expect(try await repository.runner.run(["show", ":末行 [*].txt"]) == Data(expectedIndex.utf8))
        #expect(try Data(contentsOf: file) == Data(expectedWorking.utf8))
    }
}
