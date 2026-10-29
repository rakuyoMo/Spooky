import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ActivityBaselineArchiveTests

/// Repository 页增减计数的基准存在本机：每个仓库一个文件，换一个实例照样读回，读不了的文件按没有基准算。
///
/// 每个测试使用自己的临时目录，不碰 Application Support。
@MainActor
struct ActivityBaselineArchiveTests {
    /// 写入的各类清单换一个实例读回后相同；没有文件、读不了的文件与写着别的仓库的文件都按没有基准算。
    @Test("基准写入后读回，读不了的文件跳过")
    func saveAndLoad() throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.remote(host: "spooky-test", path: "/Users/wgy/spooky-test/基准 [1]")
        let other = RepositoryLocation.local(path: "/temporary/基准 [1]")
        let inventories: [ActivityInventory: [String: String]] = [
            .branches: ["refs/heads/main": "1", "refs/heads/功能": "2"],
            .stashes: ["abc": "0"],
        ]

        ActivityBaselineArchive(directory: directory).save(inventories, of: location)

        // 新的实例读回同样的清单；别的仓库还没有文件
        let archive = ActivityBaselineArchive(directory: directory)
        #expect(archive.load(location) == inventories)
        #expect(archive.load(other).isEmpty)

        // 别的仓库的文件里写着这个仓库时不用它
        try FileManager.default.copyItem(at: archive.url(of: location), to: archive.url(of: other))
        #expect(archive.load(other).isEmpty)

        // 读不了的文件按没有基准算
        try Data("{".utf8).write(to: archive.url(of: location))
        #expect(archive.load(location).isEmpty)
    }

    /// 文件名只由仓库身份决定：同一仓库总是同一个文件，路径相同的本机与服务器仓库各用一个。
    @Test("基准的文件名按仓库")
    func fileNames() {
        let directory = URL(filePath: "/temporary/baselines", directoryHint: .isDirectory)
        let local = RepositoryLocation.local(path: "/Users/wgy/spooky-test/仓库")
        let remote = RepositoryLocation.remote(host: "spooky-test", path: "/Users/wgy/spooky-test/仓库")
        let other = RepositoryLocation.local(path: "/Users/wgy/spooky-test/其它")

        let url = ActivityBaselineArchive(directory: directory).url(of: local)
        #expect(url == ActivityBaselineArchive(directory: directory).url(of: local))
        #expect(url.deletingLastPathComponent().path == directory.path)
        #expect(url.lastPathComponent.count == 64 + ".json".count)

        #expect(url != ActivityBaselineArchive(directory: directory).url(of: remote))
        #expect(url != ActivityBaselineArchive(directory: directory).url(of: other))
    }
}
