import Foundation
import Testing

@testable import SpookyKit

/// 合并在冲突中停下后的识别、收尾与中止，由真实 Git 验证。
extension WorkingCopyOperationsTests {
    /// 采用一侧与手工标记均由 Git 收尾，合并提交保留两个父提交。
    @Test("合并冲突、采用一侧、提交与中止")
    func conflicts() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)
        let file = repository.directory.appending(path: "file")

        try Data("base\n".utf8).write(to: file)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")

        _ = try await repository.runner.run(["checkout", "-b", "side"])
        try Data("theirs\n".utf8).write(to: file)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "theirs", body: "")

        _ = try await repository.runner.run(["checkout", "main"])
        try Data("ours\n".utf8).write(to: file)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "ours", body: "")

        _ = try await repository.runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])
        #expect(try await service.context(head: try await repository.runner.status().branch.oid).operation == .merge)
        try await service.finish(.merge, action: "abort")
        #expect(try await repository.runner.status().entries.isEmpty)

        _ = try await repository.runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])
        try await service.resolve(try await repository.runner.status().entries, theirs: true)
        #expect(try Data(contentsOf: file) == Data("theirs\n".utf8))
        #expect(try await repository.runner.status().entries.allSatisfy { $0.kind != .conflicted })

        try await service.commit(subject: "merge", body: "")
        #expect(try await service.context(head: try await repository.runner.status().branch.oid).operation == nil)
        let parents = try await repository.runner.run(["rev-list", "--parents", "-1", "HEAD"])
        #expect(String(decoding: parents, as: UTF8.self).split(separator: " ").count == 3)
    }
}
