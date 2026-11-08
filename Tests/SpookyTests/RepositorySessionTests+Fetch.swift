import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 跳过对话框的获取所用的选项与清理结果，以及添加远端后随即获取。
extension RepositorySessionTests {
    /// 快速获取、自动获取与 Fetch All 读获取对话框保存的清理偏好，没有保存值时清理，全部标签不生效；
    /// 清理按 fetch refspec：普通分支映射保留本地独有的标签，加上标签映射后删除远端没有的本地标签。
    @Test("跳过对话框的获取：选项与两种 refspec 的清理")
    func fetchWithPreferences() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (runner, other) = try await makeSyncRepository(in: directory)

        // 远端的分支 gone 取到本地后被删掉
        _ = try await other.run(["push", "-q", "origin", "HEAD:refs/heads/gone"])
        _ = try await runner.run(["fetch", "-q", "origin"])
        _ = try await other.run(["push", "-q", "origin", "--delete", "gone"])

        // 远端另有一个不在任何分支上的标签，本地有一个独有的标签
        _ = try await other.run(["commit", "--allow-empty", "-q", "-m", "lonely"])
        _ = try await other.run(["tag", "lonely"])
        _ = try await other.run(["reset", "-q", "--hard", "HEAD~1"])
        _ = try await other.run(["push", "-q", "origin", "refs/tags/lonely"])
        _ = try await runner.run(["tag", "mine"])

        let session = try await openSession(runner)
        defer { session.close() }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defaults.set(true, forKey: "fetchAllTags")

        // 快速获取：没有保存值时清理，全部标签不生效，普通映射不动本地标签
        session.quickFetch(defaults: defaults)
        await session.writeTask?.value

        var refs = try await references(runner)

        #expect(!refs.contains("refs/remotes/origin/gone"))
        #expect(!refs.contains("refs/tags/lonely"))
        #expect(refs.contains("refs/tags/mine"))

        // 自动获取：加上标签映射后，清理删除远端没有的本地标签
        _ = try await runner.run(["config", "--local", "--add", "remote.origin.fetch", "+refs/tags/*:refs/tags/*"])

        #expect(session.autoFetch(remote: "origin", defaults: defaults))
        await session.writeTask?.value

        refs = try await references(runner)

        #expect(!refs.contains("refs/tags/mine"))
        #expect(refs.contains("refs/tags/lonely"))

        // Fetch All：保存了不清理时照保存值，本地独有的标签保留
        defaults.set(false, forKey: "fetchPrune")
        _ = try await runner.run(["tag", "kept"])

        session.fetchAll(defaults: defaults)
        await session.writeTask?.value

        #expect(try await references(runner).contains("refs/tags/kept"))
    }

    /// 添加远端成功后随即获取它，Repository 页记添加、Remote 页记获取；
    /// 地址连得上而获取失败时远端仍在，获取的记录如实失败并报告错误，添加不重复。
    @Test("添加远端后获取，获取失败时远端保留")
    func addRemoteThenFetch() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (runner, other) = try await makeSyncRepository(in: directory)
        let session = try await openSession(runner)
        defer { session.close() }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        // 添加成功并取到远端分支
        let mirror = directory.appending(path: "mirror.git").path
        _ = try await other.run(["init", "-q", "--bare", mirror])
        _ = try await other.run(["push", "-q", mirror, "HEAD:main"])

        try await addRemote("mirror", url: mirror, to: session, runner: runner)

        #expect(try await references(runner).contains("refs/remotes/mirror/main"))
        #expect(remoteRecords(runner).first { $0.target == .fetch("mirror") }?.state == "activity.finished")
        #expect(failures.isEmpty)

        // 远端的引用读得到，但缺了提交的树对象：添加成功、获取失败。空树是 Git 内置的对象，提交里须有文件
        let broken = directory.appending(path: "broken.git").path
        try Data("a\n".utf8).write(to: directory.appending(path: "other/a.txt"))
        _ = try await other.run(["add", "a.txt"])
        _ = try await other.run(["commit", "-q", "-m", "file"])
        _ = try await other.run(["init", "-q", "--bare", broken])
        _ = try await other.run(["push", "-q", broken, "HEAD:main"])

        let tree = String(decoding: try await other.run(["rev-parse", "HEAD^{tree}"]), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        try FileManager.default.removeItem(
            atPath: broken + "/objects/" + tree.prefix(2) + "/" + tree.dropFirst(2)
        )

        try await addRemote("broken", url: broken, to: session, runner: runner)

        let remotes = String(decoding: try await runner.run(["remote"]), as: UTF8.self)
        let fetch = remoteRecords(runner).first

        #expect(remotes.split(separator: "\n") == ["broken", "mirror", "origin"])
        #expect(fetch?.target == .fetch("broken"))
        #expect(fetch?.state == "activity.failed")
        #expect(failures.count == 1)
    }
}

// MARK: - Fetch Helpers

extension RepositorySessionTests {
    /// 经会话添加远端，等添加与随后的获取都结束；添加记在 Repository 页且已完成。
    private func addRemote(
        _ name: String,
        url: String,
        to session: RepositorySession,
        runner: GitRunner
    ) async throws {
        let adding = AppLocalization.text("remote.add")

        #expect(session.addRemote(name: name, url: url))
        await session.writeTask?.value

        let added = RepositoryActivities.shared.items.first {
            $0.repository == runner.location && $0.title == adding
        }

        #expect(added?.kind == .repository)
        #expect(added?.state == "activity.finished")

        // 获取在添加的写操作结束后才开始
        await until {
            remoteRecords(runner).contains { $0.target == .fetch(name) && $0.ended != nil }
        }
    }

    /// 本地仓库里的分支、远端跟踪分支与标签的完整引用名。
    private func references(_ runner: GitRunner) async throws -> Set<String> {
        let output = try await runner.run(["for-each-ref", "--format=%(refname)"])
        return Set(String(decoding: output, as: UTF8.self).split(separator: "\n").map(String.init))
    }
}
