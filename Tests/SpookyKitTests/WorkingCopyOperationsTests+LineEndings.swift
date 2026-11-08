import Foundation
import Testing

@testable import SpookyKit

extension WorkingCopyOperationsTests {
    /// 新旧末尾 LF 的组合、三种动作与删除 / 新增 / 配对三种选择，经预检和正式写入逐字节核对；
    /// 六组参数让每种动作、每种选择各出现两次，四种末尾组合都至少出现一次。
    @Test("末行选择补丁保持未选字节", arguments: [
        ((false, true), ("stage", 45)),
        ((true, false), ("stage", 43)),
        ((false, false), ("unstage", 0)),
        ((true, true), ("unstage", 45)),
        ((true, false), ("discard", 43)),
        ((false, true), ("discard", 0)),
    ])
    func lineEndings(endings: (Bool, Bool), operation: (String, Int)) async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)
        let file = repository.directory.appending(path: "末行 [*].txt")
        let old = "a\nold" + (endings.0 ? "\n" : "")
        let new = "a\nnew" + (endings.1 ? "\n" : "")

        try Data(old.utf8).write(to: file)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")
        try Data(new.utf8).write(to: file)

        if operation.0 == "unstage" {
            try await service.stageAll(staged: true)
        }

        // 按前缀选出删除行、新增行，或两者都选
        let entry = try #require(try await repository.runner.status().entries.first)
        let snapshot = try await service.diff(for: entry, side: operation.0 == "unstage" ? .staged : .unstaged)
        let hunk = try #require(snapshot.diff?.files.first?.hunks.first)
        let selected = hunk.lines.filter {
            $0.isChange && (operation.1 == 0 || Int($0.prefix) == operation.1)
        }
        let lines = Set(selected.map(\.id))
        #expect(lines.count == (operation.1 == 0 ? 2 : 1))

        try await service.apply(
            snapshot,
            file: 0,
            hunk: 0,
            lines: lines,
            discard: operation.0 == "discard"
        )

        // 被写的一侧：整块回到一端；只写入删除时去掉旧行，只写入新增时两行并存
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
